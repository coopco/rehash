#!/bin/zsh
# Rehash shell integration for Zsh

# AIDEV-NOTE: capture command before execution
_rehash_preexec() {
    _REHASH_LAST_COMMAND="$1"
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

# AIDEV-NOTE: interactive search widget for Ctrl+R (global scope)
_rehash_search_widget() {
    local selected
    # Get current command line as prefix
    local current_command="$BUFFER"
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope global --prefix "$current_command" 2>/dev/null)
    else
        selected=$(rehash interactive --scope global 2>/dev/null)
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
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope local --prefix "$current_command" 2>/dev/null)
    else
        selected=$(rehash interactive --scope local 2>/dev/null)
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
    if [[ -n "$current_command" ]]; then
        selected=$(rehash interactive --scope session --prefix "$current_command" 2>/dev/null)
    else
        selected=$(rehash interactive --scope session 2>/dev/null)
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