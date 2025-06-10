use anyhow::Result;
use chrono::Utc;
use console::style;
use crossterm::{
    cursor,
    event::{self, Event, KeyCode, KeyModifiers},
    execute,
    terminal::{self, disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen, size},
};
use fuzzy_matcher::{skim::SkimMatcherV2, FuzzyMatcher};
use std::io::{self, Write, stdout};

use crate::history::{HistoryEntry, SearchScope};

// AIDEV-NOTE: format timestamp as human-readable relative time
fn format_relative_time(timestamp: &chrono::DateTime<chrono::Utc>) -> String {
    let now = Utc::now();
    let duration = now.signed_duration_since(*timestamp);
    
    if duration.num_days() > 0 {
        let days = duration.num_days();
        if days > 365 {
            format!("{}y ago", days / 365)
        } else if days > 30 {
            format!("{}mo ago", days / 30)
        } else {
            format!("{}d ago", days)
        }
    } else if duration.num_hours() > 0 {
        format!("{}h ago", duration.num_hours())
    } else if duration.num_minutes() > 0 {
        format!("{}m ago", duration.num_minutes())
    } else {
        "now".to_string()
    }
}

pub struct FuzzySearcher {
    matcher: SkimMatcherV2,
}

impl FuzzySearcher {
    pub fn new() -> Self {
        Self {
            matcher: SkimMatcherV2::default(),
        }
    }

    pub fn search(&self, query: &str, entries: &[HistoryEntry], max_results: usize) -> Vec<HistoryEntry> {
        let mut scored_entries: Vec<(i64, &HistoryEntry)> = entries
            .iter()
            .filter_map(|entry| {
                self.matcher
                    .fuzzy_match(&entry.command, query)
                    .map(|score| (score, entry))
            })
            .collect();

        // AIDEV-NOTE: sort by score descending, then by timestamp for ties
        scored_entries.sort_by(|a, b| {
            b.0.cmp(&a.0).then_with(|| b.1.timestamp.cmp(&a.1.timestamp))
        });

        scored_entries
            .into_iter()
            .take(max_results)
            .map(|(_, entry)| entry.clone())
            .collect()
    }
}

pub struct InteractiveSearcher {
    all_entries: Vec<HistoryEntry>,
    filtered_entries: Vec<HistoryEntry>,
    query: String,
    selected_index: usize,
    scroll_offset: usize,
    searcher: FuzzySearcher,
    current_scope: SearchScope,
    current_dir: String,
    session_id: String,
}

impl InteractiveSearcher {
    pub fn new(
        all_entries: Vec<HistoryEntry>, 
        initial_scope: SearchScope, 
        current_dir: &str, 
        session_id: &str
    ) -> Self {
        Self::new_with_prefix(all_entries, initial_scope, current_dir, session_id, None)
    }

    pub fn new_with_prefix(
        all_entries: Vec<HistoryEntry>, 
        initial_scope: SearchScope, 
        current_dir: &str, 
        session_id: &str,
        prefix: Option<String>
    ) -> Self {
        let mut searcher = Self {
            all_entries,
            filtered_entries: Vec::new(),
            query: prefix.unwrap_or_default(),
            selected_index: 0,
            scroll_offset: 0,
            searcher: FuzzySearcher::new(),
            current_scope: initial_scope,
            current_dir: current_dir.to_string(),
            session_id: session_id.to_string(),
        };
        
        searcher.update_filter();
        searcher
    }

    pub fn run(mut self) -> Result<Option<String>> {
        enable_raw_mode()?;
        execute!(io::stdout(), EnterAlternateScreen)?;

        let result = self.main_loop();

        disable_raw_mode()?;
        execute!(io::stdout(), LeaveAlternateScreen)?;

        result
    }

    fn main_loop(&mut self) -> Result<Option<String>> {
        loop {
            self.render()?;

            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        return Ok(None);
                    }
                    KeyCode::Esc => {
                        return Ok(None);
                    }
                    KeyCode::Enter => {
                        if let Some(entry) = self.filtered_entries.get(self.selected_index) {
                            return Ok(Some(entry.command.clone()));
                        }
                        return Ok(None);
                    }
                    KeyCode::Up => {
                        if self.selected_index > 0 {
                            self.selected_index -= 1;
                            self.update_scroll();
                        }
                    }
                    KeyCode::Down => {
                        if self.selected_index < self.filtered_entries.len().saturating_sub(1) {
                            self.selected_index += 1;
                            self.update_scroll();
                        }
                    }
                    // AIDEV-NOTE: hotkeys for scope switching
                    KeyCode::F(1) => {
                        self.current_scope = SearchScope::Global;
                        self.update_filter();
                        self.update_scroll();
                    }
                    KeyCode::F(2) => {
                        self.current_scope = SearchScope::Session;
                        self.update_filter();
                        self.update_scroll();
                    }
                    KeyCode::F(3) => {
                        self.current_scope = SearchScope::Local;
                        self.update_filter();
                        self.update_scroll();
                    }
                    KeyCode::Tab => {
                        // AIDEV-NOTE: cycle through scopes with Tab
                        self.current_scope = match self.current_scope {
                            SearchScope::Global => SearchScope::Session,
                            SearchScope::Session => SearchScope::Local,
                            SearchScope::Local => SearchScope::Global,
                        };
                        self.update_filter();
                        self.update_scroll();
                    }
                    KeyCode::Char(c) => {
                        self.query.push(c);
                        self.update_filter();
                        self.update_scroll();
                    }
                    KeyCode::Backspace => {
                        self.query.pop();
                        self.update_filter();
                        self.update_scroll();
                    }
                    _ => {}
                }
            }
        }
    }

    fn update_filter(&mut self) {
        // AIDEV-NOTE: first filter by scope, then by query
        let mut scope_filtered = self.filter_by_scope();
        
        if self.query.is_empty() {
            // AIDEV-NOTE: sort by timestamp when no search query (oldest first)
            scope_filtered.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
            self.filtered_entries = scope_filtered;
        } else {
            self.filtered_entries = self.searcher.search(&self.query, &scope_filtered, 50);
            // AIDEV-NOTE: maintain timestamp order for search results too
            self.filtered_entries.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
        }
        
        // AIDEV-NOTE: reset selection to most recent (last item) when filter changes
        self.selected_index = self.filtered_entries.len().saturating_sub(1);
        self.scroll_offset = 0;
        self.update_scroll();
    }

    fn filter_by_scope(&self) -> Vec<HistoryEntry> {
        match self.current_scope {
            SearchScope::Global => self.all_entries.clone(),
            SearchScope::Session => self.all_entries
                .iter()
                .filter(|entry| entry.session_id == self.session_id)
                .cloned()
                .collect(),
            SearchScope::Local => self.all_entries
                .iter()
                .filter(|entry| {
                    entry.directory == self.current_dir || 
                    entry.directory.starts_with(&format!("{}/", self.current_dir))
                })
                .cloned()
                .collect(),
        }
    }

    fn update_scroll(&mut self) {
        let (_, rows) = terminal::size().unwrap_or((80, 24));
        let header_lines = 1; // Updated to match render function
        let available_rows = rows.saturating_sub(header_lines + 1) as usize;
        
        if available_rows == 0 {
            return;
        }
        
        // AIDEV-NOTE: Atuin-style proactive scrolling at 35% threshold
        let scroll_threshold = (available_rows as f32 * 0.35).max(1.0) as usize;
        
        // Current position relative to scroll window
        let current_pos_in_window = self.selected_index.saturating_sub(self.scroll_offset);
        
        // AIDEV-NOTE: Scroll one line at a time for smooth visual movement
        // Scroll up if selection is too close to top of visible area
        if current_pos_in_window < scroll_threshold && self.scroll_offset > 0 {
            self.scroll_offset = self.scroll_offset.saturating_sub(1);
        }
        // Scroll down if selection is too close to bottom of visible area
        else if current_pos_in_window >= available_rows.saturating_sub(scroll_threshold) {
            let max_offset = self.filtered_entries.len().saturating_sub(available_rows);
            if self.scroll_offset < max_offset {
                self.scroll_offset += 1;
            }
        }
        
        // Ensure scroll bounds are respected (fallback safety)
        if self.selected_index < self.scroll_offset {
            self.scroll_offset = self.selected_index;
        } else if self.selected_index >= self.scroll_offset + available_rows {
            self.scroll_offset = self.selected_index.saturating_sub(available_rows.saturating_sub(1));
        }
    }

    fn render(&self) -> Result<()> {
        let (cols, rows) = size()?;
        let mut stdout = stdout();
        
        // Clear screen and move to top
        execute!(stdout, terminal::Clear(terminal::ClearType::All))?;
        
        // AIDEV-NOTE: calculate layout with single header line (no horizontal separator)
        let header_lines = 1;
        let available_rows = rows.saturating_sub(header_lines + 1) as usize;
        
        // Split header: scope indicator on left, help+rehash on right
        let scope_prompt = match self.current_scope {
            SearchScope::Global => style("[ GLOBAL ]").cyan().bold(),
            SearchScope::Session => style("[ SESSION ]").yellow().bold(),
            SearchScope::Local => style("[ DIRECTORY ]").green().bold(),
        };
        
        let help_text = style("F1-F3: Scope | Tab: Cycle").black().bright();
        let rehash_text = style("  rehash").white();
        let right_content = format!("{}{}", help_text, rehash_text);
        
        // AIDEV-NOTE: calculate padding between left and right parts
        let scope_display_width = match self.current_scope {
            SearchScope::Global => "[ GLOBAL ]".len(),
            SearchScope::Session => "[ SESSION ]".len(), 
            SearchScope::Local => "[ DIRECTORY ]".len(),
        };
        let right_display_width = "F1-F3: Scope | Tab: Cycle  rehash".len();
        
        let middle_padding = if cols as usize > scope_display_width + right_display_width {
            " ".repeat(cols as usize - scope_display_width - right_display_width)
        } else {
            " ".to_string()
        };
        
        execute!(stdout, cursor::MoveTo(0, 0))?;
        println!("{}{}{}\r", scope_prompt, middle_padding, right_content);

        // AIDEV-NOTE: show entries in chronological order (oldest first) so newest appears at bottom near prompt
        let start_idx = self.scroll_offset;
        let end_idx = (start_idx + available_rows).min(self.filtered_entries.len());
        
        for (display_row, entry_idx) in (start_idx..end_idx).enumerate() {
            if let Some(entry) = self.filtered_entries.get(entry_idx) {
                let is_selected = entry_idx == self.selected_index;
                let row = header_lines + display_row as u16;
                
                execute!(stdout, cursor::MoveTo(0, row))?;
                
                // Format time column
                let time_str = format!("{:>8}", format_relative_time(&entry.timestamp));
                let time_colored = if is_selected {
                    style(time_str).black().on_white()
                } else {
                    style(time_str).blue()
                };
                
                // AIDEV-NOTE: calculate available space for command
                let time_width = 10;
                let available_cmd_width = cols.saturating_sub(time_width + 2) as usize;
                
                // Truncate command if too long
                let command = if entry.command.len() > available_cmd_width {
                    format!("{}…", &entry.command[..available_cmd_width.saturating_sub(1)])
                } else {
                    entry.command.clone()
                };
                
                let command_colored = if is_selected {
                    style(format!(" {}", command)).black().on_white().bold()
                } else {
                    style(format!(" {}", command)).white()
                };
                
                print!("{}{}\r", time_colored, command_colored);
            }
        }
        
        // Input prompt at bottom
        let prompt_row = rows.saturating_sub(1);
        execute!(stdout, cursor::MoveTo(0, prompt_row))?;
        
        let query_display = if self.query.is_empty() {
            style("Type to search...").blue().italic()
        } else {
            style(self.query.as_str()).white().bold()
        };
        
        print!("{} {}", style(">").cyan().bold(), query_display);
        
        stdout.flush()?;
        Ok(())
    }
}
