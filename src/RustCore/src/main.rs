use kore_rust_core::network::{RoClient, PacketMiner};
use kore_rust_core::ipc::{IpcMessage, IpcCommand, IpcServer};
use kore_rust_core::map::cache::MapCache;
use kore_rust_core::world::{ActorManager, sync_packet};
use tokio::sync::mpsc;
use log::{info, error};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    info!("Rust Core starting...");

    let (tx_cmd, mut rx_cmd) = mpsc::channel::<(IpcCommand, mpsc::Sender<IpcMessage>)>(100);

    // Spawn IPC Server
    let ipc_server = IpcServer::bind("127.0.0.1:0").await?;
    let port = ipc_server.port().unwrap_or(0);
    info!("Rust Core bridge active on port {}.", port);
    
    // Register bot
    let bot_id = std::env::var("BOT_ID").unwrap_or_else(|_| "default".to_string());
    let pid = std::process::id();
    
    std::fs::create_dir_all("logs").unwrap_or_default();
    if let Ok(mut file) = std::fs::OpenOptions::new().create(true).append(true).open("logs/bots.registry") {
        use std::io::Write;
        let _ = writeln!(file, "{},{},{}", pid, bot_id, port);
    }

    tokio::spawn(async move {
        if let Err(e) = ipc_server.run(tx_cmd).await {
            error!("IPC Server error: {}", e);
        }
    });


    let mut current_client: Option<RoClient> = None;
    let mut current_addr: String = String::new();
    let mut current_tx_msg: Option<mpsc::Sender<IpcMessage>> = None;
    
    let mut miner = PacketMiner::new();
    let mut actor_manager = ActorManager::new();
    
    let fields_path = std::env::current_dir()?.join("fields");
    let mut map_cache = MapCache::new(fields_path);

    loop {
        tokio::select! {
            // Commands from Perl via IPC Server
            maybe_cmd = rx_cmd.recv() => {
                match maybe_cmd {
                    Some((cmd, tx_msg)) => {
                        current_tx_msg = Some(tx_msg.clone());
                        match cmd {
                            IpcCommand::Connect { host, port } => {
                                let port_str = if let Some(s) = port.as_str() {
                                    s.to_string()
                                } else {
                                    port.to_string()
                                };
                                let addr = format!("{}:{}", host, port_str);
                                info!("Connecting to RO Server at {}...", addr);
                                
                                current_client = None;
                                match RoClient::connect(&addr, "", "").await {
                                    Ok(client) => {
                                        info!("Connected to RO Server at {}", addr);
                                        current_client = Some(client);
                                        current_addr = addr.clone();
                                        let _ = tx_msg.send(IpcMessage::ConnectionStatus {
                                            connected: true,
                                            addr,
                                        }).await;
                                    }
                                    Err(e) => {
                                        error!("Failed to connect to RO Server at {}: {}", addr, e);
                                        let _ = tx_msg.send(IpcMessage::ConnectionStatus {
                                            connected: false,
                                            addr,
                                        }).await;
                                    }
                                }
                            }
                            IpcCommand::SendPacket { data } => {
                                miner.log("send", &data).await;
                                info!("Forwarding {} bytes to RO Server. Hex: {}", data.len(), hex::encode(&data));
                                if let Some(ref mut client) = current_client {
                                    if let Err(e) = client.write_packet(&data).await {
                                        error!("Failed to send packet: {}", e);
                                        current_client = None;
                                        if let Some(ref tx) = current_tx_msg {
                                            let _ = tx.send(IpcMessage::ConnectionStatus {
                                                connected: false,
                                                addr: current_addr.clone(),
                                            }).await;
                                        }
                                    }
                                }
                            }
                            IpcCommand::EnableMiner { log_file } => {
                                let _ = miner.start(&log_file).await;
                            }
                            IpcCommand::FindPath { map_name, start_x, start_y, end_x, end_y, random_factor: _ } => {
                                match map_cache.get_map(&map_name) {
                                    Ok(map) => {
                                        if let Some(path) = map.find_path((start_x, start_y), (end_x, end_y), false) {
                                            let _ = tx_msg.send(IpcMessage::PathFound { points: path }).await;
                                        } else {
                                            let _ = tx_msg.send(IpcMessage::PathNotFound { error: "No path".to_string() }).await;
                                        }
                                    }
                                    Err(e) => {
                                        let _ = tx_msg.send(IpcMessage::PathNotFound { error: e.to_string() }).await;
                                    }
                                }
                            }
                            IpcCommand::GetNearby { x, y, range } => {
                                let actors = actor_manager.get_nearby(x, y, range);
                                let _ = tx_msg.send(IpcMessage::NearbyActors { actors }).await;
                            }
                        }
                    }
                    None => break,
                }
            }

            // Packets from RO Server
            res = async {
                if let Some(ref mut client) = current_client {
                    client.read_stream().await
                } else {
                    std::future::pending().await
                }
            } => {
                match res {
                    Ok(Some(data)) => {
                        miner.log("recv", &data).await;
                        sync_packet(&data, &mut actor_manager);
                        if let Some(ref tx) = current_tx_msg {
                            let _ = tx.send(IpcMessage::PacketRaw { data }).await;
                        }
                    }
                    Ok(None) => {
                        info!("RO Server disconnected.");
                        current_client = None;
                        if let Some(ref tx) = current_tx_msg {
                            let _ = tx.send(IpcMessage::ConnectionStatus {
                                connected: false,
                                addr: current_addr.clone(),
                            }).await;
                        }
                    }
                    Err(e) => {
                        error!("Error reading: {}", e);
                        current_client = None;
                        if let Some(ref tx) = current_tx_msg {
                            let _ = tx.send(IpcMessage::ConnectionStatus {
                                connected: false,
                                addr: current_addr.clone(),
                            }).await;
                        }
                    }
                }
            }
        }
    }

    info!("Rust Core shutting down.");
    Ok(())
}
