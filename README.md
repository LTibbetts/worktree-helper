# worktree-helper

Sync gitignored personal files (like `CLAUDE.local.md`, `justfile`) to git worktrees.

## Problem

When you create a new git worktree, gitignored files aren't copied over. This tool maintains a set of template files and syncs them to new worktrees automatically.

## Installation

```bash
./install.sh
```

This will:
- Symlink `worktree-helper` to `~/.local/bin/`
- Create the config directory at `~/.config/worktree-helper/`

## Quick Start

```bash
# 1. Initialize a project (run from any worktree)
worktree-helper init myproject

# 2. Add files to sync
worktree-helper add-file justfile
worktree-helper add-files "**/CLAUDE.local.md"

# 3. Capture current files as templates
worktree-helper capture-templates

# 4. Install git alias for automatic sync
worktree-helper install-alias

# 5. Create new worktrees with auto-sync
git wt-add ../new-feature feature-branch
```

## Commands

| Command | Description |
|---------|-------------|
| `init <project>` | Initialize config (auto-detects main worktree) |
| `sync [path]` | Sync files to worktree(s) |
| `status` | Show sync status for all worktrees |
| `add-file <path>` | Add explicit file to sync |
| `add-files <glob>` | Add glob pattern (e.g., `**/CLAUDE.local.md`) |
| `capture-templates` | Copy files from source repo to templates |
| `install-alias` | Add `git wt-add` alias to ~/.gitconfig |
| `list` | List configured projects |

## Options

| Option | Description |
|--------|-------------|
| `--project <name>` | Specify project (default: auto-detect) |
| `--source <path>` | Specify source path for init |
| `--all` | Sync to all worktrees |
| `--force` | Overwrite without prompting |
| `--dry-run` | Show what would be done |

## Configuration

Config files are stored in `~/.config/worktree-helper/`:

```
~/.config/worktree-helper/
└── projects/
    └── myproject/
        ├── config.json      # Sync rules
        └── templates/       # Template files
            ├── justfile
            └── CLAUDE.local.md
```

### Project Config

```json
{
  "project": {
    "name": "myproject",
    "source_path": "/path/to/main/repo",
    "match": {
      "remote_patterns": ["github.com/org/repo"],
      "root_name": "repo"
    }
  },
  "files": [
    { "path": "justfile" }
  ],
  "patterns": [
    { "glob": "**/CLAUDE.local.md" }
  ]
}
```

- `files`: Explicit paths copied to the same location
- `patterns`: Glob patterns expanded at capture-time, preserving relative paths

## Workflow

### Initial Setup (once per project)

```bash
cd /path/to/your/repo
worktree-helper init myproject
worktree-helper add-file justfile
worktree-helper add-files "**/CLAUDE.local.md"
worktree-helper capture-templates
worktree-helper install-alias
```

### Creating New Worktrees

```bash
# Instead of: git worktree add ../feature feature-branch
git wt-add ../feature feature-branch
# Files are automatically synced!
```

### Syncing Existing Worktrees

```bash
# Sync current worktree
worktree-helper sync

# Sync all worktrees
worktree-helper sync --all
```

### Updating Templates

```bash
# After modifying files in your main repo
worktree-helper capture-templates

# Sync updates to all worktrees
worktree-helper sync --all
```

### Checking Status

```bash
worktree-helper status
```

Output:
```
Project: myproject
Source: /home/user/repo
Templates: /home/user/.config/worktree-helper/projects/myproject/templates

Template files: 2
  - justfile
  - CLAUDE.local.md

Worktrees:
  /home/user/repo
    [synced] justfile
    [synced] CLAUDE.local.md
  /home/user/worktrees/feature
    [missing] justfile
    [missing] CLAUDE.local.md
```

## Conflict Handling

When syncing, if a file already exists and differs from the template:

```
[conflict] justfile
  [o]verwrite | [s]kip | [d]iff | [b]ackup+overwrite | [O]verwrite all | [S]kip all:
```

Use `--force` to overwrite all without prompting.

## Dependencies

- Bash 4+
- jq
- git

## License

MIT
