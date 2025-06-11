#!/bin/bash
# Rehash shell integration for Bash

# Generate a session ID that persists for this shell session
if [[ -z "$REHASH_SESSION_ID" ]]; then
    # Use the terminal's PID instead of shell PID for consistency across shell changes
    export REHASH_SESSION_ID="$(ps -o ppid= -p $$ | tr -d ' ')_$(date +%s)"
fi

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
        rehash add "$last_cmd" --exit-code "$exit_code" 2>/dev/null || true
    fi
}

# AIDEV-NOTE: interactive search with Ctrl+R (global scope)
_rehash_search() {
    local selected
    # Get current command line as prefix
    local current_command="${READLINE_LINE}"
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope global --prefix "$current_command" </dev/tty >/dev/tty 2>&1)
    else
        selected=$(rehash interactive --scope global </dev/tty >/dev/tty 2>&1)
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
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope local --prefix "$current_command" </dev/tty >/dev/tty 2>&1)
    else
        selected=$(rehash interactive --scope local </dev/tty >/dev/tty 2>&1)
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
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope session --prefix "$current_command" </dev/tty >/dev/tty 2>&1)
    else
        selected=$(rehash interactive --scope session </dev/tty >/dev/tty 2>&1)
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
export -f _rehash_precmd _rehash_search _rehash_search_local _rehash_search_session