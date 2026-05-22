# Phase 5 & 6: Protocol Mastery & Research Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Transform the Rust Core into a fully-typed network engine (Option 2) and build an autonomous map researcher (Option 3).

---

### Part 1: Full Packet Serialization (Option 2)
We will move away from raw byte passing to typed JSON objects.

- [ ] **Task 1: Define Shared Packet Registry**
    - Define all common RO switches as a centralized Rust `enum`.
- [ ] **Task 2: Implement Packet Unpacker Library**
    - A reusable Rust library to parse raw RO packets into strongly typed structs.
- [ ] **Task 3: Refactor RustBridge IPC**
    - Update IPC to transport typed packets instead of raw byte blobs.

### Part 2: Autonomous Map Researcher (Option 3)
We will empower the bot to navigate and log maps without pre-existing files.

- [ ] **Task 1: Walkability Sniffer**
    - The Rust core logs every tile traversed as "walkable" by default.
- [ ] **Task 2: Portal Hunter**
    - Log every time the server sends a "Map Change" packet (with coordinates), creating a Portal-Graph.
- [ ] **Task 3: Auto-Mapper CLI**
    - A Rust tool that imports `mining.jsonl` and builds a `.fld` walkability map automatically.

---

**EXPLICIT ASSUMPTIONS:**
- I assume we focus on the `Account` and `Character` server protocols first, as they are the most stable across RO servers.

**DISSENT:**
This is extremely labor-intensive. Protocol definitions are massive. I propose we only implement packets as we *need* them rather than trying to map the entire RO protocol at once.

**Execution Handoff:**
Ready to begin **Part 1, Task 1: Defining the Packet Registry skeleton**?
