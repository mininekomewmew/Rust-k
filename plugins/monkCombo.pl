package monkCombo;

use strict;
use Plugins;
use Globals;
use Log qw(message debug);
use Skill;
use Network::Send;
use Utils;
use Time::HiRes qw(time);

# This should print when the plugin is loaded by OpenKore
message "MonkCombo plugin: Loading...\n", "info";

Plugins::register("monkCombo", "Automates Monk combo skills", \&on_unload);

my $hooks = Plugins::addHooks(
	['packet_skilluse', \&on_packet_skilluse],
	['packet/combo_delay', \&on_combo_delay],
	['packet/actor_status_active', \&on_actor_status_active],
	['AI_pre', \&on_AI_pre],
	['AI_post', \&on_AI_post]
);

my $last_skill_used = 0;
my $combo_active = 0;
my $combo_target_id = undef;
my $last_attack_id = undef;
my $last_triple_tick = 0;
my $last_attempt_time = 0;
my $spam_interval = 0.1; # Spam interval in seconds

sub on_unload {
	Plugins::delHooks($hooks);
}

sub on_packet_skilluse {
	my (undef, $args) = @_;
	return unless $args->{sourceID} eq $accountID;
	
	my $skillID = $args->{skillID};
	debug "MonkCombo: packet_skilluse ID: $skillID, Target: " . Utils::getHex($args->{targetID}) . "\n", "monkCombo";

	# Force target ID if we use Triple Attack
	if ($skillID == 263) { # MO_TRIPLEATTACK
		debug "MonkCombo: Triple Attack detected! Storing Target: " . Utils::getHex($args->{targetID}) . "\n", "monkCombo";
		$combo_target_id = $args->{targetID};
		$last_triple_tick = time();
		$last_skill_used = 263;
	} elsif ($skillID == 272) { # MO_CHAINCOMBO
		debug "MonkCombo: Chain Combo SUCCESS! Resetting spam.\n", "monkCombo";
		$last_skill_used = 272;
		$combo_target_id = $args->{targetID} if $args->{targetID};
		# We used it once, don't spam 272 anymore, maybe wait for status 89 for 273
		# Actually, keep combo_active true if we want to move to phase 3 immediately
		# But usually status 89 will refresh for the next window.
	} elsif ($skillID == 273) { # MO_COMBOFINISH
		debug "MonkCombo: Combo Finish SUCCESS!\n", "monkCombo";
		$last_skill_used = 273;
		$combo_active = 0;
	}
}

sub on_combo_delay {
	my (undef, $args) = @_;
	return unless $config{monkCombo};
	return unless $args->{ID} eq $accountID;

	message "MonkCombo: Combo Window Opened (Packet 01D2, Delay: $args->{delay}ms)\n", "success";
	$combo_active = 1;
	
	# Try to get target from various sources if not set
	$combo_target_id = $ai_v{attackID} if !$combo_target_id && $ai_v{attackID};
	
	debug "MonkCombo: 01D2 Active. Target: " . ($combo_target_id ? Utils::getHex($combo_target_id) : "NONE") . "\n", "monkCombo";
	$last_attempt_time = 0; # Trigger immediate attempt in next AI loop
}

sub on_actor_status_active {
	my (undef, $args) = @_;
	return unless $config{monkCombo};
	return unless $args->{ID} eq $accountID;

	# EFST_COMBOATTACK = 89
	if ($args->{type} == 89) {
		if ($args->{flag} == 1) {
			message "MonkCombo: Combo Window Opened (Status 89)!\n", "success";
			$combo_active = 1;
			$combo_target_id = $ai_v{attackID} if !$combo_target_id && $ai_v{attackID};
			debug "MonkCombo: Status 89 Active. Target: " . ($combo_target_id ? Utils::getHex($combo_target_id) : "NONE") . "\n", "monkCombo";
			$last_attempt_time = 0; # Trigger immediate attempt
		} else {
			debug "MonkCombo: Combo window CLOSED (Status 89)\n", "monkCombo";
			$combo_active = 0;
		}
	}
}

sub on_AI_post {
	# Reset sequence if target changed or we are no longer attacking
	my $current_attack_id = $ai_v{attackID} || "";
	if ($current_attack_id ne ($last_attack_id || "")) {
		if ($last_skill_used != 0 && !$combo_active) {
			debug "MonkCombo: Resetting sequence (Target changed or lost)\n", "monkCombo";
			$last_skill_used = 0;
			$combo_target_id = undef;
		}
		$last_attack_id = $current_attack_id;
	}
}

sub on_AI_pre {
	return unless $config{monkCombo};
	
	# Priority 1: Combo window active AND we have a target
	if ($combo_active && $combo_target_id) {
		# SP Check
		if ($config{monkCombo_sp}) {
			my $val = $config{monkCombo_sp};
			if ($val =~ /^(\d+)%$/) {
				my $percent = $1;
				if ($char->sp_percent < $percent) {
					return;
				}
			} else {
				if ($char->{sp} < $val) {
					return;
				}
			}
		}

		my $target = Actor::get($combo_target_id);
		if ($target) {
			# Spam logic: only try every $spam_interval
			if (time() - $last_attempt_time >= $spam_interval) {
				execute_combo($target);
				$last_attempt_time = time();
			}
			return;
		}
	}
	
	# Priority 2: Fallback trigger after Triple Attack (if packet/status missed or delayed)
	if ($last_skill_used == 263 && (time() - $last_triple_tick < 1.0) && $combo_target_id) {
		# SP Check
		if ($config{monkCombo_sp}) {
			my $val = $config{monkCombo_sp};
			if ($val =~ /^(\d+)%$/) {
				if ($char->sp_percent < $1) { return; }
			} else {
				if ($char->{sp} < $val) { return; }
			}
		}

		my $target = Actor::get($combo_target_id);
		if ($target && (time() - $last_attempt_time >= $spam_interval)) {
			debug "MonkCombo: Fallback attempt following Triple Attack\n", "monkCombo";
			execute_combo($target);
			$last_attempt_time = time();
		}
	}
}

sub execute_combo {
	my ($target) = @_;
	my $target_id = $target->{ID};

	# Determine next skill
	my $next_skill_id = 0;
	if ($last_skill_used == 272) {
		# We just successfully used Chain Combo, next is Combo Finish
		$next_skill_id = 273 if $config{monkCombo_finish} || !defined $config{monkCombo_finish};
	} else {
		# Triple Attack or first stage
		$next_skill_id = 272 if $config{monkCombo_chain} || !defined $config{monkCombo_chain};
	}

	if ($next_skill_id) {
		my $skill_handle = Skill->new(idn => $next_skill_id)->getHandle();
		my $skill_data = $char->{skills}{$skill_handle};

		if ($skill_data) {
			if ($char->{sp} >= ($skill_data->{sp} || 0)) {
				# Check for spirit spheres for Combo Finish (Skill 273)
				if ($next_skill_id == 273 && ($char->{spirits} || 0) < 1) {
					debug "MonkCombo: Skipping Combo Finish (No spirit spheres)\n", "monkCombo";
					$combo_active = 0;
					$last_skill_used = 0;
					return;
				}

				debug "MonkCombo: Sending skill $next_skill_id (Lv: $skill_data->{lv}) on " . $target->name . "\n", "monkCombo";
				$messageSender->sendSkillUse($next_skill_id, $skill_data->{lv}, $target_id);
				
				# We DON'T set combo_active = 0 here. 
				# We let on_packet_skilluse set last_skill_used when success is confirmed, 
				# or on_actor_status_active set combo_active = 0 when window closes.
			} else {
				debug "MonkCombo: Skill $next_skill_id not usable (Need " . ($skill_data->{sp} || 0) . " SP, have " . $char->{sp} . ")\n", "monkCombo";
				$combo_active = 0;
			}
		} else {
			debug "MonkCombo: Skill $next_skill_id not found in your skills list!\n", "monkCombo";
			$combo_active = 0;
		}
	}
}

1;
