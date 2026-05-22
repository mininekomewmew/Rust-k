use flate2::read::GzDecoder;
use std::io::Read;
use std::fs::File;
use anyhow::Result;

pub struct FieldMap {
    pub width: u16,
    pub height: u16,
    pub data: Vec<u8>,
}

impl FieldMap {
    pub fn load(path: &str) -> Result<Self> {
        let mut file = File::open(path)?;
        let mut buf = Vec::new();
        
        // Try to decode as Gzip first
        let mut decoder = GzDecoder::new(&file);
        if decoder.read_to_end(&mut buf).is_err() {
            // If Gzip fails, try reading as raw file
            buf.clear();
            file = File::open(path)?; // Re-open because GzDecoder might have consumed some bytes
            file.read_to_end(&mut buf)?;
        }

        if buf.len() < 4 {
            return Err(anyhow::anyhow!("Map file too short"));
        }

        let width = u16::from_le_bytes([buf[0], buf[1]]);
        let height = u16::from_le_bytes([buf[2], buf[3]]);
        let data = buf[4..].to_vec();

        if data.len() != (width as usize) * (height as usize) {
            return Err(anyhow::anyhow!("Map data size mismatch: expected {}, got {}", (width as usize) * (height as usize), data.len()));
        }

        Ok(Self {
            width,
            height,
            data,
        })
    }

    pub fn is_walkable(&self, x: u16, y: u16) -> bool {
        if x >= self.width || y >= self.height {
            return false;
        }
        let idx = (y as usize) * (self.width as usize) + (x as usize);
        self.data.get(idx).map(|&v| (v & 1) != 0).unwrap_or(false)
    }

    pub fn find_path(&self, start: (u16, u16), end: (u16, u16), smooth: bool) -> Option<Vec<(u16, u16)>> {
        super::pathfinder::a_star(self, start, end, smooth)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use flate2::write::GzEncoder;
    use flate2::Compression;
    use tempfile::NamedTempFile;

    #[test]
    fn test_load_valid_map() {
        let mut file = NamedTempFile::new().unwrap();
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        
        let width: u16 = 2;
        let height: u16 = 2;
        let data: Vec<u8> = vec![1, 0, 1, 1]; // 1=walkable, 0=non-walkable
        
        encoder.write_all(&width.to_le_bytes()).unwrap();
        encoder.write_all(&height.to_le_bytes()).unwrap();
        encoder.write_all(&data).unwrap();
        let compressed_data = encoder.finish().unwrap();
        file.write_all(&compressed_data).unwrap();

        let map = FieldMap::load(file.path().to_str().unwrap()).unwrap();
        assert_eq!(map.width, 2);
        assert_eq!(map.height, 2);
        assert_eq!(map.data, vec![1, 0, 1, 1]);
    }

    #[test]
    fn test_is_walkable() {
        let map = FieldMap {
            width: 2,
            height: 2,
            data: vec![1, 0, 1, 1],
        };
        assert!(map.is_walkable(0, 0));
        assert!(!map.is_walkable(1, 0));
        assert!(map.is_walkable(0, 1));
        assert!(map.is_walkable(1, 1));
        assert!(!map.is_walkable(2, 2)); // Out of bounds
    }

    #[test]
    fn test_field_map_find_path() {
        let map = FieldMap {
            width: 3,
            height: 3,
            data: vec![1; 9],
        };
        let path = map.find_path((0, 0), (2, 2));
        assert!(path.is_some());
        let path = path.unwrap();
        assert_eq!(path.first().unwrap(), &(0, 0));
        assert_eq!(path.last().unwrap(), &(2, 2));
    }
}
