#!/bin/bash
# Rehash shell integration for Bash

# AIDEV-NOTE: capture command before execution using DEBUG trap
_rehash_preexec() {
    if [[ -n "$BASH_COMMAND" && "$BASH_COMMAND" != "_rehash_preexec" ]]; then
        _REHASH_LAST_COMMAND="$BASH_COMMAND"
    fi
}

# AIDEV-NOTE: capture exit code and log command after execution
_rehash_precmd() {
    local exit_code=$?
    if [[ -n "$_REHASH_LAST_COMMAND" ]]; then
        # Skip rehash commands to avoid recursion
        if [[ "$_REHASH_LAST_COMMAND" != rehash* ]]; then
            rehash add "$_REHASH_LAST_COMMAND" --exit-code "$exit_code" 2>/dev/null || true
        fi
        unset _REHASH_LAST_COMMAND
    fi
}

# AIDEV-NOTE: interactive search with Ctrl+R (global scope)
_rehash_search() {
    local selected
    # Get current command line as prefix
    local current_command="${READLINE_LINE}"
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope global --prefix "$current_command" 2>/dev/null)
    else
        selected=$(rehash interactive --scope global 2>/dev/null)
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
        selected=$(rehash interactive --scope local --prefix "$current_command" 2>/dev/null)
    else
        selected=$(rehash interactive --scope local 2>/dev/null)
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
        selected=$(rehash interactive --scope session --prefix "$current_command" 2>/dev/null)
    else
        selected=$(rehash interactive --scope session 2>/dev/null)
    fi
    if [[ -n "$selected" ]]; then
        READLINE_LINE="$selected"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# Set up hooks
if [[ "$BASH_VERSION" ]]; then
    # Use DEBUG trap for preexec functionality
    trap '_rehash_preexec' DEBUG
    
    # Use PROMPT_COMMAND for precmd functionality
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
export -f _rehash_preexec _rehash_precmd _rehash_search _rehash_search_local _rehash_search_session