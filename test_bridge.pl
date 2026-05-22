use strict;
use lib 'src';
use lib 'src/deps';
use IO::Socket::INET;
use Cwd;

sub start_rust_core {
	my $core_bin = "src/RustCore/target/release/kore-rust-core";
	$core_bin = "src/RustCore/target/debug/kore-rust-core" unless -x $core_bin;
	
	if (-x $core_bin) {
		my $abs_core_bin = Cwd::abs_path($core_bin);
		print "Starting Rust Core Bridge ($abs_core_bin)...\n";
		if ($^O eq 'MSWin32') {
			system("start /B $abs_core_bin");
		} else {
			# Set RUST_LOG to see what's happening
			system("RUST_LOG=debug $abs_core_bin > rust_core_test.log 2>&1 &");
		}
		# Wait for it
		print "Waiting 2s for bind...\n";
		select(undef, undef, undef, 2.0);
	} else {
		die "Rust Core binary not found.\n";
	}
}

print "--- Starting Core ---\n";
start_rust_core();

print "--- Connecting to 9091 ---\n";
my $sock = IO::Socket::INET->new(
	PeerAddr => '127.0.0.1',
	PeerPort => 9091,
	Proto    => 'tcp',
	Timeout  => 5
);

if ($sock) {
	print "SUCCESS: Connected to Rust IPC Bridge!\n";
	close($sock);
} else {
	print "FAILED: Could not connect to Rust IPC Bridge: $!\n";
}

print "--- Cleanup ---\n";
system("killall kore-rust-core");
