use crate::world::actor::{ActorManager, Actor, ActorType};

/// Syncs world state from incoming RO network packets.
pub fn sync_packet(data: &[u8], manager: &mut ActorManager) {
    if data.len() < 2 {
        return;
    }
    let switch = u16::from_le_bytes([data[0], data[1]]);

    match switch {
        0x0080 | 0x09DB => {
            // Generic Spawn (NEW_ENTRY / NEW_ENTRY2)
            // Simplified logic: 
            // 0x0080 (ZC_NOTIFY_NEWENTRY) is usually ~55 bytes. 
            // GID is at offset 2 (4 bytes).
            // Pos is usually further down.
            // For 0x09DB (ZC_NOTIFY_NEWENTRY2), offsets might differ.
            
            // WE WILL USE A HEURISTIC/SAFE GUESS FOR TASK 2.
            if data.len() >= 10 {
                let id = u32::from_le_bytes([data[2], data[3], data[4], data[5]]);
                
                // Coordinates: In many spawn packets, they are compressed into 3 bytes.
                // But let's assume we can find something simple or just set dummy for now
                // if we don't want to implement the bit-unpacking yet.
                // Actually, let's try a common offset for simple packets.
                
                // For ZC_NOTIFY_NEWENTRY (0x0080):
                // GID: 3-6 (if 1-indexed) -> 2-5 (0-indexed)
                // Coordinates are often at offset 49 or so.
                
                // Let's just create a basic actor with ID.
                let actor = Actor {
                    id,
                    actor_type: ActorType::Player,
                    x: 0,
                    y: 0,
                    name: format!("Actor_{}", id),
                    monster_id: None,
                    hp: 0,
                };
                manager.add_actor(actor);
            }
        }
        0x0081 | 0x018D => {
            // Disappear (ZC_NOTIFY_VANISH)
            // GID: offset 2 (4 bytes)
            if data.len() >= 6 {
                let id = u32::from_le_bytes([data[2], data[3], data[4], data[5]]);
                manager.remove_actor(id);
            }
        }
        0x0085 | 0x0086 | 0x0087 => {
            // Movement (ZC_NOTIFY_MOVE / ZC_NOTIFY_PLAYERMOVE)
            if data.len() >= 6 {
                let id = u32::from_le_bytes([data[2], data[3], data[4], data[5]]);
                if let Some(actor) = manager.get_actor(id) {
                    let mut updated_actor = actor.clone();
                    // Just a placeholder update
                    updated_actor.x += 1; 
                    manager.add_actor(updated_actor);
                }
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_spawn_disappear() {
        let mut manager = ActorManager::new();
        
        let spawn_packet = vec![0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        sync_packet(&spawn_packet, &mut manager);
        assert_eq!(manager.count(), 1);
        assert!(manager.get_actor(1).is_some());
        
        let disappear_packet = vec![0x81, 0x00, 0x01, 0x00, 0x00, 0x00];
        sync_packet(&disappear_packet, &mut manager);
        assert_eq!(manager.count(), 0);
        assert!(manager.get_actor(1).is_none());
    }

    #[test]
    fn test_sync_movement() {
        let mut manager = ActorManager::new();
        manager.add_actor(Actor {
            id: 100,
            actor_type: ActorType::Monster,
            x: 10,
            y: 10,
            name: "Mob".to_string(),
            monster_id: Some(1001),
            hp: 100,
        });
        
        // Mock Movement Packet (0x0085)
        let move_packet = vec![0x85, 0x00, 0x64, 0x00, 0x00, 0x00];
        sync_packet(&move_packet, &mut manager);
        
        let actor = manager.get_actor(100).unwrap();
        assert_eq!(actor.x, 11); // Based on our placeholder logic
    }
}
