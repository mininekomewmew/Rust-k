# IPC Discovery Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a bot registry system in `logs/bots.registry` to allow `kore-console` to discover running Rust Core instances.

**Architecture:** Rust Core appends connection info (PID, BotID, Port) to a shared file on startup. Kore Console reads and parses this file to list active instances.

**Tech Stack:** Rust, Tokio, Serde.

---

### Task 1: Rust Core - Registry Writing Logic

**Files:**
- Modify: `src/RustCore/src/main.rs`

- [ ] **Step 1: Implement registry append in main.rs**

In `main.rs`, after `IpcServer::bind`, add logic to log registration.

```rust
// In main.rs, inside main(), after ipc_server binding:
let bot_id = std::env::var("KORE_BOT_ID").unwrap_or_else(|_| "default".to_string());
let port = ipc_server.listener.local_addr()?.port();
let pid = std::process::id();
let entry = format!("{},{},{}\n", pid, bot_id, port);
let mut file = tokio::fs::OpenOptions::new()
    .create(true)
    .append(true)
    .open("logs/bots.registry")
    .await?;
tokio::io::AsyncWriteExt::write_all(&mut file, entry.as_bytes()).await?;
```

- [ ] **Step 2: Commit**

```bash
git add src/RustCore/src/main.rs
git commit -m "feat(ipc): add bot registration to logs/bots.registry"
```

### Task 2: Kore Console - Registry Reading Logic

**Files:**
- Modify: `src/RustCore/src/bin/console.rs`

- [ ] **Step 1: Implement reading registry in console.rs**

```rust
use std::fs::File;
use std::io::{BufRead, BufReader};

fn main() {
    println!("Kore Console initialized.");
    let path = "logs/bots.registry";
    if let Ok(file) = File::open(path) {
        let reader = BufReader::new(file);
        println!("Registered Bots:");
        for line in reader.lines() {
            if let Ok(line) = line {
                let parts: Vec<&str> = line.split(',').collect();
                if parts.len() == 3 {
                    println!("PID: {}, BotID: {}, Port: {}", parts[0], parts[1], parts[2]);
                }
            }
        }
    } else {
        println!("No registry found at {}", path);
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/RustCore/src/bin/console.rs
git commit -m "feat(console): add bot discovery from registry"
```

### Task 3: Verification

- [ ] **Step 1: Start two Rust Core instances**

```bash
export KORE_BOT_ID=bot1
cargo run --bin rust_core &
export KORE_BOT_ID=bot2
cargo run --bin rust_core &
```

- [ ] **Step 2: Check registry**

```bash
cat logs/bots.registry
```
Expected: Two lines with distinct PIDs, bot1/bot2, and ports.

- [ ] **Step 3: Run console**

```bash
cargo run --bin console
```
Expected: Output showing both bot1 and bot2.
