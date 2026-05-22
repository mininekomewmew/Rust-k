# Rust Path Smoother Implementation Plan

**Goal:** Implement a Catmull-Rom spline smoother in Rust to convert A* paths into smooth curves.

**Architecture:** A `smooth_path` function in `pathfinder.rs` uses Catmull-Rom logic to interpolate between points.

**Tech Stack:** Rust, standard library.

---

### Task 1: Implement `smooth_path` in `pathfinder.rs`

**Files:**
- Modify: `src/RustCore/src/map/pathfinder.rs`

- [ ] **Step 1: Add implementation of `smooth_path`**

```rust
pub fn smooth_path(path: Vec<(u16, u16)>, points_per_segment: usize) -> Vec<(u16, u16)> {
    if path.len() < 3 {
        return path;
    }
    let mut smoothed = Vec::new();
    
    // We iterate through all points (p0, p1, p2, p3) to form segments.
    // For Catmull-Rom, we need 4 points.
    // Pad the path with the start and end points for the spline
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

            let x = 0.5 * (
                (2.0 * p1.0 as f32) +
                (-p0.0 as f32 + p2.0 as f32) * t +
                (2.0 * p0.0 as f32 - 5.0 * p1.0 as f32 + 4.0 * p2.0 as f32 - p3.0 as f32) * t2 +
                (-p0.0 as f32 + 3.0 * p1.0 as f32 - 3.0 * p2.0 as f32 + p3.0 as f32) * t3
            );

            let y = 0.5 * (
                (2.0 * p1.1 as f32) +
                (-p0.1 as f32 + p2.1 as f32) * t +
                (2.0 * p0.1 as f32 - 5.0 * p1.1 as f32 + 4.0 * p2.1 as f32 - p3.1 as f32) * t2 +
                (-p0.1 as f32 + 3.0 * p1.1 as f32 - 3.0 * p2.1 as f32 + p3.1 as f32) * t3
            );

            smoothed.push((x.round() as u16, y.round() as u16));
        }
    }
    // Add the final point
    smoothed.push(*path.last().unwrap());
    smoothed
}
```

- [ ] **Step 2: Update `a_star` to support smoothing**

Modify `a_star` signature (or add a wrapper) to return smoothed path if requested. Since `a_star` is a core utility, adding an optional boolean parameter `smooth: bool` is easiest.

```rust
pub fn a_star(map: &FieldMap, start: (u16, u16), end: (u16, u16), smooth: bool) -> Option<Vec<(u16, u16)>> {
    let path_opt = /* existing a_star implementation */;
    if let Some(path) = path_opt {
        if smooth {
            return Some(smooth_path(path, 10)); // Default 10 points
        }
        return Some(path);
    }
    None
}
```

- [ ] **Step 3: Add unit test**

```rust
#[test]
fn test_smooth_path_increases_length() {
    let path = vec![(0, 0), (5, 5), (10, 10)];
    let smoothed = smooth_path(path.clone(), 10);
    assert!(smoothed.len() > path.len());
}
```

- [ ] **Step 4: Commit**
