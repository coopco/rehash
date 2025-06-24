#!/bin/bash
# Rehash shell integration for Bash

# Generate a session ID that persists for this shell session
if [[ -z "$REHASH_SESSION_ID" ]]; then
    # Use the terminal's PID instead of shell PID for consistency across shell changes
    export REHASH_SESSION_ID="$(ps -o ppid= -p $$ | tr -d ' ')_$(date +%s)"
fi

# Helper function to build rehash command with multi-source support
_rehash_build_cmd() {
    local hostname=$(hostname)
    local history_dir="$HOME/.local/share/rehash"
    local primary_db="$history_dir/$hostname.jsonl"
    local read_sources=""
    
    # Create history directory if it doesn't exist
    mkdir -p "$history_dir"
    
    # Find all other .jsonl files in the directory (excluding current hostname)
    for jsonl_file in "$history_dir"/*.jsonl; do
        if [[ -f "$jsonl_file" && "$(basename "$jsonl_file")" != "$hostname.jsonl" ]]; then
            if [[ -n "$read_sources" ]]; then
                read_sources="$read_sources,$jsonl_file"
            else
                read_sources="$jsonl_file"
            fi
        fi
    done
    
    # Build the rehash command
    local cmd="rehash --database \"$primary_db\""
    if [[ -n "$read_sources" ]]; then
        cmd="$cmd --read-sources \"$read_sources\""
    fi
    
    echo "$cmd"
}

# AIDEV-NOTE: capture command using history
_rehash_precmd() {
    local exit_code=$?
    
    # Skip during shell initialization
    if [[ -z "$_REHASH_INITIALIZED" ]]; then
        _REHASH_INITIALIZED=1
        return
    fi
    
    # Get the last command from history
    local last_cmd=$(history 1 | sed 's/^ *[0-9]* *//')
    
    # Skip problematic commands
    if [[ -n "$last_cmd" && 
          "$last_cmd" != rehash* && 
          "$last_cmd" != "_rehash_precmd" &&
          "$last_cmd" != "'" &&
          "$last_cmd" != '"' &&
          ${#last_cmd} -gt 1 ]]; then
        eval "$(_rehash_build_cmd) add \"$last_cmd\" --exit-code \"$exit_code\"" 2>/dev/null || true
    fi
}

# AIDEV-NOTE: interactive search with Ctrl+R (global scope)
_rehash_search() {
    local selected
    # Get current command line as prefix
    local current_command="${READLINE_LINE}"
    # Use temp file to capture result
    local temp_file="/tmp/rehash_result_$$"
    
    # Run rehash interactively - let it take control of terminal
    if [[ -n "$current_command" ]]; then
        eval "$(_rehash_build_cmd) interactive --scope global --prefix \"$current_command\" --output-file \"$temp_file\""
    else
        eval "$(_rehash_build_cmd) interactive --scope global --output-file \"$temp_file\""
    fi
    
    # Read result from temp file
    if [[ -f "$temp_file" ]]; then
        selected=$(cat "$temp_file")
        rm -f "$temp_file"
    fi
    if [[ -n "$selected" ]]; then
        READLINE_LINE="$selected"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# AIDEV-NOTE: directory-local search with Ctrl+T
_rehash_search_local() {
    local selected
    # Get current command line as prefix
    local current_command="${READLINE_LINE}"
    # Use temp file to capture result
    local temp_file="/tmp/rehash_result_$$"
    
    # Run rehash interactively - let it take control of terminal
    if [[ -n "$current_command" ]]; then
        eval "$(_rehash_build_cmd) interactive --scope local --prefix \"$current_command\" --output-file \"$temp_file\""
    else
        eval "$(_rehash_build_cmd) interactive --scope local --output-file \"$temp_file\""
    fi
    
    # Read result from temp file
    if [[ -f "$temp_file" ]]; then
        selected=$(cat "$temp_file")
        rm -f "$temp_file"
    fi
    if [[ -n "$selected" ]]; then
        READLINE_LINE="$selected"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# AIDEV-NOTE: session search with Alt+R
_rehash_search_session() {
    local selected
    # Get current command line as prefix
    local current_command="${READLINE_LINE}"
    # Use temp file to capture result
    local temp_file="/tmp/rehash_result_$$"
    
    # Run rehash interactively - let it take control of terminal
    if [[ -n "$current_command" ]]; then
        eval "$(_rehash_build_cmd) interactive --scope session --prefix \"$current_command\" --output-file \"$temp_file\""
    else
        eval "$(_rehash_build_cmd) interactive --scope session --output-file \"$temp_file\""
    fi
    
    # Read result from temp file
    if [[ -f "$temp_file" ]]; then
        selected=$(cat "$temp_file")
        rm -f "$temp_file"
    fi
    if [[ -n "$selected" ]]; then
        READLINE_LINE="$selected"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# Set up hooks
if [[ "$BASH_VERSION" ]]; then
    # Use PROMPT_COMMAND for capturing commands from history
    if [[ -z "$PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND="_rehash_precmd"
    else
        PROMPT_COMMAND="$PROMPT_COMMAND; _rehash_precmd"
    fi
    
    # Set up key bindings
    bind -x '"\C-r": _rehash_search'
    bind -x '"\C-t": _rehash_search_local'
    bind -x '"\er": _rehash_search_session'  # Alt+R
fi

# Export functions for subshells
export -f _rehash_build_cmd _rehash_precmd _rehash_search _rehash_search_local _rehash_search_session