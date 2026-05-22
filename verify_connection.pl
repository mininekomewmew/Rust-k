use strict;
use IO::Select;

# Start OpenKore in background
open(my $ph, "|-", "perl -Isrc -Isrc/deps openkore.pl --control=control --interface=Console") or die $!;

# Send profile choice
print $ph "1\n";

# Wait for a while to let it connect
sleep(15);

# Quit
print $ph "quit\n";
close($ph);
