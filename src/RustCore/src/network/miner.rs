use tokio::fs::{File, OpenOptions};
use tokio::io::AsyncWriteExt;
use serde::Serialize;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize)]
struct MiningEntry {
    timestamp: u128,
    direction: String,
    hex_data: String,
}

pub struct PacketMiner {
    file: Option<File>,
}

impl PacketMiner {
    pub fn new() -> Self { Self { file: None } }
    
    pub async fn start(&mut self, path: &str) -> anyhow::Result<()> {
        let file = OpenOptions::new().create(true).append(true).open(path).await?;
        self.file = Some(file);
        Ok(())
    }

    pub async fn log(&mut self, direction: &str, data: &[u8]) {
        if let Some(ref mut f) = self.file {
            let entry = MiningEntry {
                timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis(),
                direction: direction.to_string(),
                hex_data: hex::encode(data),
            };
            if let Ok(json) = serde_json::to_string(&entry) {
                let _ = f.write_all(format!("{}\n", json).as_bytes()).await;
            }
        }
    }
}
