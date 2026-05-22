use serde::{Serialize, Deserialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub enum ActorType {
    Player,
    Monster,
    Npc,
    Pet,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub struct Actor {
    pub id: u32,
    pub actor_type: ActorType,
    pub x: u16,
    pub y: u16,
    pub name: String,
    pub monster_id: Option<u32>,
    pub hp: u32,
}

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct ActorManager {
    actors: HashMap<u32, Actor>,
}

impl ActorManager {
    pub fn new() -> Self {
        Self {
            actors: HashMap::new(),
        }
    }

    pub fn add_actor(&mut self, actor: Actor) {
        self.actors.insert(actor.id, actor);
    }

    pub fn remove_actor(&mut self, id: u32) {
        self.actors.remove(&id);
    }

    pub fn get_actor(&self, id: u32) -> Option<&Actor> {
        self.actors.get(&id)
    }

    pub fn clear(&mut self) {
        self.actors.clear();
    }

    pub fn count(&self) -> usize {
        self.actors.len()
    }

    pub fn get_nearby(&self, x: u16, y: u16, range: u16) -> Vec<Actor> {
        self.actors
            .values()
            .filter(|a| {
                let dx = (a.x as i32 - x as i32).abs();
                let dy = (a.y as i32 - y as i32).abs();
                dx <= range as i32 && dy <= range as i32
            })
            .cloned()
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_actor_lifecycle() {
        let mut manager = ActorManager::new();
        
        let player = Actor {
            id: 1,
            actor_type: ActorType::Player,
            x: 100,
            y: 200,
            name: "TestPlayer".to_string(),
            monster_id: None,
            hp: 100,
        };
        
        manager.add_actor(player.clone());
        assert_eq!(manager.count(), 1);
        
        let retrieved = manager.get_actor(1).unwrap();
        assert_eq!(retrieved.name, "TestPlayer");
        assert_eq!(retrieved.actor_type, ActorType::Player);
        
        manager.remove_actor(1);
        assert_eq!(manager.count(), 0);
        assert!(manager.get_actor(1).is_none());
    }

    #[test]
    fn test_clear() {
        let mut manager = ActorManager::new();
        manager.add_actor(Actor {
            id: 1,
            actor_type: ActorType::Monster,
            x: 10,
            y: 10,
            name: "Poring".to_string(),
            monster_id: Some(1001),
            hp: 10,
        });
        manager.add_actor(Actor {
            id: 2,
            actor_type: ActorType::Npc,
            x: 20,
            y: 20,
            name: "Kafra".to_string(),
            monster_id: None,
            hp: 0,
        });
        
        assert_eq!(manager.count(), 2);
        manager.clear();
        assert_eq!(manager.count(), 0);
    }

    #[test]
    fn test_get_nearby() {
        let mut manager = ActorManager::new();
        manager.add_actor(Actor {
            id: 1,
            actor_type: ActorType::Monster,
            x: 10,
            y: 10,
            name: "Poring1".to_string(),
            monster_id: Some(1001),
            hp: 10,
        });
        manager.add_actor(Actor {
            id: 2,
            actor_type: ActorType::Monster,
            x: 15,
            y: 15,
            name: "Poring2".to_string(),
            monster_id: Some(1001),
            hp: 10,
        });
        manager.add_actor(Actor {
            id: 3,
            actor_type: ActorType::Monster,
            x: 20,
            y: 20,
            name: "Poring3".to_string(),
            monster_id: Some(1001),
            hp: 10,
        });

        // Test range 5 at (10, 10) -> should get 1 and 2
        let nearby = manager.get_nearby(10, 10, 5);
        assert_eq!(nearby.len(), 2);
        assert!(nearby.iter().any(|a| a.id == 1));
        assert!(nearby.iter().any(|a| a.id == 2));
        assert!(!nearby.iter().any(|a| a.id == 3));

        // Test range 0 at (10, 10) -> should get only 1
        let nearby = manager.get_nearby(10, 10, 0);
        assert_eq!(nearby.len(), 1);
        assert_eq!(nearby[0].id, 1);

        // Test range 100 at (0, 0) -> should get all
        let nearby = manager.get_nearby(0, 0, 100);
        assert_eq!(nearby.len(), 3);
    }
}
