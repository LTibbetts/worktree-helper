# init.sh - Project initialization command

cmd_init() {
    local project="" source_path=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                cat <<EOF
Usage: worktree-helper init <project> [options]

Initialize a new project configuration.

Options:
  --source <path>   Source repository path (default: auto-detect main worktree)
  --help, -h        Show this help message

Examples:
  worktree-helper init myproject
  worktree-helper init myproject --source /path/to/repo
EOF
                return 0 ;;
            --source) source_path="$2"; shift 2 ;;
            --source=*) source_path="${1#*=}"; shift ;;
            -*) die "Unknown option: $1" ;;
            *)
                if [[ -z "$project" ]]; then
                    project="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done

    [[ -n "$project" ]] || die "Project name required. Usage: worktree-helper init <project>"

    # Auto-detect source path if not provided
    if [[ -z "$source_path" ]]; then
        source_path="$(git_main_worktree)" || die "Could not detect main worktree. Use --source to specify."
        log_info "Auto-detected main worktree: $source_path"
    fi

    [[ -d "$source_path" ]] || die "Source path does not exist: $source_path"

    local config_file templates_dir
    config_file="$(project_config_path "$project")"
    templates_dir="$(project_templates_path "$project")"

    if [[ -f "$config_file" ]]; then
        log_warn "Project '$project' already exists at $config_file"
        read -rp "Overwrite? [y/N] " choice
        [[ "$choice" =~ ^[Yy]$ ]] || { log_info "Aborted."; return 0; }
    fi

    # Create directories
    mkdir -p "$(dirname "$config_file")" "$templates_dir"

    # Detect remote URL for match patterns
    local remote_url root_name
    remote_url="$(cd "$source_path" && git_remote_url)"
    root_name="$(basename "$source_path")"

    # Create config with sensible default excludes
    cat > "$config_file" <<EOF
{
  "project": {
    "name": "$project",
    "source_path": "$source_path",
    "match": {
      "remote_patterns": [],
      "root_name": "$root_name"
    }
  },
  "files": [],
  "patterns": [],
  "excludes": [
    ".git",
    "dist-newstyle",
    "node_modules",
    ".stack-work",
    ".cabal",
    "target",
    "build",
    ".cache",
    "__pycache__",
    ".venv",
    "venv"
  ]
}
EOF

    log_success "Created project config: $config_file"
    log_info "Templates directory: $templates_dir"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Add files:     worktree-helper add-file justfile --project $project"
    log_info "  2. Add patterns:  worktree-helper add-files \"**/CLAUDE.local.md\" --project $project"
    log_info "  3. Capture:       worktree-helper capture-templates --project $project"
}
