use std::collections::HashMap;
use crate::map::reader::FieldMap;
use anyhow::{Result, anyhow};
use std::path::PathBuf;

pub struct MapCache {
    cache: HashMap<String, FieldMap>,
    base_path: PathBuf,
}

impl MapCache {
    pub fn new(base_path: PathBuf) -> Self {
        Self {
            cache: HashMap::new(),
            base_path,
        }
    }

    pub fn get_map(&mut self, name: &str) -> Result<&FieldMap> {
        if !self.cache.contains_key(name) {
            let mut path = self.base_path.join(format!("{}.fld2.gz", name));
            
            if !path.exists() {
                path = self.base_path.join(format!("{}.fld2", name));
            }
            
            if !path.exists() {
                return Err(anyhow!("Map file not found: {}", name));
            }

            let map = FieldMap::load(path.to_str().ok_or_else(|| anyhow!("Invalid path"))?)?;
            self.cache.insert(name.to_string(), map);
        }

        Ok(self.cache.get(name).unwrap())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use flate2::write::GzEncoder;
    use flate2::Compression;
    use tempfile::tempdir;

    #[test]
    fn test_map_cache_load() {
        let dir = tempdir().unwrap();
        let map_name = "test_map";
        let map_path = dir.path().join(format!("{}.fld2.gz", map_name));

        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        let width: u16 = 2;
        let height: u16 = 2;
        let data: Vec<u8> = vec![0, 0, 0, 0];
        encoder.write_all(&width.to_le_bytes()).unwrap();
        encoder.write_all(&height.to_le_bytes()).unwrap();
        encoder.write_all(&data).unwrap();
        let compressed_data = encoder.finish().unwrap();
        
        let mut file = std::fs::File::create(&map_path).unwrap();
        file.write_all(&compressed_data).unwrap();

        let mut cache = MapCache::new(dir.path().to_path_buf());
        let map = cache.get_map(map_name).unwrap();
        assert_eq!(map.width, 2);
        
        // Second call should come from cache
        let _ = cache.get_map(map_name).unwrap();
    }
}
