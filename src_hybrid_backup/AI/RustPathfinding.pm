#########################################################################
#  OpenKore - Rust Pathfinding Wrapper
#
#  This module provides an interface to the Rust Core's A* pathfinding.
#########################################################################
package AI::RustPathfinding;

use strict;
use Globals;
use Log qw(debug error);
use Translation qw(TF);

sub new {
	my ($class, @args) = @_;
	my $self = {
		solution => [],
		start => undef,
		dest => undef,
		field => undef,
	};
	bless $self, $class;
	$self->reset(@args) if (@args);
	return $self;
}

sub reset {
	my ($self, %args) = @_;
	$self->{start} = $args{start};
	$self->{dest} = $args{dest};
	$self->{field} = $args{field};
	$self->{solution} = [];
}

sub run {
	my ($self, $solution_ref) = @_;
	
	debug TF("AI::RustPathfinding::run: from %s,%s to %s,%s\n", 
		$self->{start}{x}, $self->{start}{y}, $self->{dest}{x}, $self->{dest}{y}), "rust_bridge";

	if (!$net || !$net->isa('Network::RustBridge')) {
		error "Rust pathfinding requires Network::RustBridge\n";
		return -1;
	}

	my $field = $self->{field} || $Globals::field;
	if (!$field) {
		debug "Rust pathfinding failed: No field object available\n", "rust_bridge";
		return -1;
	}

	my $points = $net->find_path(
		$field->baseName,
		$self->{start},
		$self->{dest}
	);

	if (defined $points) {
		if (@$points) {
			@$solution_ref = ();
			for my $pt (@$points) {
				push @$solution_ref, { x => $pt->[0], y => $pt->[1] };
			}
			return scalar(@$solution_ref);
		} else {
			# Path not found
			$self->{solution} = [];
			return -1; 
		}
	} else {
		# Timeout or error
		$self->{solution} = [];
		return -1; 
	}
}

sub runcount {
	my ($self) = @_;
	my @solution;
	return $self->run(\@solution);
}

1;
