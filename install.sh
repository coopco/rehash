#!/bin/bash
# Install script for rehash

set -e

INSTALL_DIR="$HOME/.local/bin"
SHELL_DIR="$HOME/.local/share/rehash/shell"

echo "Installing rehash..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$SHELL_DIR"

# Build if not already built
if [[ ! -f target/release/rehash ]]; then
    echo "Building rehash..."
    if command -v nix &> /dev/null; then
        nix develop --command cargo build --release
    else
        cargo build --release
    fi
fi

# Install binary
cp target/release/rehash "$INSTALL_DIR/"
echo "✓ Installed binary to $INSTALL_DIR/rehash"

# Install shell integrations
cp shell/rehash.bash "$SHELL_DIR/"
cp shell/rehash.zsh "$SHELL_DIR/"
echo "✓ Installed shell integrations to $SHELL_DIR/"

echo ""
echo "Installation completed!"
echo ""
echo "To enable rehash in your shell, add one of the following to your shell config:"
echo ""
echo "For Bash (~/.bashrc):"
echo "  source $SHELL_DIR/rehash.bash"
echo ""
echo "For Zsh (~/.zshrc):"
echo "  source $SHELL_DIR/rehash.zsh"
echo ""
echo "After adding the source line, restart your shell or run 'source ~/.bashrc' (or ~/.zshrc)"
echo ""
echo "Key bindings:"
echo "  Ctrl+R: Global fuzzy search"
echo "  Ctrl+T: Directory-local fuzzy search"