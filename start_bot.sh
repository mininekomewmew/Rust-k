#!/bin/bash
# OpenKore Rust-Accelerated Launcher
echo "--- Killing stale Rust instances ---"
killall kore-rust-core 2>/dev/null

echo "--- Starting Rust Core Bridge ---"
./src/RustCore/target/release/kore-rust-core > rust_core.log 2>&1 &

echo "--- Waiting for IPC Bridge ---"
sleep 2

echo "--- Launching OpenKore ---"
perl -Isrc -Isrc/deps openkore.pl --control=control --interface=Console
