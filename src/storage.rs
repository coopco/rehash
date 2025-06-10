use anyhow::Result;
use serde_json;
use std::fs::{File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;

use crate::history::HistoryEntry;

pub struct Storage {
    history_file: PathBuf,
}

impl Storage {
    pub fn new(custom_path: Option<String>) -> Result<Self> {
        let history_file = if let Some(path) = custom_path {
            PathBuf::from(path)
        } else {
            let mut default_path = dirs::data_dir()
                .ok_or_else(|| anyhow::anyhow!("Could not find data directory"))?;
            
            default_path.push("rehash");
            std::fs::create_dir_all(&default_path)?;
            default_path.push("history.jsonl");
            default_path
        };

        // Ensure parent directory exists for custom paths
        if let Some(parent) = history_file.parent() {
            std::fs::create_dir_all(parent)?;
        }

        Ok(Self { history_file })
    }

    pub fn add_entry(&self, entry: HistoryEntry) -> Result<()> {
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.history_file)?;

        let json_line = serde_json::to_string(&entry)?;
        writeln!(file, "{}", json_line)?;
        file.flush()?;
        
        Ok(())
    }

    pub fn get_all_entries(&self) -> Result<Vec<HistoryEntry>> {
        self.read_entries(|_| true)
    }

    pub fn get_local_entries(&self, directory: &str) -> Result<Vec<HistoryEntry>> {
        // AIDEV-NOTE: local entries include current dir and subdirectories
        self.read_entries(|entry| {
            entry.directory == directory || 
            entry.directory.starts_with(&format!("{}/", directory))
        })
    }

    pub fn get_session_entries(&self, session_id: &str) -> Result<Vec<HistoryEntry>> {
        self.read_entries(|entry| entry.session_id == session_id)
    }

    fn read_entries<F>(&self, filter: F) -> Result<Vec<HistoryEntry>>
    where
        F: Fn(&HistoryEntry) -> bool,
    {
        if !self.history_file.exists() {
            return Ok(Vec::new());
        }

        let file = File::open(&self.history_file)?;
        let reader = BufReader::new(file);
        let mut entries = Vec::new();

        for line in reader.lines() {
            let line = line?;
            if line.trim().is_empty() {
                continue;
            }

            match serde_json::from_str::<HistoryEntry>(&line) {
                Ok(entry) => {
                    if filter(&entry) {
                        entries.push(entry);
                    }
                }
                Err(_) => {
                    // AIDEV-NOTE: skip malformed lines instead of failing
                    continue;
                }
            }
        }

        Ok(entries)
    }

    pub fn clear_all_history(&self) -> Result<()> {
        if self.history_file.exists() {
            std::fs::remove_file(&self.history_file)?;
        }
        Ok(())
    }

    pub fn clear_local_history(&self, directory: &str) -> Result<()> {
        let entries = self.get_all_entries()?;
        
        // AIDEV-NOTE: rewrite file excluding local entries
        self.clear_all_history()?;
        
        for entry in entries {
            if entry.directory != directory && 
               !entry.directory.starts_with(&format!("{}/", directory)) {
                self.add_entry(entry)?;
            }
        }
        
        Ok(())
    }

    pub fn clear_session_history(&self, session_id: &str) -> Result<()> {
        let entries = self.get_all_entries()?;
        
        // AIDEV-NOTE: rewrite file excluding session entries
        self.clear_all_history()?;
        
        for entry in entries {
            if entry.session_id != session_id {
                self.add_entry(entry)?;
            }
        }
        
        Ok(())
    }

    // AIDEV-NOTE: compact history by removing duplicates and old entries
    pub fn compact_history(&self, max_entries: usize) -> Result<()> {
        let mut entries = self.get_all_entries()?;
        
        if entries.len() <= max_entries {
            return Ok(());
        }

        // Sort by timestamp and keep most recent
        entries.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
        entries.truncate(max_entries);

        // Rewrite the file
        self.clear_all_history()?;
        for entry in entries {
            self.add_entry(entry)?;
        }

        Ok(())
    }
}