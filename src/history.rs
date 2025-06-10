use anyhow::Result;
use chrono::{DateTime, Utc};
use clap::ValueEnum;
use serde::{Deserialize, Serialize};
use std::env;

use crate::search::FuzzySearcher;
use crate::storage::Storage;

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum SearchScope {
    /// Search all history across all directories and sessions
    Global,
    /// Search current session across all directories
    Session,
    /// Search current directory across all sessions
    Local,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub command: String,
    pub timestamp: DateTime<Utc>,
    pub directory: String,
    pub exit_code: i32,
    pub session_id: String,
}

#[derive(Debug)]
pub struct HistoryStats {
    pub total_commands: usize,
    pub unique_commands: usize,
    pub local_commands: usize,
}

pub struct HistoryManager {
    storage: Storage,
    searcher: FuzzySearcher,
    current_dir: String,
    session_id: String,
}

impl HistoryManager {
    pub fn new(database_path: Option<String>) -> Result<Self> {
        let current_dir = env::current_dir()?
            .to_string_lossy()
            .to_string();
        
        // AIDEV-NOTE: session-id uses PID+timestamp for uniqueness across shells
        let session_id = format!("{}_{}", 
            std::process::id(), 
            Utc::now().timestamp()
        );

        Ok(Self {
            storage: Storage::new(database_path)?,
            searcher: FuzzySearcher::new(),
            current_dir,
            session_id,
        })
    }

    pub fn add_command(&mut self, command: &str, exit_code: i32) -> Result<()> {
        let entry = HistoryEntry {
            command: command.to_string(),
            timestamp: Utc::now(),
            directory: self.current_dir.clone(),
            exit_code,
            session_id: self.session_id.clone(),
        };

        self.storage.add_entry(entry)
    }

    pub fn search(&self, query: &str, scope: SearchScope, max_results: usize) -> Result<Vec<HistoryEntry>> {
        let entries = self.get_entries_by_scope(scope)?;
        Ok(self.searcher.search(query, &entries, max_results))
    }

    pub fn list_recent(&self, scope: SearchScope, max_results: usize) -> Result<Vec<HistoryEntry>> {
        let mut entries = self.get_entries_by_scope(scope)?;

        // AIDEV-NOTE: sort by timestamp ascending (chronological order) to match interactive UI
        entries.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
        // Take the most recent entries (from the end)
        if entries.len() > max_results {
            entries = entries.into_iter().rev().take(max_results).collect::<Vec<_>>();
            entries.reverse(); // Put back in chronological order
        }
        Ok(entries)
    }

    pub fn interactive_search(&self, initial_scope: SearchScope) -> Result<Option<String>> {
        self.interactive_search_with_prefix(initial_scope, None)
    }

    pub fn interactive_search_with_prefix(&self, initial_scope: SearchScope, prefix: Option<String>) -> Result<Option<String>> {
        use crate::search::InteractiveSearcher;
        
        let all_entries = self.storage.get_all_entries()?;
        let interactive = InteractiveSearcher::new_with_prefix(
            all_entries, 
            initial_scope, 
            &self.current_dir, 
            &self.session_id,
            prefix
        );
        interactive.run()
    }

    fn get_entries_by_scope(&self, scope: SearchScope) -> Result<Vec<HistoryEntry>> {
        match scope {
            SearchScope::Global => self.storage.get_all_entries(),
            SearchScope::Session => self.storage.get_session_entries(&self.session_id),
            SearchScope::Local => self.storage.get_local_entries(&self.current_dir),
        }
    }

    pub fn get_stats(&self) -> Result<HistoryStats> {
        let all_entries = self.storage.get_all_entries()?;
        let local_entries = self.storage.get_local_entries(&self.current_dir)?;
        
        let unique_commands: std::collections::HashSet<_> = all_entries
            .iter()
            .map(|e| &e.command)
            .collect();

        Ok(HistoryStats {
            total_commands: all_entries.len(),
            unique_commands: unique_commands.len(),
            local_commands: local_entries.len(),
        })
    }

    pub fn clear_history(&mut self, scope: SearchScope) -> Result<()> {
        match scope {
            SearchScope::Global => self.storage.clear_all_history(),
            SearchScope::Session => self.storage.clear_session_history(&self.session_id),
            SearchScope::Local => self.storage.clear_local_history(&self.current_dir),
        }
    }
}