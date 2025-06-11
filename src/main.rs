use clap::{Parser, Subcommand, ValueEnum};
use anyhow::Result;

mod history;
mod search;
mod storage;

use history::{HistoryManager, SearchScope};

#[derive(Parser)]
#[command(name = "rehash")]
#[command(about = "A lightweight shell history manager with fuzzy search")]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
    /// Path to the history database file
    #[arg(long, global = true)]
    database: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// Add a command to history
    Add {
        /// The command to add
        command: String,
        /// Exit code of the command
        #[arg(short, long, default_value = "0")]
        exit_code: i32,
    },
    /// Search history with fuzzy matching
    Search {
        /// Search query
        query: Option<String>,
        /// Search scope: global, session, or local
        #[arg(short, long, value_enum, default_value = "global")]
        scope: SearchScope,
        /// Maximum number of results
        #[arg(short, long, default_value = "20")]
        max_results: usize,
    },
    /// Interactive fuzzy search
    Interactive {
        /// Initial search scope: global, session, or local
        #[arg(short, long, value_enum, default_value = "global")]
        scope: SearchScope,
        /// Prefill the search query with this text
        #[arg(short, long)]
        prefix: Option<String>,
        /// Write result to file instead of stdout (for shell integration)
        #[arg(long)]
        output_file: Option<String>,
    },
    /// Show statistics
    Stats,
    /// Clear history
    Clear {
        /// Clear scope: global, session, or local
        #[arg(short, long, value_enum, default_value = "global")]
        scope: SearchScope,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();
    let mut history_manager = HistoryManager::new(args.database)?;

    match args.command {
        Some(Commands::Add { command, exit_code }) => {
            history_manager.add_command(&command, exit_code)?;
        }
        Some(Commands::Search { query, scope, max_results }) => {
            let results = if let Some(q) = query {
                history_manager.search(&q, scope, max_results)?
            } else {
                history_manager.list_recent(scope, max_results)?
            };
            
            for entry in results {
                println!("{}", entry.command);
            }
        }
        Some(Commands::Interactive { scope, prefix, output_file }) => {
            if let Some(selected) = history_manager.interactive_search_with_prefix(scope, prefix)? {
                if let Some(file_path) = output_file {
                    std::fs::write(file_path, selected)?;
                } else {
                    print!("{}", selected);
                }
            }
        }
        Some(Commands::Stats) => {
            let stats = history_manager.get_stats()?;
            println!("Total commands: {}", stats.total_commands);
            println!("Unique commands: {}", stats.unique_commands);
            println!("Directory-local commands: {}", stats.local_commands);
        }
        Some(Commands::Clear { scope }) => {
            history_manager.clear_history(scope)?;
            println!("History cleared");
        }
        None => {
            // Default to interactive search
            if let Some(selected) = history_manager.interactive_search_with_prefix(SearchScope::Global, None)? {
                println!("{}", selected);
            }
        }
    }

    Ok(())
}