# src/test/NetworkProxyTest.pm
package NetworkProxyTest;
use strict;
use Test::More;
use Network::PacketParser;

sub start {
    my $parser = Network::PacketParser->new();
    ok(defined $parser, "PacketParser object created");

    # Try to call process_via_proxy. It should return undef because no proxy is running.
    my $result = $parser->process_via_proxy("dummy data");
    is($result, undef, "process_via_proxy returns undef when no proxy is running");
}

1;
