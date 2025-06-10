#!/bin/bash
# Generate test data for rehash with commands across different directories and sessions

set -e

REHASH_BIN="../target/release/rehash"
DATABASE_PATH="./sample_history.jsonl"

# Ensure rehash is built
if [[ ! -f "$REHASH_BIN" ]]; then
    echo "Building rehash..."
    cd .. && nix develop --command cargo build --release && cd examples
fi

echo "Generating test data for rehash..."
echo "Database will be created at: $DATABASE_PATH"

# Clean up any existing database
rm -f "$DATABASE_PATH"

# Current directory commands
echo "Adding commands in current directory..."
$REHASH_BIN --database "$DATABASE_PATH" add "git status" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "cargo build --release" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "ls -la" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "git log --oneline" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "cargo test" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "git diff" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "cargo clippy" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "git add ." --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "vim src/main.rs" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "find . -name '*.rs'" --exit-code 0

# Create subdirectories for testing
echo "Creating test subdirectories..."
mkdir -p test_data/{src,docs,scripts}

# Commands in src subdirectory
echo "Adding commands in src/ subdirectory..."
cd test_data/src
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "rustc --version" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "cargo fmt" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "grep -r 'TODO' ." --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "wc -l *.rs" --exit-code 1
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "git blame main.rs" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "vim lib.rs" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "ls -la *.rs" --exit-code 0

# Commands in docs subdirectory
echo "Adding commands in docs/ subdirectory..."
cd ../docs
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "mdbook build" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "pandoc README.md -o readme.pdf" --exit-code 1
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "spell check *.md" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "find . -name '*.md'" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "grep -i 'FIXME' *.md" --exit-code 1
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "vim architecture.md" --exit-code 0

# Commands in scripts subdirectory
echo "Adding commands in scripts/ subdirectory..."
cd ../scripts
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "chmod +x deploy.sh" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "./deploy.sh --dry-run" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "shellcheck *.sh" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "bash -n setup.sh" --exit-code 0
../../$REHASH_BIN --database "../../$DATABASE_PATH" add "find . -name '*.sh' -exec chmod +x {} \\;" --exit-code 0

# Back to root and add more commands
cd ../../
echo "Adding more commands in root directory..."
$REHASH_BIN --database "$DATABASE_PATH" add "docker build -t myapp ." --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "docker run --rm myapp" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "npm install" --exit-code 1
$REHASH_BIN --database "$DATABASE_PATH" add "python3 -m venv venv" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "source venv/bin/activate" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "pip install requests" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "pytest tests/" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "black *.py" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "flake8 src/" --exit-code 1
$REHASH_BIN --database "$DATABASE_PATH" add "make clean" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "make install" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "htop" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "ps aux | grep rust" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "df -h" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "free -m" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "journalctl -f" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "systemctl status nginx" --exit-code 1
$REHASH_BIN --database "$DATABASE_PATH" add "curl -s https://api.github.com/user" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "wget https://example.com/file.tar.gz" --exit-code 0
$REHASH_BIN --database "$DATABASE_PATH" add "tar -xzf file.tar.gz" --exit-code 0

# Simulate commands from different "sessions" by manually creating entries
# with different session IDs (this simulates what would happen across shell sessions)
echo "Simulating commands from different sessions (manual JSON entries)..."

# Create some entries with fake session IDs to simulate cross-session scenario
# Now using the custom database path
mkdir -p "$(dirname "$DATABASE_PATH")"

# Add entries with different session IDs and varied timestamps
cat >> "$DATABASE_PATH" << 'EOF'
{"command":"nix develop","timestamp":"2024-12-01T10:30:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"11111_1705316200"}
{"command":"cargo run","timestamp":"2024-12-01T10:31:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"11111_1705316200"}
{"command":"git commit -m 'fix bug'","timestamp":"2024-12-01T10:32:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"11111_1705316200"}
{"command":"cd test_data/src","timestamp":"2024-12-01T10:33:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"11111_1705316200"}
{"command":"rustfmt *.rs","timestamp":"2024-12-01T10:34:00Z","directory":"/home/connor/Projects/rehash/test_data/src","exit_code":0,"session_id":"11111_1705316200"}
{"command":"ssh user@server","timestamp":"2024-12-05T11:00:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"22222_1705318800"}
{"command":"tmux new-session -d","timestamp":"2024-12-05T11:01:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"22222_1705318800"}
{"command":"docker ps -a","timestamp":"2024-12-10T14:15:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"33333_1705320000"}
{"command":"kubectl get pods","timestamp":"2024-12-15T09:20:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"33333_1705320000"}
{"command":"vim README.md","timestamp":"2025-01-01T16:45:00Z","directory":"/home/connor/Projects/rehash","exit_code":0,"session_id":"44444_1705400000"}
EOF

echo ""
echo "✅ Test data generated successfully!"
echo ""
echo "Test the different scopes with the sample database:"
echo "  $REHASH_BIN --database '$DATABASE_PATH' search 'git' --scope global    # All git commands"
echo "  $REHASH_BIN --database '$DATABASE_PATH' search 'git' --scope local     # Git commands in current dir"
echo "  $REHASH_BIN --database '$DATABASE_PATH' search 'cargo' --scope session # Cargo commands in current session"
echo ""
echo "Interactive testing:"
echo "  $REHASH_BIN --database '$DATABASE_PATH' interactive                     # Use F1/F2/F3 or Tab to switch scopes"
echo ""
echo "Statistics:"
echo "  $REHASH_BIN --database '$DATABASE_PATH' stats"
echo ""
echo "Directory structure created:"
echo "  test_data/"
echo "  ├── src/     (Rust development commands)"
echo "  ├── docs/    (Documentation commands)"  
echo "  └── scripts/ (Shell script commands)"