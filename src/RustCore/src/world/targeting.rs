use crate::world::actor::{Actor, ActorType};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TargetingCriteria {
    pub monster_ids: Vec<u32>,
    pub min_hp: u32,
    pub max_dist: u16,
}

pub struct TargetingEngine {
    pub criteria: TargetingCriteria,
}

impl TargetingEngine {
    pub fn new(criteria: TargetingCriteria) -> Self {
        Self { criteria }
    }

    pub fn select_target(&self, actors: &[Actor], char_x: u16, char_y: u16) -> Option<u32> {
        actors
            .iter()
            .filter(|a| a.actor_type == ActorType::Monster)
            .filter(|a| {
                if !self.criteria.monster_ids.is_empty() {
                    if let Some(mid) = a.monster_id {
                        return self.criteria.monster_ids.contains(&mid);
                    }
                    return false;
                }
                true
            })
            .filter(|a| a.hp >= self.criteria.min_hp)
            .filter(|a| {
                let dx = (a.x as i32 - char_x as i32).abs();
                let dy = (a.y as i32 - char_y as i32).abs();
                dx <= self.criteria.max_dist as i32 && dy <= self.criteria.max_dist as i32
            })
            .min_by_key(|a| {
                let dx = (a.x as i32 - char_x as i32).abs();
                let dy = (a.y as i32 - char_y as i32).abs();
                dx.max(dy)
            })
            .map(|a| a.id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_select_target() {
        let engine = TargetingEngine {
            criteria: TargetingCriteria {
                monster_ids: vec![1001],
                min_hp: 10,
                max_dist: 10,
            },
        };

        let actors = vec![
            Actor { id: 1, actor_type: ActorType::Monster, x: 5, y: 5, name: "Poring".to_string(), monster_id: Some(1001), hp: 20 },
            Actor { id: 2, actor_type: ActorType::Monster, x: 20, y: 20, name: "Poring".to_string(), monster_id: Some(1001), hp: 20 },
            Actor { id: 3, actor_type: ActorType::Monster, x: 6, y: 6, name: "Poring".to_string(), monster_id: Some(9999), hp: 20 },
        ];

        let target = engine.select_target(&actors, 0, 0);
        assert_eq!(target, Some(1));
    }
}
