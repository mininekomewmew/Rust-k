use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type")]
pub enum Packet {
    #[serde(rename = "account_info")]
    AccountInfo {
        account_id: u32,
        session_id: u32,
        session_id2: u32,
        sex: u8,
    },
}

pub trait Unpackable: Sized {
    fn unpack(data: &[u8]) -> Result<Self, anyhow::Error>;
}

impl Packet {
    pub fn try_unpack(switch: u16, data: &[u8]) -> Option<Packet> {
        match switch {
            0x0AC4 => {
                if data.len() < 13 {
                    return None;
                }
                let session_id = u32::from_le_bytes(data[0..4].try_into().ok()?);
                let account_id = u32::from_le_bytes(data[4..8].try_into().ok()?);
                let session_id2 = u32::from_le_bytes(data[8..12].try_into().ok()?);
                let sex = data[12];
                Some(Packet::AccountInfo {
                    account_id,
                    session_id,
                    session_id2,
                    sex,
                })
            }
            _ => None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unpack_account_info_0x0ac4() {
        // 0x0AC4: 2 bytes
        // sessionID: 4 bytes (offset 2)
        // accountID: 4 bytes (offset 6)
        // sessionID2: 4 bytes (offset 10)
        // sex: 1 byte (offset 14)
        // Total: 15 bytes
        let raw_packet = vec![
            0xC4, 0x0A,             // Switch (0x0AC4)
            0x01, 0x00, 0x00, 0x00, // sessionID: 1
            0x02, 0x00, 0x00, 0x00, // accountID: 2
            0x03, 0x00, 0x00, 0x00, // sessionID2: 3
            0x01,                   // sex: 1
        ];

        let packet = Packet::try_unpack(0x0AC4, &raw_packet[2..]).expect("Should unpack");
        
        let Packet::AccountInfo { account_id, session_id, session_id2, sex } = packet;
        assert_eq!(session_id, 1);
        assert_eq!(account_id, 2);
        assert_eq!(session_id2, 3);
        assert_eq!(sex, 1);
    }
}
