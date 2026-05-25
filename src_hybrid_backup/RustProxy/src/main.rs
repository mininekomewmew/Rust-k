#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    kore_packet_proxy::run_server("127.0.0.1:9090").await?;
    Ok(())
}
