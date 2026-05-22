use strict;
use IO::Socket::INET;
use Time::HiRes qw(sleep);

my $host = 'ro.djserver.win';
my $port = 6900;

print "Connecting to $host:$port...\n";
my $sock = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Proto    => 'tcp',
    Timeout  => 5
);

if (!$sock) {
    die "Failed to connect: $!\n";
}

print "Connected! Waiting for 2s to see if server sends anything...\n";
sleep(2);

my $buf;
$sock->recv($buf, 1024);

if (defined $buf && length($buf) > 0) {
    print "Received " . length($buf) . " bytes from server.\n";
    print "Hex: " . unpack("H*", $buf) . "\n";
    
    # Check if first 2 bytes match 5F91 (Little Endian)
    # 5F91 means raw bytes 91 5F
    # My log showed switch 5F91, which in Little Endian is 91 5F.
} else {
    print "Server sent nothing.\n";
}

close($sock);
