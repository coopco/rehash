# Rehash Examples

This directory contains examples and test data for demonstrating rehash functionality.

## Files

- **`generate_test_data.sh`**: Script that creates a sample history database
- **`sample_history.jsonl`**: Generated sample database (created by the script)

## Usage

### Generate Sample Data

```bash
cd examples
./generate_test_data.sh
```

This creates `sample_history.jsonl` with diverse command history including:
- Git commands (status, log, diff, commit, etc.)
- Cargo/Rust commands (build, test, clippy, fmt)
- System commands (docker, npm, python, make)
- File operations (ls, find, grep, vim)
- Commands from different directories and sessions

### Test with Sample Data

Once generated, you can test rehash features with the sample database:

```bash
# Search commands
../target/release/rehash --database ./sample_history.jsonl search "git"

# Interactive mode
../target/release/rehash --database ./sample_history.jsonl interactive

# Statistics
../target/release/rehash --database ./sample_history.jsonl stats

# Scope-specific searches
../target/release/rehash --database ./sample_history.jsonl search "cargo" --scope session
../target/release/rehash --database ./sample_history.jsonl search "docker" --scope local
```

### Interactive Features to Test

1. **Scope Switching**: Use F1/F2/F3 or Tab to switch between Global/Session/Local
2. **Fuzzy Search**: Type partial commands to see fuzzy matching
3. **Navigation**: Use ↑/↓ arrows with proactive scrolling
4. **Prefix Search**: Test with `--prefix` parameter

## Sample Data Structure

The generated database includes:

- **50+ commands** across different categories
- **Multiple directories**: root, src/, docs/, scripts/
- **Different sessions**: Simulated with various session IDs
- **Realistic timestamps**: Mix of recent and historical entries
- **Various exit codes**: Both successful (0) and failed commands

This provides a comprehensive dataset for testing all rehash features including scope filtering, fuzzy search, and session management.