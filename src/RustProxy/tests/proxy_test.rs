use tokio::net::TcpStream;
use tokio::io::{AsyncWriteExt, AsyncReadExt};

#[tokio::test]
async fn test_server_connection() {
    // Start server in background
    tokio::spawn(async {
        let _ = kore_packet_proxy::run_server("127.0.0.1:9090").await;
    });

    // Wait for server to start
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    let mut stream = TcpStream::connect("127.0.0.1:9090").await.expect("Failed to connect to proxy");
    let ping = b"PING";
    stream.write_all(ping).await.unwrap();
    
    let mut buf = [0; 1024];
    let n = stream.read(&mut buf).await.unwrap();
    assert_eq!(&buf[..n], b"PONG");
}

#[tokio::test]
async fn test_packet_parsing() {
    // Start server in background
    tokio::spawn(async {
        let _ = kore_packet_proxy::run_server("127.0.0.1:9091").await;
    });

    // Wait for server to start
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    let mut stream = TcpStream::connect("127.0.0.1:9091").await.expect("Failed to connect");
    // Send a mock packet: 0x0080 is often a simple movement/spawn packet. Let's send 4 bytes.
    let packet = vec![0x80, 0x00, 0x01, 0x02];
    stream.write_all(&packet).await.unwrap();
    
    let mut buf = [0; 1024];
    let n = stream.read(&mut buf).await.unwrap();
    let response: serde_json::Value = serde_json::from_slice(&buf[..n]).unwrap();
    assert_eq!(response["switch"].as_u64().unwrap(), 0x0080);
    assert_eq!(response["status"].as_str().unwrap(), "success");
}

#[tokio::test]
async fn test_framing_merged() {
    tokio::spawn(async {
        let _ = kore_packet_proxy::run_server("127.0.0.1:9092").await;
    });
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    let mut stream = TcpStream::connect("127.0.0.1:9092").await.expect("Failed to connect");
    
    // Send two packets merged: 0x80 (4 bytes) and 0x97 (variable, 6 bytes total)
    let packet1 = vec![0x80, 0x00, 0x01, 0x02];
    let packet2 = vec![0x97, 0x00, 0x06, 0x00, 0xCC, 0xDD];
    let mut merged = packet1.clone();
    merged.extend_from_slice(&packet2);
    
    stream.write_all(&merged).await.unwrap();
    
    // Read responses. They might come as two separate writes or one.
    let mut buf = [0; 1024];
    let n = stream.read(&mut buf).await.unwrap();
    
    // The response stream should contain two JSON objects. 
    // We can use a Deserializer to parse multiple objects.
    let mut de = serde_json::Deserializer::from_slice(&buf[..n]).into_iter::<serde_json::Value>();
    
    let resp1 = de.next().unwrap().unwrap();
    assert_eq!(resp1["switch"].as_u64().unwrap(), 0x0080);
    
    let resp2 = de.next().unwrap().unwrap();
    assert_eq!(resp2["switch"].as_u64().unwrap(), 0x0097);
}
