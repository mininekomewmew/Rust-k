Task: Implement registration in src/RustCore/src/main.rs.

Context:
- Currently, IpcServer binds to 127.0.0.1:9091.
- Requirement: After IPC server is spawned, open 'logs/bots.registry' in append mode.
- Write format: {process_id},{bot_id},{port}.
- PID: std::process::id().
- Bot ID: std::env::var("BOT_ID").unwrap_or_else(|_| "default".to_string()).
- Port: 9091.

Instructions:
1. Update main.rs to import necessary FS types.
2. After spawning IPC server, append the bot details to 'logs/bots.registry'.
3. Do not modify existing logic unless necessary.
