#!/usr/bin/env bash
# Install worktree-helper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/worktree-helper"

# Parse arguments
dry_run=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n) dry_run=true; shift ;;
        --help|-h)
            echo "Usage: ./install.sh [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n  Show what would be done without doing it"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if $dry_run; then
    echo "[dry-run] Would install worktree-helper..."
else
    echo "Installing worktree-helper..."
fi

# Create install directory if needed
if $dry_run; then
    echo "[dry-run] Would create directory: $INSTALL_DIR"
else
    mkdir -p "$INSTALL_DIR"
fi

# Create symlink
if $dry_run; then
    if [[ -L "$INSTALL_DIR/worktree-helper" ]]; then
        echo "[dry-run] Would remove existing symlink: $INSTALL_DIR/worktree-helper"
    fi
    echo "[dry-run] Would symlink: $SCRIPT_DIR/worktree-helper → $INSTALL_DIR/worktree-helper"
else
    if [[ -L "$INSTALL_DIR/worktree-helper" ]]; then
        rm "$INSTALL_DIR/worktree-helper"
    fi
    ln -s "$SCRIPT_DIR/worktree-helper" "$INSTALL_DIR/worktree-helper"
    echo "✓ Symlinked to $INSTALL_DIR/worktree-helper"
fi

# Create config directory
if $dry_run; then
    echo "[dry-run] Would create directory: $CONFIG_DIR/projects"
else
    mkdir -p "$CONFIG_DIR/projects"
    echo "✓ Created config directory: $CONFIG_DIR"
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠ Warning: $INSTALL_DIR is not in your PATH"
    echo "  Add this to your shell config (~/.bashrc or ~/.zshrc):"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
if $dry_run; then
    echo "[dry-run] Installation would be complete!"
else
    echo "Installation complete!"
fi
echo ""
echo "Next steps:"
echo "  1. Initialize a project:  worktree-helper init <project-name>"
echo "  2. Add files to sync:     worktree-helper add-file justfile"
echo "  3. Capture templates:     worktree-helper capture-templates"
echo "  4. Install git alias:     worktree-helper install-alias"
