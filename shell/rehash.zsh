#!/bin/zsh
# Rehash shell integration for Zsh

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

# AIDEV-NOTE: capture command before execution
_rehash_preexec() {
    _REHASH_LAST_COMMAND="$1"
}

# AIDEV-NOTE: capture exit code and log command after execution  
_rehash_precmd() {
    local exit_code=$?
    
    # Skip during shell initialization
    if [[ -z "$_REHASH_INITIALIZED" ]]; then
        _REHASH_INITIALIZED=1
        return
    fi
    
    if [[ -n "$_REHASH_LAST_COMMAND" ]]; then
        # Skip problematic commands
        if [[ "$_REHASH_LAST_COMMAND" != rehash* && 
              "$_REHASH_LAST_COMMAND" != "'" && 
              "$_REHASH_LAST_COMMAND" != '"' && 
              ${#_REHASH_LAST_COMMAND} -gt 1 ]]; then
            eval "$(_rehash_build_cmd) add \"$_REHASH_LAST_COMMAND\" --exit-code \"$exit_code\"" 2>/dev/null || true
        fi
        unset _REHASH_LAST_COMMAND
    fi
}

# AIDEV-NOTE: interactive search widget for Ctrl+R (global scope)
_rehash_search_widget() {
    local selected
    # Get current command line as prefix
    local current_command="$BUFFER"
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
        LBUFFER="$selected"
    fi
    zle reset-prompt
}

# AIDEV-NOTE: directory-local search widget for Ctrl+T
_rehash_search_local_widget() {
    local selected
    # Get current command line as prefix
    local current_command="$BUFFER"
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
        LBUFFER="$selected"
    fi
    zle reset-prompt
}

# AIDEV-NOTE: session search widget for Alt+R
_rehash_search_session_widget() {
    local selected
    # Get current command line as prefix
    local current_command="$BUFFER"
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
        LBUFFER="$selected"
    fi
    zle reset-prompt
}

# Register widgets
zle -N _rehash_search_widget
zle -N _rehash_search_local_widget
zle -N _rehash_search_session_widget

# Set up hooks
autoload -Uz add-zsh-hook
add-zsh-hook preexec _rehash_preexec
add-zsh-hook precmd _rehash_precmd

# Set up key bindings
bindkey '^R' _rehash_search_widget
bindkey '^T' _rehash_search_local_widget
bindkey '\er' _rehash_search_session_widget  # Alt+R