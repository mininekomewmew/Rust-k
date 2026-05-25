use serde::{Deserialize, Serialize};
use tokio::net::{TcpListener, TcpStream};
use tokio::io::AsyncWriteExt;
use anyhow::Result;
use log::{info, error};
use crate::network::packets::Packet;

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type")]
pub enum IpcMessage {
    #[serde(rename = "packet")]
    Packet {
        packet: Packet,
    },
    #[serde(rename = "packet_raw")]
    PacketRaw {
        data: Vec<u8>,
    },
    #[serde(rename = "connection_status")]
    ConnectionStatus {
        connected: bool,
        addr: String,
    },
    #[serde(rename = "path_found")]
    PathFound {
        points: Vec<(u16, u16)>,
    },
    #[serde(rename = "path_not_found")]
    PathNotFound {
        error: String,
    },
    #[serde(rename = "nearby_actors")]
    NearbyActors {
        actors: Vec<crate::world::Actor>,
    },
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type")]
pub enum IpcCommand {
    #[serde(rename = "connect")]
    Connect {
        host: String,
        port: serde_json::Value,
    },
    #[serde(rename = "send_packet")]
    SendPacket {
        data: Vec<u8>,
    },
    #[serde(rename = "enable_miner")]
    EnableMiner {
        log_file: String,
    },
    #[serde(rename = "find_path")]
    FindPath {
        map_name: String,
        start_x: u16,
        start_y: u16,
        end_x: u16,
        end_y: u16,
        random_factor: u8,
    },
    #[serde(rename = "get_nearby")]
    GetNearby {
        x: u16,
        y: u16,
        range: u16,
    },
}

pub struct IpcServer {
    listener: TcpListener,
}

impl IpcServer {
    pub async fn bind(addr: &str) -> Result<Self> {
        let listener = TcpListener::bind(addr).await?;
        let local_addr = listener.local_addr()?;
        info!("IPC Server listening on {}", local_addr);
        println!("IPC_PORT={}", local_addr.port()); // Perl will read this
        Ok(Self { listener })
    }

    pub async fn run(
        self,
        tx_cmd: tokio::sync::mpsc::Sender<(IpcCommand, tokio::sync::mpsc::Sender<IpcMessage>)>,
    ) -> Result<()> {
        loop {
            let (socket, addr) = self.listener.accept().await?;
            info!("IPC Client connected: {}", addr);

            if let Err(e) = self.handle_client(socket, tx_cmd.clone()).await {
                error!("Error handling IPC client {}: {}", addr, e);
            }
            info!("IPC Client disconnected: {}", addr);
        }
    }

    async fn handle_client(
        &self,
        socket: TcpStream,
        tx_cmd: tokio::sync::mpsc::Sender<(IpcCommand, tokio::sync::mpsc::Sender<IpcMessage>)>,
    ) -> Result<()> {
        use tokio::io::AsyncBufReadExt;
        let (reader, mut writer) = socket.into_split();
        let mut reader = tokio::io::BufReader::new(reader);
        
        let (tx_msg, mut rx_msg) = tokio::sync::mpsc::channel::<IpcMessage>(100);

        let tx_cmd_task = tx_cmd.clone();
        let mut read_task = tokio::spawn(async move {
            let mut line = String::new();
            while let Ok(n) = reader.read_line(&mut line).await {
                if n == 0 {
                    break;
                }
                let trimmed = line.trim();
                if trimmed.is_empty() {
                    line.clear();
                    continue;
                }
                info!("IPC Received: {}", trimmed);
                match serde_json::from_str::<IpcCommand>(trimmed) {
                    Ok(cmd) => {
                        info!("IPC Parsed Command: {:?}", cmd);
                        if let Err(_) = tx_cmd_task.send((cmd, tx_msg.clone())).await {
                            break;
                        }
                    }
                    Err(e) => {
                        error!("Failed to parse IPC command: {}. Line: {}", e, trimmed);
                    }
                }
                line.clear();
            }
        });

        loop {
            tokio::select! {
                _res = &mut read_task => {
                    break;
                }
                maybe_msg = rx_msg.recv() => {
                    match maybe_msg {
                        Some(msg) => {
                            let json = serde_json::to_string(&msg)? + "\n";
                            if let Err(_) = writer.write_all(json.as_bytes()).await {
                                break;
                            }
                        }
                        None => break,
                    }
                }
            }
        }

        read_task.abort();
        Ok(())
    }
}
