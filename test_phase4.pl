use strict;

# Start OpenKore in background
open(my $ph, "|-", "perl -Isrc -Isrc/deps openkore.pl --control=control --interface=Console") or die $!;

# Send profile choice (DJ)
print $ph "1\n";
sleep(15);

# Run the new diagnostic command
print $ph "actors_rust\n";
sleep(5);

# Quit
print $ph "quit\n";
close($ph);
