package WebStatus;

use strict;
use Plugins;
use Globals;
use Log qw(message error debug);
use IO::Socket::INET;
use File::Spec;
use File::Path qw(make_path);
use Commands;
use Errno qw(EAGAIN EWOULDBLOCK);
use JSON::Tiny qw(encode_json);
use Actor;
use AI;
use Utils qw(dataWaiting);
use Translation qw(T TF);
use MIME::Base64 qw(encode_base64);

our $server_socket;
our $hooks;
our $last_update = 0;
our $last_retry = 0;
our $status_dir = File::Spec->catdir($Settings::logs_folder || 'logs', 'webStatus');
our $cmd_dir = File::Spec->catdir($status_dir, 'cmds');
our $map_dir = File::Spec->catdir($status_dir, 'maps');

# Session tracking for hourly stats
our $start_time = time();
our $start_zeny = undef;
our $start_exp = undef;

Plugins::register('webStatus', 'Web Status Plugin (Improved + Map)', \&onUnload);

$hooks = Plugins::addHooks(
    ['start3', \&onStart, undef],
    ['mainLoop_pre', \&onMainLoop, undef]
);

# Start listening immediately when plugin loads
onStart();

sub onUnload {
    Plugins::delHooks($hooks);
    if ($server_socket) {
        $server_socket->close();
    }
    # Clean up our status file
    if ($char) {
        my $name = $char->name();
        $name =~ s/[^a-zA-Z0-9_\-]//g;
        my $file = File::Spec->catfile($status_dir, "$name.json");
        unlink($file) if -f $file;
    }
}

sub onStart {
    return if $server_socket; # Already started

    my $port = 20035;
    my $max_port = 20045;

    while ($port <= $max_port) {
        $server_socket = IO::Socket::INET->new(
            LocalHost => '127.0.0.1',
            LocalPort => $port,
            Proto     => 'tcp',
            Listen    => 20,
            Reuse     => 1,
            Blocking  => 0
        );
        last if $server_socket;
        $port++;
    }

    if ($server_socket) {
        message TF("WebStatus: Dashboard active on http://localhost:%s/\n", $port), "success";
    } else {
        debug "WebStatus: Port 20035 already in use. This bot will operate in client-only mode (updating status logs for the existing dashboard).\n", "webStatus";
    }
    return 1;
}

sub onMainLoop {
    my $now = time();

    # Check for incoming commands for this bot
    if ($char && $now % 1 == 0) {
        my $name = $char->name();
        $name =~ s/[^a-zA-Z0-9_\-]//g;
        my $cmd_file = File::Spec->catfile($cmd_dir, "$name.cmd");
        if (-f $cmd_file) {
            if (open(my $fh, '<', $cmd_file)) {
                my @cmds = <$fh>;
                close($fh);
                unlink($cmd_file);
                foreach my $cmd (@cmds) {
                    chomp $cmd;
                    next unless $cmd;
                    message "WebStatus: Executing remote command: $cmd\n", "info";
                    Commands::run($cmd);
                }
            }
        }
    }

    # Periodically write our own status
    if ($now - $last_update >= 2) {
        writeStatusFile();
        $last_update = $now;
    }

    # Periodically try to take over the dashboard port if it's free
    if (!$server_socket && $now - $last_retry >= 15) {
        onStart();
        $last_retry = $now;
    }

    return unless $server_socket;

    # Process incoming connections
    for (1..10) {
        my $client_socket = $server_socket->accept();
        last unless $client_socket;

        $client_socket->blocking(0);

        my $request = "";
        my $buffer;
        # Wait a tiny bit for request data if not immediately available
        if (dataWaiting(\$client_socket, 0.01)) {
            sysread($client_socket, $buffer, 2048);
            $request = $buffer || "";
        }

        if ($request =~ /GET \/api\/status/) {
            my @bots = ();
            if (-d $status_dir) {
                opendir(my $dh, $status_dir);
                while (my $f = readdir($dh)) {
                    next unless $f =~ /\.json$/;
                    my $path = File::Spec->catfile($status_dir, $f);
                    if (time() - (stat($path))[9] < 30) { # 30 seconds stale
                        if (open(my $fh, '<', $path)) {
                            local $/;
                            my $json = <$fh>;
                            close($fh);
                            push @bots, $json if $json;
                        }
                    } else {
                        unlink($path);
                    }
                }
                closedir($dh);
            }
            my $resp_body = "[" . join(",", @bots) . "]";
            my $resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n$resp_body";
            $client_socket->send($resp);
            $client_socket->close();
            next;
        }

        # New Map API
        if ($request =~ /GET \/api\/map\?name=([^&\s]+)/) {
            my $map_name = $1;
            $map_name =~ s/[^a-zA-Z0-9_\-]//g;
            my $map_file = File::Spec->catfile($map_dir, "$map_name.json");
            my $resp_body = "{}";
            if (-f $map_file) {
                if (open(my $fh, '<', $map_file)) {
                    local $/;
                    $resp_body = <$fh>;
                    close($fh);
                }
            }
            my $resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n$resp_body";
            $client_socket->send($resp);
            $client_socket->close();
            next;
        }

        if ($request =~ /GET \/cmd\?bot=([^&\s]+)&command=([^&\s\?]+)/) {
            my $target_bot = $1;
            my $command = $2;
            $command =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg; # Better URL decode
            $command =~ s/\+/ /g;

            make_path($cmd_dir) unless -d $cmd_dir;
            my $target_file = File::Spec->catfile($cmd_dir, "$target_bot.cmd");
            if (open(my $fh, '>>', $target_file)) {
                print $fh "$command\n";
                close($fh);
            }

            my $resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nOK";
            $client_socket->send($resp);
            $client_socket->close();
            next;
        }

        # Dashboard HTML
        my $html = <<'HTML';
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenKore Heimdall Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.7);
            --border: rgba(255, 255, 255, 0.1);
            --primary: #6366f1;
            --secondary: #a855f7;
            --success: #10b981;
            --danger: #ef4444;
            --warning: #f59e0b;
            --text-main: #f8fafc;
            --text-dim: #94a3b8;
        }

        * { box-sizing: border-box; }
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: radial-gradient(circle at 0% 0%, #1e1b4b 0%, #0f172a 100%);
            color: var(--text-main);
            margin: 0;
            min-height: 100vh;
            overflow-x: hidden;
        }

        header {
            padding: 1rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            backdrop-filter: blur(10px);
            background: rgba(15, 23, 42, 0.8);
            border-bottom: 1px solid var(--border);
            position: sticky;
            top: 0;
            z-index: 1000;
        }

        .logo-group { display: flex; align-items: center; gap: 12px; }
        .logo-icon { width: 32px; height: 32px; background: linear-gradient(135deg, var(--primary), var(--secondary)); border-radius: 8px; }
        .logo-text { font-size: 1.25rem; font-weight: 700; letter-spacing: -0.02em; }

        .bot-stats { display: flex; gap: 1rem; }
        .stat-pill { background: var(--border); padding: 0.5rem 1rem; border-radius: 99px; font-size: 0.875rem; font-weight: 500; color: var(--text-dim); border: 1px solid transparent; transition: all 0.2s; }
        .stat-pill:hover { border-color: var(--primary); color: var(--text-main); }

        main {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
            gap: 2rem;
            padding: 2rem;
            max-width: 1600px;
            margin: 0 auto;
        }

        .bot-card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 20px;
            padding: 1.25rem;
            backdrop-filter: blur(16px);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
        }

        .bot-card:hover { transform: translateY(-5px); border-color: rgba(99, 102, 241, 0.4); box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04); }

        .bot-header { display: flex; justify-content: space-between; align-items: flex-start; }
        .bot-identity h2 { margin: 0; font-size: 1.1rem; font-weight: 700; }
        .bot-identity span { color: var(--text-dim); font-size: 0.8rem; font-weight: 500; }

        .status-tag { padding: 0.25rem 0.75rem; border-radius: 6px; font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; }
        .tag-idle { background: rgba(148, 163, 184, 0.1); color: #94a3b8; }
        .tag-combat { background: rgba(239, 68, 68, 0.1); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.2); }
        .tag-moving { background: rgba(56, 189, 248, 0.1); color: #7dd3fc; border: 1px solid rgba(56, 189, 248, 0.2); }

        /* Map Container */
        .map-container {
            width: 100%;
            aspect-ratio: 1;
            background: #000;
            border-radius: 12px;
            border: 1px solid var(--border);
            position: relative;
            overflow: hidden;
            cursor: crosshair;
        }
        canvas.map-canvas {
            width: 100%;
            height: 100%;
            image-rendering: pixelated;
        }
        .map-overlay {
            position: absolute;
            top: 8px;
            left: 8px;
            font-size: 0.65rem;
            background: rgba(0,0,0,0.5);
            padding: 4px 8px;
            border-radius: 4px;
            color: #fff;
            pointer-events: none;
        }

        .bars-container { display: flex; flex-direction: column; gap: 0.5rem; }
        .bar-group { display: flex; flex-direction: column; gap: 0.15rem; }
        .bar-header { display: flex; justify-content: space-between; font-size: 0.7rem; font-weight: 600; }
        .bar-label { color: var(--text-dim); }
        .bar-value { color: var(--text-main); }
        .bar-bg { height: 6px; background: rgba(0,0,0,0.3); border-radius: 4px; overflow: hidden; }
        .bar-fill { height: 100%; transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1); border-radius: 4px; }
        .hp-fill { background: linear-gradient(90deg, #ef4444, #f87171); }
        .sp-fill { background: linear-gradient(90deg, #3b82f6, #60a5fa); }
        .exp-fill { background: linear-gradient(90deg, #6366f1, #a855f7); }
        .jexp-fill { background: linear-gradient(90deg, #06b6d4, #22d3ee); }

        .target-box { background: rgba(0,0,0,0.2); border-radius: 8px; padding: 0.5rem; display: flex; justify-content: space-between; align-items: center; }
        .target-info { display: flex; flex-direction: column; gap: 2px; }
        .target-label { font-size: 0.6rem; color: var(--text-dim); text-transform: uppercase; font-weight: 700; }
        .target-name { font-size: 0.8rem; font-weight: 600; color: #fecaca; }
        .target-hp { font-size: 0.85rem; font-weight: 700; color: var(--danger); }

        .grid-stats { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; font-size: 0.75rem; }
        .grid-stat { display: flex; justify-content: space-between; padding-bottom: 2px; border-bottom: 1px solid var(--border); }
        .gs-label { color: var(--text-dim); }
        .gs-value { font-weight: 600; }

        .cmd-group { display: flex; gap: 8px; margin-top: 0.25rem; }
        .cmd-input { flex: 1; background: rgba(0,0,0,0.3); border: 1px solid var(--border); border-radius: 8px; padding: 6px 10px; color: var(--text-main); font-size: 0.8rem; outline: none; }
        .cmd-input:focus { border-color: var(--primary); }
        .cmd-btn { background: var(--primary); border: none; border-radius: 8px; padding: 0 12px; color: white; cursor: pointer; font-weight: 600; font-size: 0.75rem; }

        @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
        .active-dot { width: 8px; height: 8px; background: var(--success); border-radius: 50%; display: inline-block; margin-right: 6px; animation: pulse 2s infinite; }
    </style>
</head>
<body>
    <header>
        <div class="logo-group">
            <div class="logo-icon"></div>
            <div class="logo-text">HEIMDALL</div>
        </div>
        <div class="bot-stats">
            <div class="stat-pill" id="total-bots">0 Bots</div>
            <div class="stat-pill" id="total-zeny">0 Zeny</div>
        </div>
    </header>

    <main id="container"></main>

    <script>
        const container = document.getElementById('container');
        const mapCache = {};

        async function fetchMap(mapName) {
            if (mapCache[mapName]) return mapCache[mapName];
            try {
                const res = await fetch(`/api/map?name=${mapName}`);
                const data = await res.json();
                if (data.data) {
                    // Decode base64 map data
                    const binary = atob(data.data);
                    const bytes = new Uint8Array(binary.length);
                    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
                    data.decoded = bytes;
                    mapCache[mapName] = data;
                    return data;
                }
            } catch (e) { console.error("Map load failed", e); }
            return null;
        }

        function drawMap(canvas, bot) {
            const ctx = canvas.getContext('2d');
            const map = mapCache[bot.map];
            if (!map) return;

            const w = map.width;
            const h = map.height;

            // Adjust canvas internal size
            if (canvas.width !== w || canvas.height !== h) {
                canvas.width = w;
                canvas.height = h;
            }

            // Draw walkability
            const imgData = ctx.createImageData(w, h);
            for (let i = 0; i < map.decoded.length; i++) {
                const type = map.decoded[i];
                const x = i % w;
                const y = h - 1 - Math.floor(i / w); // Flip Y
                const idx = (y * w + x) * 4;

                let r, g, b;
                if (type === 1) { r=40; g=40; b=50; } // Walkable (Dark gray)
                else if (type === 0) { r=10; g=10; b=15; } // Wall (Near black)
                else if (type === 4) { r=30; g=60; b=100; } // Water (Deep blue)
                else { r=20; g=20; b=25; }

                imgData.data[idx] = r;
                imgData.data[idx+1] = g;
                imgData.data[idx+2] = b;
                imgData.data[idx+3] = 255;
            }
            ctx.putImageData(imgData, 0, 0);

            // Draw Actors
            if (bot.actors) {
                bot.actors.forEach(actor => {
                    ctx.fillStyle = actor.type === 'monster' ? '#ef4444' : (actor.type === 'player' ? '#6366f1' : '#a855f7');
                    ctx.fillRect(actor.x - 1, h - 1 - actor.y - 1, 3, 3);
                });
            }

            // Draw Character (Me)
            ctx.fillStyle = '#10b981';
            ctx.shadowBlur = 4;
            ctx.shadowColor = '#10b981';
            ctx.fillRect(bot.pos_x - 1, h - 1 - bot.pos_y - 1, 4, 4);
            ctx.shadowBlur = 0;
        }

        async function refresh() {
            try {
                const res = await fetch('/api/status');
                const bots = await res.json();

                document.getElementById('total-bots').textContent = `${bots.length} Active Bots`;
                let totalZeny = 0;
                const activeIds = bots.map(b => b.name.replace(/\s/g, '_'));

                for (const bot of bots) {
                    const id = bot.name.replace(/\s/g, '_');
                    totalZeny += parseInt(bot.zeny || 0);

                    let card = document.getElementById('bot-' + id);
                    if (!card) {
                        card = document.createElement('div');
                        card.id = 'bot-' + id;
                        card.className = 'bot-card';
                        container.appendChild(card);
                    }

                    const input = card.querySelector('.cmd-input');
                    const currentInput = (input && document.activeElement === input) ? input.value : '';

                    const targetHtml = bot.target_name ? `
                        <div class="target-box">
                            <div class="target-info">
                                <div class="target-label">Target</div>
                                <div class="target-name">${bot.target_name}</div>
                            </div>
                            <div class="target-hp">${bot.target_hp_pct}%</div>
                        </div>
                    ` : '';

                    card.innerHTML = `
                        <div class="bot-header">
                            <div class="bot-identity">
                                <h2><div class="active-dot"></div>${bot.name}</h2>
                                <span>${bot.job} • ${bot.lv}/${bot.j_lv}</span>
                            </div>
                            <div class="status-tag ${bot.status_class}">${bot.display_status}</div>
                        </div>

                        <div class="map-container">
                            <canvas id="canvas-${id}" class="map-canvas"></canvas>
                            <div class="map-overlay">${bot.map} (${bot.pos_x}, ${bot.pos_y})</div>
                        </div>

                        <div class="bars-container">
                            <div class="bar-group">
                                <div class="bar-header"><span class="bar-label">HP</span><span class="bar-value">${bot.hp}/${bot.hp_max}</span></div>
                                <div class="bar-bg"><div class="bar-fill hp-fill" style="width:${bot.hp_pct}%"></div></div>
                            </div>
                            <div class="bar-group">
                                <div class="bar-header"><span class="bar-label">SP</span><span class="bar-value">${bot.sp}/${bot.sp_max}</span></div>
                                <div class="bar-bg"><div class="bar-fill sp-fill" style="width:${bot.sp_pct}%"></div></div>
                            </div>
                            <div class="bar-group">
                                <div class="bar-header"><span class="bar-label">Base Exp</span><span class="bar-value">${bot.b_exp.toLocaleString()} / ${bot.b_exp_max.toLocaleString()} (${bot.b_exp_pct}%)</span></div>
                                <div class="bar-bg"><div class="bar-fill exp-fill" style="width:${bot.b_exp_pct}%"></div></div>
                            </div>
                            <div class="bar-group">
                                <div class="bar-header"><span class="bar-label">Job Exp</span><span class="bar-value">${bot.j_exp.toLocaleString()} / ${bot.j_exp_max.toLocaleString()} (${bot.j_exp_pct}%)</span></div>
                                <div class="bar-bg"><div class="bar-fill jexp-fill" style="width:${bot.j_exp_pct}%"></div></div>
                            </div>
                        </div>

                        ${targetHtml}

                        <div class="grid-stats">
                            <div class="grid-stat"><span class="gs-label">Weight</span><span class="gs-value">${bot.weight_pct}%</span></div>
                            <div class="grid-stat"><span class="gs-label">Zeny</span><span class="gs-value">${bot.zeny.toLocaleString()}</span></div>
                            <div class="grid-stat"><span class="gs-label">Inv</span><span class="gs-value">${bot.inv_size}/100</span></div>
                        </div>

                        <div class="cmd-group">
                            <input type="text" class="cmd-input" placeholder="Command..." value="${currentInput}" 
                                onkeydown="if(event.key==='Enter') sendCmd('${id}', this.value, this)">
                            <button class="cmd-btn" onclick="sendCmd('${id}', this.previousElementSibling.value, this.previousElementSibling)">GO</button>
                        </div>
                    `;

                    if (currentInput) {
                        const newInput = card.querySelector('.cmd-input');
                        newInput.focus();
                        newInput.setSelectionRange(currentInput.length, currentInput.length);
                    }

                    // Update Map
                    await fetchMap(bot.map);
                    drawMap(document.getElementById(`canvas-${id}`), bot);
                }

                Array.from(container.children).forEach(child => {
                    if (!activeIds.includes(child.id.replace('bot-', ''))) child.remove();
                });

                document.getElementById('total-zeny').textContent = `${totalZeny.toLocaleString()} Zeny`;

            } catch (e) { console.error(e); }
        }

        async function sendCmd(botId, cmd, inputEl) {
            if (!cmd) return;
            try {
                await fetch(`/cmd?bot=${botId}&command=${encodeURIComponent(cmd)}`);
                inputEl.value = '';
                inputEl.placeholder = 'Sent!';
                setTimeout(() => inputEl.placeholder = 'Command...', 2000);
            } catch (e) { alert('Failed'); }
        }

        setInterval(refresh, 2000);
        refresh();
    </script>
</body>
</html>
HTML
        my $resp = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n$html";
        $client_socket->send($resp);
        $client_socket->close();
    }
}

sub writeStatusFile {
    return unless $char;
    make_path($status_dir) unless -d $status_dir;
    make_path($map_dir) unless -d $map_dir;

    my $name = $char->name();
    my $safe_name = $name;
    $safe_name =~ s/[^a-zA-Z0-9_\-]//g;
    my $file = File::Spec->catfile($status_dir, "$safe_name.json");

    # Handle Map Export (once per map change)
    if ($field && $field->name()) {
        my $map_name = $field->name();
        my $map_json_file = File::Spec->catfile($map_dir, "$map_name.json");
        if (!-f $map_json_file) {
            my $map_data = {
                name => $map_name,
                width => int($field->width()),
                height => int($field->height()),
                data => encode_base64($field->{rawMap}, "")
            };
            if (open(my $mfh, '>', $map_json_file)) {
                print $mfh encode_json($map_data);
                close($mfh);
            }
        }
    }

    my $job = $jobs_lut{$char->{jobID}} || 'Novice';

    # Target discovery
    my $target_name = undef;
    my $target_hp_pct = 0;
    my $attack_idx = AI::findAction('attack');
    if ($attack_idx ne '') {
        my $target = Actor::get(AI::args($attack_idx)->{ID});
        if ($target) {
            $target_name = $target->name();
            # Try multiple common HP sources
            if (defined $target->{hp_percent}) {
                $target_hp_pct = $target->{hp_percent};
            } elsif ($target->{hp_max} && $target->{hp_max} > 0) {
                $target_hp_pct = int(($target->{hp} / $target->{hp_max}) * 100);
            } elsif (defined $target->{hp} && $target->{hp} > 0 && $target->{hp} <= 100) {
                # Some servers send percentage in the 'hp' field
                $target_hp_pct = $target->{hp};
            } else {
                # If target is alive but HP is unknown, default to 100
                $target_hp_pct = 100;
            }
        }
    }

    # Gather Actor positions (nearby only)
    my @actor_list = ();
    foreach my $m (@{$monstersList}) {
        next unless ($m && $m->{pos_to});
        push @actor_list, { type => 'monster', x => int($m->{pos_to}{x}), y => int($m->{pos_to}{y}) };
    }
    foreach my $p (@{$playersList}) {
        next unless ($p && $p->{pos_to});
        push @actor_list, { type => 'player', x => int($p->{pos_to}{x}), y => int($p->{pos_to}{y}) };
    }
    foreach my $n (@{$npcsList}) {
        next unless ($n && $n->{pos_to});
        push @actor_list, { type => 'npc', x => int($n->{pos_to}{x}), y => int($n->{pos_to}{y}) };
    }

    my $data = {
        name => $name,
        job => $job,
        lv => int($char->{lv} || 0),
        j_lv => int($char->{lv_job} || 0),
        hp => int($char->{hp} || 0),
        hp_max => int($char->{hp_max} || 1),
        hp_pct => sprintf("%.1f", (($char->{hp} || 0) / ($char->{hp_max} || 1)) * 100),
        sp => int($char->{sp} || 0),
        sp_max => int($char->{sp_max} || 1),
        sp_pct => sprintf("%.1f", (($char->{sp} || 0) / ($char->{sp_max} || 1)) * 100),
        b_exp => int($char->{exp} || 0),
        b_exp_max => int($char->{exp_max} || 1),
        b_exp_pct => sprintf("%.1f", (($char->{exp} || 0) / ($char->{exp_max} || 1)) * 100),
        j_exp => int($char->{exp_job} || 0),
        j_exp_max => int($char->{exp_job_max} || 1),
        j_exp_pct => sprintf("%.1f", (($char->{exp_job} || 0) / ($char->{exp_job_max} || 1)) * 100),
        zeny => int($char->{zeny} || 0),
        weight_pct => sprintf("%.1f", $char->weight_percent()),
        inv_size => int($char->inventory->size()),
        map => $field ? $field->name() : 'Unknown',
        pos_x => int($char->{pos}{x} || 0),
        pos_y => int($char->{pos}{y} || 0),
        actors => \@actor_list,
        target_name => $target_name,
        target_hp_pct => $target_hp_pct,
        display_status => ucfirst($AI::ai_seq[0] || 'Idle'),
        status_class => 'tag-idle',
        last_updated => time()
    };

    $data->{status_class} = 'tag-combat' if $data->{display_status} =~ /attack/i;
    $data->{status_class} = 'tag-moving' if $data->{display_status} =~ /route|move|teleport/i;

    my $json = encode_json($data);

    if (open(my $fh, '>', $file)) {
        print $fh $json;
        close($fh);
    }
}
1;
