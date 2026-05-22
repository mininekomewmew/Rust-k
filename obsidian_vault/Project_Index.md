# OpenKore Hybrid Master Index

This is the central entry point for the Hybrid Rust-Perl bot architecture and the Heimdall Dashboard system.

## 🚀 Getting Started
- [[HybridCore_Implementation|Implementation Overview]] - The "Big Picture" of how the bot works.
- [[RustCore_PostMortem|Rust Core Post-Mortem]] - Historical errors and why we chose the Hybrid path.

## 🛠️ Production Management
- **Linux Folder**: `../hybridkore`
- **Windows Folder**: `../hybridkore-win`
- **Update Script**: `./sync_changes.sh` (Run this in the main dev folder to push updates to production).

## 📊 Monitoring
- **Dashboard**: http://localhost:20035/
- **Key Features**: 
    - Real-time HP/SP/EXP/JEXP bars.
    - Live Canvas Mini-map with actor tracking.
    - Remote Command Console.

## 🐛 Resolved Issues
1. **Login Handshake**: Resolved by Hybrid Mode (Perl established session, Rust takes over at map).
2. **Pathfinding (0,0)**: Fixed parameter shift in `AI::RustPathfinding.pm`.
3. **IPC Port Collision**: Fixed via Dynamic Port Binding and PID-based logs.
4. **Bridge Deadlock**: Fixed by relaxing `serverSend` state-checks for IPC commands.
5. **Double XOR**: Fixed by removing redundant hook triggers in `RustBridge.pm`.

## 📂 Project Structure (Hybrid)
- `src/Network/RustBridge.pm`: The logic hub for switching between Perl and Rust.
- `src/RustCore/src/main.rs`: The high-performance engine.
- `plugins/webStatus.pl`: The dashboard provider.
- `fields/`: Map data consumed by both systems.
