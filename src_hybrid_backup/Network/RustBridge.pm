#########################################################################
#  OpenKore - Networking subsystem
#  This module contains the Rust Bridge network core.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#########################################################################
package Network::RustBridge;

use strict;
use IO::Socket::INET;
use JSON::Tiny qw(decode_json encode_json);
use Globals;
use Log qw(message warning error debug);
use Network;
use base qw(Network::DirectConnection);
use Utils qw(dataWaiting);
use Translation qw(T TF);

sub new {
	my ($class, $wrapper) = @_;
	my $self = $class->SUPER::new($wrapper);
	$self->{ipc_buffer} = "";
	$self->{packet_queue} = [];
	$self->{responses_queue} = [];
	$self->{ipc_socket} = undef;
	$self->{ro_server_alive} = 0;
	return bless $self, $class;
}

sub version {
	return 4; # Rust Bridge version
}

sub serverPeerHost {
	return $_[0]->{actual_host};
}

sub serverPeerPort {
	return $_[0]->{actual_port};
}

sub serverAlive {
	my $self = shift;
	if ($self->{use_rust}) {
		# We are alive ONLY if the IPC bridge is connected AND Rust reports the RO server is connected
		return $self->{ipc_socket} && $self->{ipc_socket}->connected() && $self->{ro_server_alive};
	} else {
		# Legacy mode uses DirectConnection's logic
		return $self->SUPER::serverAlive();
	}
}

sub serverAddress {
	my $self = shift;
	if ($self->{use_rust}) {
		return $self->{ipc_socket}->sockaddr();
	} else {
		return $self->SUPER::serverAddress();
	}
}

sub _process_ipc_messages {
	my ($self, $raw_data) = @_;
	return unless defined $raw_data && length($raw_data) > 0;
	
	$self->{ipc_buffer} .= $raw_data;
	
	while ($self->{ipc_buffer} =~ s/^(.*)\n//) {
		my $line = $1;
		eval {
			my $msg = decode_json($line);
			if ($msg->{type} eq 'packet_received' || $msg->{type} eq 'packet' || $msg->{type} eq 'packet_raw') {
				my $data;
				if ($msg->{type} eq 'packet') {
					warning "Received structured packet from Rust, but expected raw. Check Rust implementation.";
					# We don't handle structured packets in Perl yet, they should be PacketRaw
				} else {
					$data = pack("C*", @{$msg->{data}});
				}
				
				if (defined $data && length($data) > 0) {
					push @{$self->{packet_queue}}, $data;
				}
			} elsif ($msg->{type} eq 'connection_status') {
				$self->{ro_server_alive} = $msg->{connected} ? 1 : 0;
				if ($msg->{connected}) {
					debug TF("Rust Bridge: RO Server connected to %s\n", $msg->{addr}), "rust_bridge";
				} else {
					message TF("Rust Bridge: RO Server disconnected from %s\n", $msg->{addr}), "connection";
				}
				push @{$self->{responses_queue}}, $msg;
			} else {
				push @{$self->{responses_queue}}, $msg;
			}
		};
		if ($@) {
			warning TF("Failed to decode IPC message: %s\n", $@);
		}
	}
}

sub serverConnect {
	my ($self, $host, $port) = @_;
	
	$self->{actual_host} = $host;
	$self->{actual_port} = $port;

	# Hybrid Mode: Use legacy Perl for Login/Char servers, Rust for Map server.
	# conState 4 is when we are about to connect to the Map server.
	if ($self->getState() < 4) {
		message TF("Hybrid Mode: Using legacy Perl networking for %s:%s (state %s)\n", $host, $port, $self->getState()), "connection";
		$self->{use_rust} = 0;
		$self->{ro_server_alive} = 0; # Not used in legacy mode but for safety
		return $self->SUPER::serverConnect($host, $port);
	}

	$self->{use_rust} = 1;
	$self->{ro_server_alive} = 0; # Reset until confirmed
	
	# Ensure Rust Core is started
	if (!$main::rust_core_started) {
		Log::debug("Rust Bridge: start_rust_core() required.\n", "rust_bridge");
		main::start_rust_core();
	} else {
		Log::debug("Rust Bridge: start_rust_core() already called.\n", "rust_bridge");
	}
	
	# Determine which log file to read for the IPC port
	my $log_file = $main::rust_core_log || 'rust_core.log';
	Log::debug("Rust Bridge: Looking for port in $log_file\n", "rust_bridge");
	
	# Wait for Rust to write the port to the log
	my $ipc_port;
	my $timeout = time + 10;
	while (time < $timeout) {
		if (open(my $log, '<', $log_file)) {
			while (<$log>) {
				if (/IPC_PORT=(\d+)/) {
					$ipc_port = $1;
					last;
				}
			}
			close($log);
		}
		last if $ipc_port;
		select(undef, undef, undef, 0.1); # Sleep 0.1s
	}
	
	if (!$ipc_port) {
		Log::debug("Rust Bridge: Port discovery failed after 10s.\n", "rust_bridge");
		die T("Could not determine Rust IPC port. Check $log_file.\n");
	}

	Log::debug("Rust Bridge: Found port $ipc_port. Connecting...\n", "rust_bridge");
	message TF("Hybrid Mode: Connecting to Rust IPC Bridge (127.0.0.1:%s) via %s...\n", $ipc_port, $log_file), "connection";
	
	# Clear old queues on new connection
	$self->{packet_queue} = [];
	$self->{responses_queue} = [];
	$self->{ipc_buffer} = "";

	my $retries = 5;
	while ($retries > 0) {
		$self->{ipc_socket} = new IO::Socket::INET(
			PeerAddr => '127.0.0.1',
			PeerPort => $ipc_port,
			Proto    => 'tcp',
			Timeout  => 2
		);
		last if $self->{ipc_socket};
		$retries--;
		message T("Rust IPC Bridge not ready, retrying in 1s...\n"), "connection" if $retries > 0;
		sleep(1);
	}

	if ($self->{ipc_socket}) {
		Log::debug("Rust Bridge: IPC Socket connected.\n", "rust_bridge");
		message T("Connected to Rust IPC Bridge.\n"), "connection";
		# Tell Rust to connect to the actual RO server
		$self->serverSend({
			type => 'connect',
			host => $host,
			port => $port
		});

		# WAIT for confirmation
		Log::debug("Rust Bridge: Sent connect command. Waiting for confirmation...\n", "rust_bridge");
		message TF("Waiting for Rust Core to connect to %s:%s...\n", $host, $port), "connection";
		my $confirmed = 0;
		my $timeout = time + 10;
		while (time < $timeout) {
			if (dataWaiting(\$self->{ipc_socket})) {
				my $raw_data;
				$self->{ipc_socket}->recv($raw_data, 4096);
				$self->_process_ipc_messages($raw_data);
				while (@{$self->{responses_queue}}) {
					my $msg = shift @{$self->{responses_queue}};
					if ($msg->{type} eq 'connection_status') {
						if ($msg->{connected}) {
							Log::debug("Rust Bridge: Connection confirmed.\n", "rust_bridge");
							message TF("Rust Core successfully connected to %s.\n", $msg->{addr}), "connection";
							$confirmed = 1;
							$self->{ro_server_alive} = 1;
						} else {
							Log::debug("Rust Bridge: Connection FAILED.\n", "rust_bridge");
							error TF("Rust Core failed to connect: %s\n", $msg->{addr}), "connection";
							$self->{ro_server_alive} = 0;
							die T("Rust Core connection failed.\n");
						}
					}
				}
			}
			last if $confirmed;
			select(undef, undef, undef, 0.1);
		}
		if (!$confirmed) {
			Log::debug("Rust Bridge: Confirmation TIMEOUT.\n", "rust_bridge");
			die T("Timeout waiting for Rust Core connection confirmation.\n");
		}
	} else {
		error TF("Could not connect to Rust IPC Bridge: %s\n", $!), "connection";
		die T("Rust IPC Bridge not found. Is kore-rust-core running?\n");
	}
}

sub find_path {
	my ($self, $map_name, $start, $end) = @_;
	return undef unless $self->serverAlive;
	return undef unless $self->{use_rust}; # Pathfinding only via Rust

	$self->serverSend({
		type => 'find_path',
		map_name => $map_name,
		start_x => int($start->{x}),
		start_y => int($start->{y}),
		end_x => int($end->{x}),
		end_y => int($end->{y}),
		random_factor => int($self->{randomFactor} || 0)
	});

	my $timeout = time + 5;
	while (time < $timeout) {
		if (!@{$self->{responses_queue}}) {
			if (dataWaiting(\$self->{ipc_socket}, 0.1)) {
				my $raw_data;
				$self->{ipc_socket}->recv($raw_data, 4096);
				$self->_process_ipc_messages($raw_data);
			}
		}

		my @remaining;
		my $result;
		while (@{$self->{responses_queue}}) {
			my $msg = shift @{$self->{responses_queue}};
			if ($msg->{type} eq 'path_found') {
				$result = $msg->{points};
				last;
			} elsif ($msg->{type} eq 'path_not_found') {
				$result = [];
				last;
			} else {
				push @remaining, $msg;
			}
		}
		
		if (defined $result) {
			unshift @{$self->{responses_queue}}, @remaining;
			return $result;
		}

		unshift @{$self->{responses_queue}}, @remaining;
		select(undef, undef, undef, 0.01);
	}
	
	return undef;
}

sub get_nearby {
	my ($self, $x, $y, $range) = @_;
	return undef unless $self->serverAlive;
	return undef unless $self->{use_rust};

	$self->serverSend({
		type => 'get_nearby',
		x => int($x),
		y => int($y),
		range => int($range)
	});

	my $timeout = time + 2;
	while (time < $timeout) {
		if (!@{$self->{responses_queue}}) {
			if (dataWaiting(\$self->{ipc_socket}, 0.1)) {
				my $raw_data;
				$self->{ipc_socket}->recv($raw_data, 4096);
				$self->_process_ipc_messages($raw_data);
			}
		}

		my @remaining;
		my $result;
		while (@{$self->{responses_queue}}) {
			my $msg = shift @{$self->{responses_queue}};
			if ($msg->{type} eq 'nearby_actors') {
				$result = $msg->{actors};
				last;
			} else {
				push @remaining, $msg;
			}
		}
		
		if (defined $result) {
			unshift @{$self->{responses_queue}}, @remaining;
			return $result;
		}

		unshift @{$self->{responses_queue}}, @remaining;
		select(undef, undef, undef, 0.01);
	}
	
	return undef;
}

sub serverSend {
	my ($self, $msg) = @_;

	if (!$self->{use_rust}) {
		return unless $self->serverAlive;
		return $self->SUPER::serverSend($msg);
	}
	
	# For Rust mode, we need the IPC socket to be alive.
	return unless $self->{ipc_socket} && $self->{ipc_socket}->connected();

	if (ref $msg ne 'HASH') {
		# Raw packets REQUIRE the actual RO server to be connected
		return unless $self->{ro_server_alive};

		# Raw packet data: call pre-send hook (encryption usually happens here)
		if (Plugins::hasHook('Network::serverSend/pre')) {
			Plugins::callHook('Network::serverSend/pre', {msg => \$msg});
		}
		return unless defined $msg;
	}

	my $ipc_msg;
	if (ref $msg eq 'HASH') {
		# If we passed a hash, it's an IPC command (e.g. 'connect')
		$ipc_msg = encode_json($msg) . "\n";
		debug TF("Rust Bridge: Sending IPC Command: %s\n", $msg->{type}), "rust_bridge";
	} else {
		# Raw packet data
		my @data = unpack("C*", $msg);
		$ipc_msg = encode_json({
			type => 'send_packet',
			data => \@data
		}) . "\n";
		debug TF("Rust Bridge: Sending Packet (%s bytes) to Rust\n", length($msg)), "rust_bridge";
	}
	
	$self->{ipc_socket}->send($ipc_msg);
	$self->{ipc_socket}->flush(); # Force flush
	
	if (ref $msg ne 'HASH' && Plugins::hasHook('Network::serverSend')) {
		Plugins::callHook('Network::serverSend', {msg => $msg});
	}
}

sub serverRecv {
	my $self = shift;
	return undef unless $self->serverAlive;

	if (!$self->{use_rust}) {
		return $self->SUPER::serverRecv();
	}
	
	# Process IPC messages to fill queue
	if (dataWaiting(\$self->{ipc_socket})) {
		my $raw_data;
		$self->{ipc_socket}->recv($raw_data, 1024 * 32);
		if (defined $raw_data && length($raw_data) == 0) {
			$self->serverDisconnect();
			return undef;
		}
		$self->_process_ipc_messages($raw_data);
	}

	if (@{$self->{packet_queue}}) {
		my $msg = shift @{$self->{packet_queue}};
		debug TF("Rust Bridge: Dequeued packet (%s bytes)\n", length($msg)), "rust_bridge";
		
		# This is the critical missing piece: plugins hook into PacketTokenizer
		# or direct PacketParser usage. By passing it here, we ensure plugins get it.
		if (Plugins::hasHook('Network::serverRecv')) {
			Plugins::callHook('Network::serverRecv', {msg => \$msg});
		}
		return $msg;
	}
	
	return undef;
}

sub serverDisconnect {
	my $self = shift;
	if ($self->{use_rust}) {
		if ($self->{ipc_socket} && $self->{ipc_socket}->connected()) {
			message T("Disconnecting from Rust IPC Bridge...\n"), "connection";
			close($self->{ipc_socket});
		}
		undef $self->{ipc_socket};
		$self->{ro_server_alive} = 0;
	} else {
		$self->SUPER::serverDisconnect();
	}
}

1;
