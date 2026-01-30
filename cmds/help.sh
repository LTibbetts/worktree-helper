# help.sh - Help and version commands

cmd_help() {
    echo -e "${BOLD}worktree-helper${RESET} v$VERSION - Sync gitignored files to git worktrees

${BOLD}USAGE:${RESET}
    worktree-helper <command> [options]

${BOLD}COMMANDS:${RESET}
    init <project>          Initialize config for a project (auto-detects main worktree)
    sync [worktree-path]    Sync files to worktree(s)
    status                  Show sync status for all worktrees
    show-templates          Show captured template files (optionally with contents)
    add-file <path>         Add explicit file to sync config
    add-folder <path>       Add folder to sync (recursive)
    add-files <glob>        Add glob pattern (e.g., **/CLAUDE.local.md)
    capture-templates       Copy files from main repo to templates dir
    install-alias           Add git aliases to ~/.gitconfig
    list                    List configured projects
    help                    Show this help message
    version                 Show version

${BOLD}OPTIONS:${RESET}
    --project <name>        Specify project (default: auto-detect)
    --source <path>         Specify source path for init (default: auto-detect)
    --all                   Sync to all worktrees
    --force                 Overwrite without prompting
    --dry-run               Show what would be done without doing it

${BOLD}EXAMPLES:${RESET}
    # Initial setup
    worktree-helper init all
    worktree-helper add-file justfile
    worktree-helper add-files \"**/CLAUDE.local.md\"
    worktree-helper capture-templates

    # Sync to new worktree
    git wt-add ../feature-branch feature-branch

    # Sync to existing worktrees
    worktree-helper sync --all"
}

cmd_version() {
    echo "worktree-helper v$VERSION"
}
