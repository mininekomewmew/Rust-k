use clap::{Parser, Subcommand};
use std::fs::File;
use std::io::{BufRead, BufReader};

#[derive(Parser)]
#[command(name = "kore-console")]
#[command(about = "Manage multiple OpenKore bots", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    List,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    match &cli.command {
        Commands::List => {
            if let Ok(file) = File::open("logs/bots.registry") {
                let reader = BufReader::new(file);
                for line in reader.lines().flatten() {
                    let parts: Vec<&str> = line.split(',').collect();
                    if parts.len() == 3 {
                        println!("Bot {} (PID: {}) listening on {}", parts[1], parts[0], parts[2]);
                    }
                }
            } else {
                println!("No bots registered in logs/bots.registry");
            }
        }
    }
    Ok(())
}
