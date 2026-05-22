# Phase 9 Task 2: IPC Discovery Service

## Tasks

1. [ ] Implement registration in `src/RustCore/src/main.rs`.
   - After IPC server setup, write `(pid, bot_id, port)` to `logs/bots.registry`.
   - Use `std::fs::OpenOptions` with `create(true)` and `append(true)`.
   - Bot ID: default to "default" if env var `BOT_ID` is not set.

2. [ ] Implement discovery in `src/RustCore/src/bin/console.rs`.
   - Read `logs/bots.registry`.
   - Parse each line and print: `Bot [ID] (PID: [PID]) listening on [PORT]`.
EOF
,file_path: