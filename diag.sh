#!/bin/bash
echo "--- Cleaning up ---"
killall kore-rust-core 2>/dev/null
rm -f rust_core.log

echo "--- Building Rust Core ---"
cd src/RustCore
cargo build --release > build.log 2>&1
if [ $? -ne 0 ]; then
    echo "Rust Build Failed!"
    cat build.log
    exit 1
fi
cd ../..

echo "--- Starting Rust Core manually for 5s ---"
RUST_LOG=debug ./src/RustCore/target/release/kore-rust-core > rust_core_manual.log 2>&1 &
CORE_PID=$!
sleep 2

echo "--- Checking if Rust Core is listening on 9091 ---"
ss -tuln | grep 9091

echo "--- Running OpenKore Diagnostic ---"
# Choice 4 is standard config
echo -e "4\nquit\n" | perl -Isrc -Isrc/deps openkore.pl --no-connect --control=control > openkore_diag.log 2>&1

echo "--- Results ---"
ps aux | grep kore-rust-core
cat rust_core_manual.log
grep "Rust" openkore_diag.log

kill $CORE_PID 2>/dev/null
