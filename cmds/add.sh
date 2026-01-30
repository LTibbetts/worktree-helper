# add.sh - File and folder adding commands

cmd_add_file() {
    require_jq
    local file_path="" project="" dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper add-file <path> [options]

Add an explicit file path to sync.

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --dry-run         Show what would be added without modifying config
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper add-file justfile
  worktree-helper add-file justfile --dry-run
  worktree-helper add-file .claude/settings.local.json --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --dry-run) dry_run=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *)
                if [[ -z "$file_path" ]]; then
                    file_path="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done

    [[ -n "$file_path" ]] || die "File path required. Usage: worktree-helper add-file <path>"

    # Auto-detect project if not provided
    if [[ -z "$project" ]]; then
        project="$(detect_project)"
        log_info "Auto-detected project: $project"
    fi

    project_exists "$project" || die "Project '$project' not found. Run: worktree-helper init $project"

    local config_file
    config_file="$(project_config_path "$project")"

    # Check if file already exists in config
    if jq -e ".files[] | select(.path == \"$file_path\")" "$config_file" &>/dev/null; then
        log_warn "File '$file_path' already in config"
        return 0
    fi

    if $dry_run; then
        log_info "[dry-run] Would add file: $file_path"
        return 0
    fi

    # Add file to config
    local tmp_file
    tmp_file="$(mktemp)"
    jq ".files += [{\"path\": \"$file_path\"}]" "$config_file" > "$tmp_file"
    mv "$tmp_file" "$config_file"

    log_success "Added file: $file_path"
}

cmd_add_folder() {
    require_jq
    local folder_path="" project="" follow_symlinks=false dry_run=false
    local -a folder_excludes=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper add-folder <path> [options]

Add a folder to sync (recursively captures all files).

${BOLD}Options:${RESET}
  --project <name>    Project name (default: auto-detect)
  --follow-symlinks   Follow symbolic links when capturing
  --exclude <path>    Exclude file/folder (relative to project root, can be repeated)
  --dry-run           Show what would be added without modifying config
  --help, -h          Show this help message

${BOLD}Examples:${RESET}
  worktree-helper add-folder .claude
  worktree-helper add-folder .claude --exclude .claude/settings.local.json
  worktree-helper add-folder scripts/local --follow-symlinks
  worktree-helper add-folder .claude --dry-run
  worktree-helper add-folder .claude --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --follow-symlinks) follow_symlinks=true; shift ;;
            --exclude) folder_excludes+=("$2"); shift 2 ;;
            --exclude=*) folder_excludes+=("${1#*=}"); shift ;;
            --dry-run) dry_run=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *)
                if [[ -z "$folder_path" ]]; then
                    folder_path="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done

    [[ -n "$folder_path" ]] || die "Folder path required. Usage: worktree-helper add-folder <path>"

    # Auto-detect project if not provided
    if [[ -z "$project" ]]; then
        project="$(detect_project)"
        log_info "Auto-detected project: $project"
    fi

    project_exists "$project" || die "Project '$project' not found. Run: worktree-helper init $project"

    local config_file
    config_file="$(project_config_path "$project")"

    # Check if folder already exists in config
    if jq -e ".folders[]? | select(.path == \"$folder_path\")" "$config_file" &>/dev/null; then
        log_warn "Folder '$folder_path' already in config"
        return 0
    fi

    # Build folder entry JSON
    local folder_json="{\"path\": \"$folder_path\""
    if $follow_symlinks; then
        folder_json+=", \"follow_symlinks\": true"
    fi
    if [[ ${#folder_excludes[@]} -gt 0 ]]; then
        # Build JSON array of excludes
        local excludes_json="["
        local first=true
        for exclude in "${folder_excludes[@]}"; do
            if $first; then
                first=false
            else
                excludes_json+=","
            fi
            excludes_json+="\"$exclude\""
        done
        excludes_json+="]"
        folder_json+=", \"excludes\": $excludes_json"
    fi
    folder_json+="}"

    if $dry_run; then
        log_info "[dry-run] Would add folder: $folder_path"
        if $follow_symlinks; then
            log_info "[dry-run]   follow_symlinks: true"
        fi
        for exclude in "${folder_excludes[@]}"; do
            log_info "[dry-run]   exclude: $exclude"
        done
        return 0
    fi

    # Add folder to config
    local tmp_file
    tmp_file="$(mktemp)"
    jq ".folders = (.folders // []) + [$folder_json]" "$config_file" > "$tmp_file"
    mv "$tmp_file" "$config_file"

    local msg="Added folder: $folder_path"
    if $follow_symlinks; then
        msg+=" (following symlinks)"
    fi
    if [[ ${#folder_excludes[@]} -gt 0 ]]; then
        msg+=" (${#folder_excludes[@]} excludes)"
    fi
    log_success "$msg"
}

cmd_add_files() {
    require_jq
    local glob_pattern="" project="" dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper add-files <glob> [options]

Add a glob pattern to sync (e.g., **/CLAUDE.local.md).
Remember to quote the pattern to prevent shell expansion.

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --dry-run         Show what would be added without modifying config
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper add-files \"**/CLAUDE.local.md\"
  worktree-helper add-files \"**/CLAUDE.local.md\" --dry-run
  worktree-helper add-files \"**/.envrc\" --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --dry-run) dry_run=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *)
                if [[ -z "$glob_pattern" ]]; then
                    glob_pattern="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done

    [[ -n "$glob_pattern" ]] || die "Glob pattern required. Usage: worktree-helper add-files <glob>"

    # Auto-detect project if not provided
    if [[ -z "$project" ]]; then
        project="$(detect_project)"
        log_info "Auto-detected project: $project"
    fi

    project_exists "$project" || die "Project '$project' not found. Run: worktree-helper init $project"

    local config_file
    config_file="$(project_config_path "$project")"

    # Check if pattern already exists in config
    if jq -e ".patterns[] | select(.glob == \"$glob_pattern\")" "$config_file" &>/dev/null; then
        log_warn "Pattern '$glob_pattern' already in config"
        return 0
    fi

    if $dry_run; then
        log_info "[dry-run] Would add pattern: $glob_pattern"
        return 0
    fi

    # Add pattern to config
    local tmp_file
    tmp_file="$(mktemp)"
    jq ".patterns += [{\"glob\": \"$glob_pattern\"}]" "$config_file" > "$tmp_file"
    mv "$tmp_file" "$config_file"

    log_success "Added pattern: $glob_pattern"
}
