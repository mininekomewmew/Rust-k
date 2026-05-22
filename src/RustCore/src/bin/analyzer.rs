use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use serde::Deserialize;

#[derive(Deserialize)]
struct MiningEntry {
    direction: String,
    hex_data: String,
}

fn load_reference(path: &str) -> HashMap<u16, i32> {
    let mut map = HashMap::new();
    if let Ok(file) = File::open(path) {
        let reader = BufReader::new(file);
        for line in reader.lines().flatten() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                if let (Ok(switch), Ok(len)) = (u16::from_str_radix(parts[0], 16), parts[1].parse::<i32>()) {
                    map.insert(switch, len);
                }
            }
        }
    }
    map
}

fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let log_path = args.get(1).map(|s| s.as_str()).unwrap_or("../../logs/mining.jsonl");
    let ref_path = args.get(2).map(|s| s.as_str()).unwrap_or("../../tables/tRO/recvpackets.txt");

    let known_packets = load_reference(ref_path);
    println!("Loaded {} known packets from reference.", known_packets.len());

    let file = File::open(log_path)?;
    let reader = BufReader::new(file);

    let mut all_bytes = Vec::new();
    for line in reader.lines() {
        let entry_res: Result<MiningEntry, _> = serde_json::from_str(&line?);
        if let Ok(entry) = entry_res {
            if entry.direction == "recv" {
                if let Ok(decoded) = hex::decode(entry.hex_data) {
                    all_bytes.extend(decoded);
                }
            }
        }
    }

    println!("Analyzing {} bytes...", all_bytes.len());

    let mut pos = 0;
    while pos + 2 <= all_bytes.len() {
        let switch = u16::from_le_bytes([all_bytes[pos], all_bytes[pos+1]]);
        let switch_hex = format!("{:04X}", switch);

        // 1. Check if it's a known packet from our reference
        if let Some(&len) = known_packets.get(&switch) {
            if len == -1 {
                if pos + 4 <= all_bytes.len() {
                    let var_len = u16::from_le_bytes([all_bytes[pos+2], all_bytes[pos+3]]) as usize;
                    if var_len >= 4 && pos + var_len <= all_bytes.len() {
                        println!("{} {} (Known Variable)", switch_hex, -1);
                        pos += var_len;
                        continue;
                    }
                }
            } else if pos + (len as usize) <= all_bytes.len() {
                println!("{} {} (Known Fixed)", switch_hex, len);
                pos += len as usize;
                continue;
            }
        }

        // 2. Not in reference. Try to find the next known packet to guess the length.
        let mut found_sync = false;
        for lookahead in 2..100 { // Search up to 100 bytes ahead
            if pos + lookahead + 2 > all_bytes.len() { break; }
            let next_switch = u16::from_le_bytes([all_bytes[pos+lookahead], all_bytes[pos+lookahead+1]]);
            if known_packets.contains_key(&next_switch) && next_switch != 0 {
                println!("{} {} (GUESSED - Mystery gap of {} bytes before known {})", 
                    switch_hex, lookahead, lookahead, format!("{:04X}", next_switch));
                pos += lookahead;
                found_sync = true;
                break;
            }
        }

        if !found_sync {
            println!("{} (STILL UNKNOWN - No sync point found in next 100 bytes)", switch_hex);
            pos += 2; // Desperate skip
        }
    }

    Ok(())
}
