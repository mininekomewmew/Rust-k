use strict;
use warnings;
use lib 'c:/Users/Minicats/Downloads/opk/Heimdall-V2 Updated/src';
use Network::Send::ServerType0;

my $sender = Network::Send::ServerType0->new();
my $bytes = $sender->reconstruct({
	switch => 'warp_select',
	skillID => 26,
	mapName => "Random"
});

print "HEIMDALL BYTES: " . unpack("H*", $bytes) . "\n";
