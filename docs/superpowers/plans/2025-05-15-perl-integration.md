# Perl Integration (Phase 4, Task 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Rust core actor management into OpenKore by providing a way for Perl to query nearby actors from the Rust side.

**Architecture:**
Update `Network::RustBridge.pm` with a `get_nearby` method that performs synchronous IPC with the Rust core. Add a diagnostic command `actors_rust` to `Commands.pm` to verify Perl can receive actor data from Rust.

**Tech Stack:** Perl, JSON::Tiny (used by RustBridge).

---

### Task 1: Update RustBridge.pm

**Files:**
- Modify: `src/Network/RustBridge.pm`

- [ ] **Step 1: Implement get_nearby method**
Add `get_nearby` to `src/Network/RustBridge.pm`. It should send a `{ type: 'get_nearby', x: ..., y: ..., range: ... }` message and wait for `{ type: 'nearby_actors', actors: [...] }`.

```perl
sub get_nearby {
	my ($self, $x, $y, $range) = @_;
	return undef unless $self->serverAlive;

	$self->serverSend({
		type => 'get_nearby',
		x => int($x),
		y => int($y),
		range => int($range)
	});

	my $timeout = time + 2;
	while (time < $timeout) {
		if (!@{$self->{responses_queue}}) {
			if (dataWaiting(\$self->{remote_socket}, 0.1)) {
				my $raw_data;
				$self->{remote_socket}->recv($raw_data, 4096);
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
	
	warning T("Rust get_nearby timed out\n");
	return undef;
}
```

- [ ] **Step 2: Verify syntax**
Run: `perl -Isrc src/Network/RustBridge.pm` (or `perl -c -Isrc src/Network/RustBridge.pm`)
Expected: `src/Network/RustBridge.pm syntax OK`

### Task 2: Update Commands.pm

**Files:**
- Modify: `src/Commands.pm`

- [ ] **Step 1: Register actors_rust command**
Search for `sub initHandlers` and add `actors_rust` to the `register` calls.

```perl
		['actors_rust', T("Display actors known to Rust core."), \&cmdActorsRust],
```

- [ ] **Step 2: Implement cmdActorsRust**
Add the `cmdActorsRust` subroutine.

```perl
sub cmdActorsRust {
	if ($config{networkCore} eq 'rust') {
		if ($Globals::net->can('get_nearby')) {
			my $actors = $Globals::net->get_nearby($Globals::char->{pos}{x}, $Globals::char->{pos}{y}, 50);
			if ($actors && @$actors) {
				foreach my $actor (@$actors) {
					Log::message(sprintf("Rust Actor: %s (ID: %d) at %d,%d\n", $actor->{name}, $actor->{id}, $actor->{x}, $actor->{y}), "system");
				}
			} elsif ($actors) {
				Log::message("No actors reported by Rust core nearby.\n", "system");
			} else {
				Log::error("Failed to get actors from Rust core (timeout or error).\n");
			}
		} else {
			Log::error("Current network core does not support get_nearby.\n");
		}
	} else {
		Log::error("Rust core is not active (networkCore != rust).\n");
	}
}
```

- [ ] **Step 3: Verify syntax**
Run: `perl -c -Isrc src/Commands.pm`
Expected: `src/Commands.pm syntax OK`

### Task 3: Final Verification

- [ ] **Step 1: Check for any other Actor-related Perl code that needs updating**
Briefly check `src/Actor.pm` to ensure no immediate conflicts.

- [ ] **Step 2: Commit changes**
```bash
git add src/Network/RustBridge.pm src/Commands.pm
git commit -m "feat(perl): add get_nearby to RustBridge and actors_rust command"
```
