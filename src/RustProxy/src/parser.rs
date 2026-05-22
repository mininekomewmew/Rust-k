use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug)]
pub struct ParsedPacket {
    pub switch: u16,
    pub status: String,
    pub data: Vec<u8>, // Using Vec<u8> for now for easier JSON serialization, but avoiding clones where possible
}

pub struct PacketParser {
    lengths: HashMap<u16, i16>,
}

impl PacketParser {
    pub fn new() -> Self {
        let mut lengths = HashMap::new();
        // Add some common RO packets for demonstration
        lengths.insert(0x0064, 55);
        lengths.insert(0x0069, -1);
        lengths.insert(0x0097, -1); // private_message
        lengths.insert(0x0080, 4);  // For testing
        
        PacketParser { lengths }
    }

    pub fn get_packet_length(&self, switch: u16, buf: &[u8]) -> Option<usize> {
        match self.lengths.get(&switch) {
            Some(&len) if len > 0 => Some(len as usize),
            Some(&-1) => {
                if buf.len() >= 4 {
                    let len = u16::from_le_bytes([buf[2], buf[3]]) as usize;
                    if len >= 4 { Some(len) } else { None }
                } else {
                    None // Need more data to read length
                }
            }
            _ => {
                // Fallback: if it looks like a variable length packet
                if buf.len() >= 4 {
                    let len = u16::from_le_bytes([buf[2], buf[3]]) as usize;
                    if len >= 4 && len < 16384 {
                        return Some(len);
                    }
                }
                None
            }
        }
    }

    pub fn parse_packet(&self, raw_data: &[u8]) -> Result<ParsedPacket, String> {
        if raw_data.len() < 2 {
            return Err("Packet too short".into());
        }
        
        let switch = u16::from_le_bytes([raw_data[0], raw_data[1]]);
        
        Ok(ParsedPacket {
            switch,
            status: "success".into(),
            data: if raw_data.len() > 2 { raw_data[2..].to_vec() } else { Vec::new() },
        })
    }
}
