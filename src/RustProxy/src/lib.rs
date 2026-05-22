use tokio::net::TcpListener;
use tokio::io::{AsyncReadExt, AsyncWriteExt, AsyncRead, AsyncWrite};
use bytes::{BytesMut, Buf};

pub mod parser;
use crate::parser::PacketParser;

pub async fn run_server(addr: &str) -> Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind(addr).await?;
    println!("Packet Proxy listening on {}", addr);

    loop {
        let (socket, _) = listener.accept().await?;
        tokio::spawn(async move {
            if let Err(e) = handle_connection(socket).await {
                eprintln!("Connection error: {}", e);
            }
        });
    }
}

pub async fn handle_connection<S>(mut socket: S) -> Result<(), std::io::Error>
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let parser = PacketParser::new();
    let mut buf = BytesMut::with_capacity(4096);
    
    loop {
        let n = socket.read_buf(&mut buf).await?;
        if n == 0 {
            break;
        }

        // Process all complete packets in the buffer
        loop {
            if buf.len() < 2 {
                break;
            }

            // Simple PING/PONG handling (out-of-band for proxy)
            if buf.len() >= 4 && &buf[0..4] == b"PING" {
                socket.write_all(b"PONG").await?;
                buf.advance(4);
                continue;
            }

            let switch = u16::from_le_bytes([buf[0], buf[1]]);
            match parser.get_packet_length(switch, &buf) {
                Some(len) if buf.len() >= len => {
                    // Extract exactly one packet
                    let packet_data = buf.split_to(len);
                    
                    match parser.parse_packet(&packet_data) {
                        Ok(parsed) => {
                            match serde_json::to_string(&parsed) {
                                Ok(json) => {
                                    if let Err(e) = socket.write_all(json.as_bytes()).await {
                                        return Err(e);
                                    }
                                }
                                Err(e) => {
                                    let err_json = format!(r#"{{"error": "JSON serialization failed: {}"}}"#, e);
                                    let _ = socket.write_all(err_json.as_bytes()).await;
                                }
                            }
                        }
                        Err(e) => {
                            let err_json = format!(r#"{{"error": "{}"}}"#, e);
                            let _ = socket.write_all(err_json.as_bytes()).await;
                        }
                    }
                }
                _ => {
                    // Not enough data for a complete packet, wait for more
                    break;
                }
            }
        }

        // Prevent runaway buffer growth if we can't parse anything
        if buf.len() > 65536 {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                "Buffer size exceeded 64KB - possible protocol mismatch or huge packet",
            ));
        }
    }
    Ok(())
}
