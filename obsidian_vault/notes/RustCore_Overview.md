# OpenKore Rust Core Knowledge Base

## Architecture
- **Rust Core**: Standalone binary in `src/RustCore`. Handles low-level TCP and streams raw bytes.
- **Perl Bridge**: `Network::RustBridge` in `src/Network/RustBridge.pm`. IPC client for Rust Core.
- **IPC Protocol**: JSON-over-TCP on `127.0.0.1:9091`.

## Protocol Reference

### Commands (Perl -> Rust)
- `connect`: `{ "type": "connect", "host": "...", "port": "..." }` (Port can be string or integer).
- `send_packet`: `{ "type": "send_packet", "data": [byte1, byte2, ...] }`

### Messages (Rust -> Perl)
- `packet_received`: Contains an `unpacked` object representing the parsed packet.
  - `raw`: `{ "type": "packet_received", "unpacked": { "packet_type": "raw", "switch": "XXXX", "data": [...] } }`
  - `account_info`: `{ "type": "packet_received", "unpacked": { "packet_type": "account_info", "account_id": ..., ... } }`
- `connection_status`: `{ "type": "connection_status", "connected": true/false, "addr": "..." }`

## Unpacking Flow (Phase 2)

Phase 2 introduced a "hybrid" unpacking approach to handle complex encryption/decryption while moving towards a more structured core.

### 1. Rust-Side Unpacking (`UnpackedPacket`)
The Rust Core now attempts to unpack critical packets before sending them to Perl. This is defined in `src/RustCore/src/network/packets.rs` via the `UnpackedPacket` enum.

- **Raw Fallback**: Most packets are still sent as `raw` to preserve compatibility with Perl-side decryption hooks.
- **Structured Packets**: Specific packets (e.g., `0x0AC4` Account Info) are parsed into structured JSON objects by Rust.

### 2. Perl-Side Handling (`RustBridge.pm`)
The `Network::RustBridge` handles the incoming IPC messages:
- **Raw Packets**: Converted back to binary strings and passed through the `Network::serverRecv` hook. This allows legacy plugins (like XOR decryption) to work without modification.
- **Structured Packets**: Passed directly as hash references into the OpenKore packet queue.

## Troubleshooting

### Unknown switch: 5F91
- **Cause**: Double decryption. Rust Core was XORing 0x55, and then Perl plugins were XORing 0x55 again.
- **Fix**: Rust Core made transparent (pass-through). Perl plugins handle decryption as they do in the legacy core.

### Timeout waiting for confirmation
- **Cause**: IPC command parsing failure (e.g., port type mismatch).
- **Fix**: Changed `port` type in Rust to `serde_json::Value` to accept both strings and numbers from Perl.

## Packet Mining & Analysis

Tools for protocol research and packet capture.

### Packet Mining (`mine` command)
Packet mining captures raw network traffic during a session for later analysis.

- **Usage**: Type `mine` in the OpenKore console.
- **Output**: Logs are stored in `logs/mining.jsonl`.
- **Format**: JSON Lines (JSONL) containing timestamp, direction, and hex data.

### Packet Analyzer
A standalone Rust tool to analyze mined packet logs and identify patterns or switches.

- **Location**: `src/RustCore/src/bin/analyzer.rs`
- **Run**: `cd src/RustCore && cargo run --bin packet-analyzer -- ../../logs/mining.jsonl`
- **Features**:
  - Combines all received chunks into a continuous stream.
  - Applies heuristics to identify potential switches and variable-length headers.
  - Suggests draft `recvpackets.txt` entries.
