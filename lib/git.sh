# git.sh - Git helper functions

# Get the root of the current git repo
git_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get the main worktree (first one listed, typically the original clone)
git_main_worktree() {
    git worktree list --porcelain | grep '^worktree ' | head -1 | cut -d' ' -f2
}

# Get all worktrees except the main one
git_secondary_worktrees() {
    git worktree list --porcelain | grep '^worktree ' | tail -n +2 | cut -d' ' -f2
}

# Get all worktrees
git_all_worktrees() {
    git worktree list --porcelain | grep '^worktree ' | cut -d' ' -f2
}

# Get remote URL
git_remote_url() {
    git remote get-url origin 2>/dev/null || echo ""
}
