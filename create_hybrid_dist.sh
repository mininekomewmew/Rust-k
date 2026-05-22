#!/bin/bash
# Script to create portable HybridKore distributions

LINUX_DIR="hybridkore"
WIN_DIR="hybridkore-win"

echo "--- Creating Linux Distribution: $LINUX_DIR ---"
rm -rf "$LINUX_DIR"
mkdir -p "$LINUX_DIR/src/RustCore/target/release"
mkdir -p "$LINUX_DIR/control"
mkdir -p "$LINUX_DIR/tables"
mkdir -p "$LINUX_DIR/fields"
mkdir -p "$LINUX_DIR/plugins"

# Copy Perl Core
cp -r src/Actor src/AI src/Base src/Bus src/Interface src/Network src/Poseidon src/Task src/Utils "$LINUX_DIR/src/"
cp src/*.pl "$LINUX_DIR/src/"
cp -r src/deps "$LINUX_DIR/src/"

# Copy Essential Files
cp openkore.pl "$LINUX_DIR/"
cp README.md "$LINUX_DIR/"
cp start_bot.sh "$LINUX_DIR/"

# Copy Config and Data
cp control/*.txt "$LINUX_DIR/control/"
cp tables/*.txt "$LINUX_DIR/tables/" 2>/dev/null || true
cp -r tables/iRO tables/kRO "$LINUX_DIR/tables/" 2>/dev/null || true
cp fields/*.gz "$LINUX_DIR/fields/" 2>/dev/null || true

# Copy Plugins
cp -r plugins/* "$LINUX_DIR/plugins/"

# Copy Rust Binary
if [ -f "src/RustCore/target/release/kore-rust-core" ]; then
    cp "src/RustCore/target/release/kore-rust-core" "$LINUX_DIR/src/RustCore/target/release/"
else
    echo "Warning: Linux Rust binary not found!"
fi

echo "--- Creating Windows Distribution: $WIN_DIR ---"
rm -rf "$WIN_DIR"
mkdir -p "$WIN_DIR/src/RustCore/target/release"
mkdir -p "$WIN_DIR/control"
mkdir -p "$WIN_DIR/tables"
mkdir -p "$WIN_DIR/fields"
mkdir -p "$WIN_DIR/plugins"

# Copy Perl Core (Shared with Linux)
cp -r "$LINUX_DIR/src" "$WIN_DIR/"

# Copy Windows Executables and DLLs
cp *.exe "$WIN_DIR/"
cp *.dll "$WIN_DIR/"
cp openkore.pl "$WIN_DIR/"

# Copy Config and Data (Shared)
cp -r "$LINUX_DIR/control" "$WIN_DIR/"
cp -r "$LINUX_DIR/tables" "$WIN_DIR/"
cp -r "$LINUX_DIR/fields" "$WIN_DIR/"
cp -r "$LINUX_DIR/plugins" "$WIN_DIR/"

# Copy Rust Binary (Windows version if exists, usually .exe)
if [ -f "src/RustCore/target/release/kore-rust-core.exe" ]; then
    cp "src/RustCore/target/release/kore-rust-core.exe" "$WIN_DIR/src/RustCore/target/release/"
else
    echo "Note: Windows Rust binary (.exe) not found in release folder. You may need to compile it on Windows."
fi

# Create a basic Windows launcher
echo "@echo off" > "$WIN_DIR/start_bot.bat"
echo "start wxstart.exe" >> "$WIN_DIR/start_bot.bat"

echo "--- Done ---"
echo "Linux dist: ./$LINUX_DIR"
echo "Windows dist: ./$WIN_DIR"
