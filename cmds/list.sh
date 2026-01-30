# list.sh - List and install-alias commands

cmd_list() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper list

List all configured projects.

${BOLD}Options:${RESET}
  --help, -h  Show this help message"
                return 0 ;;
            -*) die "Unknown option: $1" ;;
            *) die "Unexpected argument: $1" ;;
        esac
    done

    echo -e "${BOLD}Configured projects:${RESET}"

    local found=false
    for config_file in "$CONFIG_DIR/projects"/*/config.json; do
        [[ -f "$config_file" ]] || continue
        found=true
        local name source_path
        name="$(jq -r '.project.name' "$config_file")"
        source_path="$(jq -r '.project.source_path' "$config_file")"
        echo -e "  ${BOLD}$name${RESET}"
        echo "    Source: $source_path"
        echo "    Config: $config_file"
    done

    if ! $found; then
        echo "  (none)"
        echo ""
        echo "Run 'worktree-helper init <project>' to create a project."
    fi
}

cmd_install_alias() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper install-alias

Add 'git wt-add' alias to ~/.gitconfig for automatic sync on worktree creation.

${BOLD}Options:${RESET}
  --help, -h  Show this help message

The alias wraps 'git worktree add' and automatically runs 'worktree-helper sync'
on the new worktree.

${BOLD}Usage after install:${RESET}
  git wt-add <path> <branch>
  git wt-add --checkout ~/worktrees/feature feature-branch"
                return 0 ;;
            -*) die "Unknown option: $1" ;;
            *) die "Unexpected argument: $1" ;;
        esac
    done

    local gitconfig="$HOME/.gitconfig"

    # Check if alias already exists
    if git config --global --get alias.wt-add &>/dev/null; then
        log_warn "Git alias 'wt-add' already exists"
        local current
        current="$(git config --global --get alias.wt-add)"
        echo "  Current: $current"
        read -rp "Overwrite? [y/N] " choice
        [[ "$choice" =~ ^[Yy]$ ]] || { log_info "Aborted."; return 0; }
    fi

    # Add alias
    # Find the path argument (first non-flag argument) from git worktree add args
    git config --global alias.wt-add '!f() { git worktree add "$@"; local path=""; for arg in "$@"; do case "$arg" in -*) ;; *) path="$arg"; break;; esac; done; worktree-helper sync "$(realpath "$path")"; }; f'

    log_success "Added git alias 'wt-add'"
    log_info "Usage: git wt-add <path> <branch>"
}
