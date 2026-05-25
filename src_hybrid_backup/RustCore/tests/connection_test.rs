use tokio::net::TcpListener;
use kore_rust_core::network::RoClient;

#[tokio::test]
async fn test_ro_client_connect() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    
    let handle = tokio::spawn(async move {
        let _ = listener.accept().await;
    });
    
    let mut client = RoClient::connect(&addr.to_string(), "user", "pass").await.unwrap();
    assert_eq!(client.addr().unwrap(), addr);

    let packet = client.read_stream().await.expect("Failed to read packet");
    assert!(packet.is_none());
    
    handle.await.unwrap();
}
