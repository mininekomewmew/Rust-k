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
        
        if let Packet::AccountInfo { account_id, session_id, session_id2, sex } = packet {
            assert_eq!(session_id, 1);
            assert_eq!(account_id, 2);
            assert_eq!(session_id2, 3);
            assert_eq!(sex, 1);
        } else {
            panic!("Expected AccountInfo packet");
        }
    }
}
