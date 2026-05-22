# Map Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a high-performance map reader in Rust that can load OpenKore's `.fld2` (Gzipped) files.

**Architecture:** A `FieldMap` struct will store map dimensions and a flat `Vec<u8>` for cell data. It uses `flate2` for Gzip decompression and provides a simple `is_walkable` interface.

**Tech Stack:** Rust, `flate2` (Gzip), `anyhow` (Error handling).

---

### Task 1: Dependency Setup

**Files:**
- Modify: `src/RustCore/Cargo.toml`

- [ ] **Step 1: Add flate2 dependency**
Add `flate2 = "1.0"` to `[dependencies]`.

- [ ] **Step 2: Run cargo check**
Ensure dependencies are resolved correctly.

### Task 2: Module Structure

**Files:**
- Modify: `src/RustCore/src/lib.rs`
- Create: `src/RustCore/src/map/mod.rs`

- [ ] **Step 1: Expose map module in lib.rs**
Add `pub mod map;` to `src/RustCore/src/lib.rs`.

- [ ] **Step 2: Create map/mod.rs**
Add `pub mod reader;` to `src/RustCore/src/map/mod.rs`.

### Task 3: Map Reader Implementation (TDD)

**Files:**
- Create: `src/RustCore/src/map/reader.rs`

- [ ] **Step 1: Write failing test for FieldMap::load**
Create `src/RustCore/src/map/reader.rs` with the struct definition and a failing test that attempts to load a dummy map.

- [ ] **Step 2: Run test to verify it fails**
Run: `cargo test map::reader::tests::test_load_valid_map`
Expected: FAIL (load method not implemented)

- [ ] **Step 3: Implement FieldMap::load**
Implement the `load` method using `GzDecoder`.

- [ ] **Step 4: Run test to verify it passes**
Run: `cargo test map::reader::tests::test_load_valid_map`
Expected: PASS

### Task 4: Walkability Interface (TDD)

**Files:**
- Modify: `src/RustCore/src/map/reader.rs`

- [ ] **Step 1: Write failing test for is_walkable**
Add a test case `test_is_walkable`.

- [ ] **Step 2: Run test to verify it fails**
Expected: FAIL (is_walkable not implemented)

- [ ] **Step 3: Implement FieldMap::is_walkable**
Implement the bounds checking and indexing logic.

- [ ] **Step 4: Run test to verify it passes**
Expected: PASS

### Task 5: Final Verification

- [ ] **Step 1: Run all tests in RustCore**
Run: `cargo test`

- [ ] **Step 2: Run cargo check**
Ensure no warnings or errors.
