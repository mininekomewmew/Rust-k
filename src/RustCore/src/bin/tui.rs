use std::fs::File;
use std::io::{BufRead, BufReader, stdout};
use std::time::Duration;
use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    widgets::{Block, Borders, Row, Table, Paragraph},
    Terminal,
};

#[derive(Clone)]
struct BotInfo {
    pid: String,
    bot_id: String,
    port: String,
}

fn load_bots() -> Vec<BotInfo> {
    let mut bots = Vec::new();
    if let Ok(file) = File::open("logs/bots.registry") {
        let reader = BufReader::new(file);
        for line in reader.lines().flatten() {
            let parts: Vec<&str> = line.split(',').collect();
            if parts.len() == 3 {
                bots.push(BotInfo {
                    pid: parts[0].to_string(),
                    bot_id: parts[1].to_string(),
                    port: parts[2].to_string(),
                });
            }
        }
    }
    bots
}

fn main() -> Result<()> {
    enable_raw_mode()?;
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    loop {
        let bots = load_bots();

        terminal.draw(|f| {
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .margin(1)
                .constraints(
                    [
                        Constraint::Length(3),
                        Constraint::Min(5),
                    ]
                    .as_ref(),
                )
                .split(f.size());

            let header = Paragraph::new("HybridKore Multi-Bot Monitor (Press 'q' to quit)")
                .block(Block::default().borders(Borders::ALL));
            f.render_widget(header, chunks[0]);

            let mut rows = Vec::new();
            for bot in bots {
                rows.push(Row::new(vec![bot.bot_id, bot.pid, bot.port, "Running".to_string()]));
            }

            let table = Table::new(
                rows,
                [
                    Constraint::Percentage(30),
                    Constraint::Percentage(20),
                    Constraint::Percentage(20),
                    Constraint::Percentage(30),
                ]
            )
            .header(Row::new(vec!["Bot ID", "PID", "IPC Port", "Status"]))
            .block(Block::default().title("Active Bots").borders(Borders::ALL));

            f.render_widget(table, chunks[1]);
        })?;

        if event::poll(Duration::from_millis(500))? {
            if let Event::Key(key) = event::read()? {
                if let KeyCode::Char('q') = key.code {
                    break;
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}
