# IPC Discovery Service Design

## Overview
Implement a registry system in `logs/bots.registry` to allow `kore-console` to discover running Rust Core instances.

## Bot Registration (Rust Core)
When `IpcServer::bind` successfully binds to a port, it will:
1. Determine `bot_id` (from environment variable `KORE_BOT_ID` or "default").
2. Determine `port` from the bound listener.
3. Determine `PID` from `std::process::id()`.
4. Append `PID,BOT_ID,PORT` to `logs/bots.registry` using `tokio::fs::OpenOptions` (create, append).

## Console Discovery (Kore Console)
`kore-console` will:
1. Open `logs/bots.registry` in read-only mode.
2. Read the lines.
3. Parse `PID,BOT_ID,PORT`.
4. Display the list of bots.

## Verification Plan
1. Start two Rust Core instances with different `KORE_BOT_ID`.
2. Observe `logs/bots.registry` contains two lines.
3. Implement `kore-console` to list them.
4. Run `kore-console` and verify it displays both bots.
