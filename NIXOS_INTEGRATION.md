# NixOS Integration Guide for Rehash

This guide shows how to integrate rehash with bash and zsh in your NixOS configuration.

## Overview

Rehash provides shell integration scripts that automatically:
- Capture command history from your shell sessions
- Enable Ctrl+R (global), Ctrl+T (local), and Alt+R (session) search hotkeys
- Prefill searches with your current command line text
- Persist history across shell changes (e.g., `nix develop`)

## Method 1: Using Flake Input (Recommended)

### Step 1: Add Rehash as a Flake Input

Add rehash to your system flake inputs in `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    
    # Add rehash as input
    rehash = {
      url = "path:/home/connor/Projects/rehash";  # or github:user/rehash when published
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, rehash, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.yourusername = { pkgs, ... }: {
            # Make rehash available
            home.packages = [ rehash.packages.${pkgs.system}.default ];
            
            # Configure bash integration
            programs.bash = {
              enable = true;
              initExtra = ''
                source ${rehash}/shell/rehash.bash
              '';
            };
            
            # Configure zsh integration
            programs.zsh = {
              enable = true;
              initExtra = ''
                source ${rehash}/shell/rehash.zsh
              '';
            };
          };
        }
      ];
    };
  };
}
```

## Method 2: Local Package Build

If you prefer to build rehash as a local package:

### Step 1: Add Package Definition

Add to your NixOS configuration or overlay:

```nix
{ pkgs, ... }: 

let
  rehash = pkgs.rustPlatform.buildRustPackage {
    pname = "rehash";
    version = "0.1.0";
    src = /path/to/rehash/source;  # or fetchFromGitHub
    
    cargoLock = {
      lockFile = /path/to/rehash/Cargo.lock;
    };
    
    buildInputs = with pkgs; [
      # Add any runtime dependencies here
    ];
    
    meta = with pkgs.lib; {
      description = "A lightweight shell history manager with fuzzy search";
      license = licenses.mit;  # or appropriate license
      maintainers = [ maintainers.yourname ];
    };
  };
in
{
  # Your configuration continues...
}
```

### Step 2: Configure Shell Integration

```nix
{ pkgs, ... }:

{
  home-manager.users.yourusername = {
    home.packages = [ rehash ];
    
    programs.bash = {
      enable = true;
      initExtra = ''
        # Source rehash bash integration
        if command -v rehash &> /dev/null; then
          REHASH_SHELL_DIR="$(dirname "$(command -v rehash)")/../share/rehash/shell"
          if [[ -f "$REHASH_SHELL_DIR/rehash.bash" ]]; then
            source "$REHASH_SHELL_DIR/rehash.bash"
          fi
        fi
      '';
    };
    
    programs.zsh = {
      enable = true;
      initExtra = ''
        # Source rehash zsh integration
        if command -v rehash &> /dev/null; then
          REHASH_SHELL_DIR="$(dirname "$(command -v rehash)")/../share/rehash/shell"
          if [[ -f "$REHASH_SHELL_DIR/rehash.zsh" ]]; then
            source "$REHASH_SHELL_DIR/rehash.zsh"
          fi
        fi
      '';
    };
  };
}
```

## Method 3: Direct File Installation

For simpler setups, you can install the shell scripts directly:

```nix
{ pkgs, ... }:

{
  home-manager.users.yourusername = {
    # Install rehash binary
    home.packages = [ rehash ];
    
    # Install shell integration files
    home.file = {
      ".local/share/rehash/shell/rehash.bash".source = /path/to/rehash/shell/rehash.bash;
      ".local/share/rehash/shell/rehash.zsh".source = /path/to/rehash/shell/rehash.zsh;
    };
    
    programs.bash = {
      enable = true;
      initExtra = ''
        source ~/.local/share/rehash/shell/rehash.bash
      '';
    };
    
    programs.zsh = {
      enable = true;
      initExtra = ''
        source ~/.local/share/rehash/shell/rehash.zsh
      '';
    };
  };
}
```

## Advanced Configuration

### Custom Key Bindings

You can customize the key bindings by modifying the shell integration:

```nix
programs.bash.initExtra = ''
  source ${rehash}/shell/rehash.bash
  
  # Override default key bindings
  bind -x '"\C-h": _rehash_search'        # Ctrl+H for global search
  bind -x '"\C-j": _rehash_search_local'  # Ctrl+J for local search
'';

programs.zsh.initExtra = ''
  source ${rehash}/shell/rehash.zsh
  
  # Override default key bindings  
  bindkey '^H' _rehash_search_widget        # Ctrl+H for global search
  bindkey '^J' _rehash_search_local_widget  # Ctrl+J for local search
'';
```

### Environment Variables

Configure rehash behavior with environment variables:

```nix
home-manager.users.yourusername = {
  home.sessionVariables = {
    # Set custom history location (optional)
    REHASH_HISTORY_FILE = "$HOME/.config/rehash/history.jsonl";
    
    # Enable debug logging (optional)
    REHASH_DEBUG = "1";
  };
};
```

### System-Wide Installation

To install rehash system-wide for all users:

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ rehash ];
  
  # Add shell integration to system-wide shell configuration
  programs.bash.interactiveShellInit = ''
    if command -v rehash &> /dev/null; then
      source ${rehash}/shell/rehash.bash
    fi
  '';
  
  programs.zsh.interactiveShellInit = ''
    if command -v rehash &> /dev/null; then
      source ${rehash}/shell/rehash.zsh
    fi
  '';
}
```

## Key Bindings Reference

Once configured, these key bindings will be available:

| Key Binding | Scope | Description |
|-------------|-------|-------------|
| `Ctrl+R` | Global | Search all history across directories and sessions |
| `Ctrl+T` | Local | Search current directory history across sessions |
| `Alt+R` | Session | Search current session history across directories |

## Interactive Controls

Within the rehash interface:

| Key | Action |
|-----|--------|
| `F1` | Switch to Global scope |
| `F2` | Switch to Session scope |
| `F3` | Switch to Local scope |
| `Tab` | Cycle through scopes |
| `↑/↓` | Navigate results |
| `Enter` | Select command |
| `Esc/Ctrl+C` | Exit |

## Usage Workflow

1. **Automatic capture**: Commands are automatically saved as you type them
2. **Prefix search**: Type partial command (e.g., `nixos-rebuild`), press `Ctrl+R`
3. **Fuzzy search**: Continue typing to filter results, or navigate with arrow keys
4. **Scope switching**: Use `F1-F3` or `Tab` to change search scope
5. **Selection**: Press `Enter` to replace your command line with the selected command

## Troubleshooting

### Rehash not found
```bash
# Check if rehash is in PATH
which rehash

# Check if shell integration is loaded
type _rehash_search
```

### Key bindings not working
```bash
# For bash, check current bindings
bind -P | grep rehash

# For zsh, check widget registration
zle -la | grep rehash
```

### History not persisting
```bash
# Check history file location
rehash stats

# Verify write permissions
ls -la ~/.local/share/rehash/
```

## Performance Considerations

- Rehash is designed to be lightweight and fast
- History is stored in JSON Lines format for efficient parsing
- Automatic compaction prevents history files from growing too large
- Session IDs enable efficient scope filtering

## Migration from Other Tools

### From Atuin
1. Export your Atuin history (if desired)
2. Configure rehash as shown above
3. Disable Atuin shell integration
4. Import history using `rehash add` commands (if needed)

### From Standard Shell History
Rehash works alongside standard shell history. Your existing `.bash_history` or `.zsh_history` files remain unchanged. Rehash maintains its own enhanced history database.

## Summary

This integration provides:
- ✅ Automatic command capture and storage
- ✅ Fuzzy search with three different scopes
- ✅ Prefix-based incremental search
- ✅ Cross-shell session persistence
- ✅ Native NixOS package management
- ✅ Customizable key bindings
- ✅ Lightweight and fast performance

Choose the method that best fits your NixOS configuration style and enjoy enhanced shell history management!