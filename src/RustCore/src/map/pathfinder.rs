use std::collections::{BinaryHeap, HashMap};
use std::cmp::Ordering;
use crate::map::reader::FieldMap;

#[derive(Copy, Clone, Eq, PartialEq)]
struct Node {
    pos: (u16, u16),
    cost: u32,
    priority: u32,
}

impl Ord for Node {
    fn cmp(&self, other: &Self) -> Ordering {
        other.priority.cmp(&self.priority)
    }
}

impl PartialOrd for Node {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub fn a_star(map: &FieldMap, start: (u16, u16), end: (u16, u16), smooth: bool) -> Option<Vec<(u16, u16)>> {
    let path_opt = a_star_internal(map, start, end);
    if let Some(path) = path_opt {
        if smooth {
            return Some(smooth_path(path, 10));
        }
        return Some(path);
    }
    None
}

fn a_star_internal(map: &FieldMap, start: (u16, u16), end: (u16, u16)) -> Option<Vec<(u16, u16)>> {
    if !map.is_walkable(start.0, start.1) || !map.is_walkable(end.0, end.1) {
        return None;
    }

    if start == end {
        return Some(vec![start]);
    }

    let mut open_set = BinaryHeap::new();
    let mut came_from: HashMap<(u16, u16), (u16, u16)> = HashMap::new();
    let mut g_score: HashMap<(u16, u16), u32> = HashMap::new();

    g_score.insert(start, 0);
    open_set.push(Node {
        pos: start,
        cost: 0,
        priority: heuristic(start, end),
    });

    while let Some(current_node) = open_set.pop() {
        let current = current_node.pos;

        if current == end {
            let mut path = vec![end];
            let mut curr = end;
            while let Some(&prev) = came_from.get(&curr) {
                path.push(prev);
                curr = prev;
            }
            path.reverse();
            return Some(path);
        }

        if let Some(&score) = g_score.get(&current) {
            if current_node.cost > score {
                continue;
            }
        }

        for neighbor in get_neighbors(map, current) {
            let tentative_g_score = g_score[&current] + 1;

            if tentative_g_score < *g_score.get(&neighbor).unwrap_or(&u32::MAX) {
                came_from.insert(neighbor, current);
                g_score.insert(neighbor, tentative_g_score);
                open_set.push(Node {
                    pos: neighbor,
                    cost: tentative_g_score,
                    priority: tentative_g_score + heuristic(neighbor, end),
                });
            }
        }
    }

    None
}

pub fn smooth_path(path: Vec<(u16, u16)>, points_per_segment: usize) -> Vec<(u16, u16)> {
    if path.len() < 3 {
        return path;
    }
    let mut smoothed = Vec::new();
    
    let mut extended = vec![*path.first().unwrap()];
    extended.extend(path.clone());
    extended.push(*path.last().unwrap());

    for i in 0..extended.len() - 3 {
        let p0 = extended[i];
        let p1 = extended[i+1];
        let p2 = extended[i+2];
        let p3 = extended[i+3];

        for t_step in 0..points_per_segment {
            let t = t_step as f32 / points_per_segment as f32;
            let t2 = t * t;
            let t3 = t2 * t;

            let x0 = p0.0 as i32;
            let y0 = p0.1 as i32;
            let x1 = p1.0 as i32;
            let y1 = p1.1 as i32;
            let x2 = p2.0 as i32;
            let y2 = p2.1 as i32;
            let x3 = p3.0 as i32;
            let y3 = p3.1 as i32;

            let x = 0.5 * (
                (2.0 * x1 as f32) +
                (-x0 as f32 + x2 as f32) * t +
                (2.0 * x0 as f32 - 5.0 * x1 as f32 + 4.0 * x2 as f32 - x3 as f32) * t2 +
                (-x0 as f32 + 3.0 * x1 as f32 - 3.0 * x2 as f32 + x3 as f32) * t3
            );

            let y = 0.5 * (
                (2.0 * y1 as f32) +
                (-y0 as f32 + y2 as f32) * t +
                (2.0 * y0 as f32 - 5.0 * y1 as f32 + 4.0 * y2 as f32 - y3 as f32) * t2 +
                (-y0 as f32 + 3.0 * y1 as f32 - 3.0 * y2 as f32 + y3 as f32) * t3
            );

            smoothed.push((x.round() as u16, y.round() as u16));
        }
    }
    smoothed.push(*path.last().unwrap());
    smoothed
}

fn heuristic(a: (u16, u16), b: (u16, u16)) -> u32 {
    let dx = (a.0 as i32 - b.0 as i32).abs();
    let dy = (a.1 as i32 - b.1 as i32).abs();
    std::cmp::max(dx, dy) as u32
}

fn get_neighbors(map: &FieldMap, pos: (u16, u16)) -> Vec<(u16, u16)> {
    let mut neighbors = Vec::new();
    let (x, y) = (pos.0 as i32, pos.1 as i32);

    for dx in -1..=1 {
        for dy in -1..=1 {
            if dx == 0 && dy == 0 {
                continue;
            }

            let nx = x + dx;
            let ny = y + dy;

            if nx >= 0 && nx < map.width as i32 && ny >= 0 && ny < map.height as i32 {
                let target_x = nx as u16;
                let target_y = ny as u16;

                if map.is_walkable(target_x, target_y) {
                    if dx != 0 && dy != 0 {
                        // Diagonal movement check
                        // Check if both cardinal adjacent cells are walkable
                        if map.is_walkable(x as u16, target_y) && map.is_walkable(target_x, y as u16) {
                            neighbors.push((target_x, target_y));
                        }
                    } else {
                        neighbors.push((target_x, target_y));
                    }
                }
            }
        }
    }

    neighbors
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_a_star_same_start_end() {
        let map = FieldMap {
            width: 10,
            height: 10,
            data: vec![1; 100],
        };
        let path = a_star(&map, (1, 1), (1, 1), false);
        assert_eq!(path, Some(vec![(1, 1)]));
    }

    #[test]
    fn test_a_star_diagonal_clipping() {
        // Map 3x3
        // S B .  (0,0) (1,0) (2,0)
        // B . .  (0,1) (1,1) (2,1)
        // . . E  (0,2) (1,2) (2,2)
        // S=(0,0), E=(2,2), B=Blocked (0).
        // Diagonal from (0,0) to (1,1) should be blocked because (1,0) and (0,1) are blocked.
        let mut data = vec![1; 9];
        data[1] = 0; // (1,0)
        data[3] = 0; // (0,1)
        let map = FieldMap {
            width: 3,
            height: 3,
            data,
        };
        
        let path = a_star(&map, (0, 0), (2, 2), false);
        // If clipping is enforced, (1,1) is unreachable from (0,0)
        // Thus (2,2) is unreachable.
        assert_eq!(path, None);
    }

    #[test]
    fn test_a_star_diagonal_valid() {
        let map = FieldMap {
            width: 3,
            height: 3,
            data: vec![1; 9],
        };
        let path = a_star(&map, (0, 0), (1, 1), false);
        assert_eq!(path, Some(vec![(0, 0), (1, 1)]));
    }

    #[test]
    fn test_smooth_path_increases_length() {
        let path = vec![(0, 0), (5, 5), (10, 10)];
        let smoothed = smooth_path(path.clone(), 10);
        assert!(smoothed.len() > path.len());
    }
}
