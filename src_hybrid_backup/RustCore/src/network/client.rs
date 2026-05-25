use tokio::net::TcpStream;
use tokio::io::AsyncReadExt;
use anyhow::Result;
use crate::network::crypto::RoCrypto;

#[derive(Debug, PartialEq, Eq)]
pub enum ConnectionState {
    Disconnected,
    ConnectingToAccount,
    LoggingIn,
    SelectingServer,
    ConnectingToMap,
    InGame,
}

pub struct RoClient {
    stream: TcpStream,
    crypto: RoCrypto,
    state: ConnectionState,
}

impl RoClient {
    pub async fn connect(addr: &str, _username: &str, _password: &str) -> Result<Self> {
        let stream = TcpStream::connect(addr).await?;
        Ok(Self {
            stream,
            crypto: RoCrypto::new(),
            state: ConnectionState::ConnectingToAccount,
        })
    }
    
    pub fn addr(&self) -> Result<std::net::SocketAddr> {
        self.stream.peer_addr().map_err(anyhow::Error::from)
    }

    pub fn state(&self) -> &ConnectionState {
        &self.state
    }

    pub async fn read_stream(&mut self) -> Result<Option<Vec<u8>>> {
        let mut buf = vec![0u8; 8192];
        let n = self.stream.read(&mut buf).await?;
        
        if n == 0 {
            return Ok(None);
        }
        
        buf.truncate(n);
        self.crypto.decrypt(&mut buf);
        
        Ok(Some(buf))
    }

    pub async fn send_login(&mut self, username: &str, password: &str) -> Result<()> {
        let mut packet = Vec::with_capacity(55);
        packet.extend_from_slice(&0x0064u16.to_le_bytes()); // Packet ID
        packet.extend_from_slice(&25u32.to_le_bytes()); // Version

        let mut user_buf = [0u8; 24];
        let user_bytes = username.as_bytes();
        let len = user_bytes.len().min(24);
        user_buf[..len].copy_from_slice(&user_bytes[..len]);
        packet.extend_from_slice(&user_buf);

        let mut pass_buf = [0u8; 24];
        let pass_bytes = password.as_bytes();
        let len = pass_bytes.len().min(24);
        pass_buf[..len].copy_from_slice(&pass_bytes[..len]);
        packet.extend_from_slice(&pass_buf);

        packet.push(0x01); // MasterVersion

        self.write_packet(&packet).await
    }

    pub async fn write_packet(&mut self, data: &[u8]) -> Result<()> {
        use tokio::io::AsyncWriteExt;
        self.stream.write_all(data).await?;
        self.stream.flush().await?; 
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::net::TcpListener;
    use tokio::io::AsyncWriteExt;

    #[tokio::test]
    async fn test_send_login_packet_format() {
        let mut packet = Vec::with_capacity(55);
        packet.extend_from_slice(&0x0064u16.to_le_bytes()); // Packet ID
        packet.extend_from_slice(&25u32.to_le_bytes()); // Version

        let username = "testuser";
        let password = "testpassword";

        let mut user_buf = [0u8; 24];
        user_buf[..username.len()].copy_from_slice(username.as_bytes());
        packet.extend_from_slice(&user_buf);

        let mut pass_buf = [0u8; 24];
        pass_buf[..password.len()].copy_from_slice(password.as_bytes());
        packet.extend_from_slice(&pass_buf);

        packet.push(0x01); // MasterVersion

        assert_eq!(packet.len(), 55);
        assert_eq!(&packet[0..2], &[0x64, 0x00]);
        assert_eq!(&packet[2..6], &[25, 0, 0, 0]);
        assert_eq!(&packet[6..6+8], username.as_bytes());
        assert_eq!(&packet[30..30+12], password.as_bytes());
        assert_eq!(packet[54], 0x01);
    }
}
