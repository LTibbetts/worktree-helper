# capture.sh - Template capture logic

cmd_capture_templates() {
    require_jq
    require_rsync
    local project="" dry_run=false verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper capture-templates [options]

Copy files from source repo to templates directory.
Files are determined by the 'files' and 'patterns' in the project config.

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --dry-run         Show what would be copied without copying
  --verbose, -v     Show individual files when capturing folders
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper capture-templates
  worktree-helper capture-templates --dry-run
  worktree-helper capture-templates --verbose
  worktree-helper capture-templates --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --dry-run) dry_run=true; shift ;;
            --verbose|-v) verbose=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *) die "Unexpected argument: $1" ;;
        esac
    done

    # Auto-detect project if not provided
    if [[ -z "$project" ]]; then
        project="$(detect_project)"
        log_info "Auto-detected project: $project"
    fi

    project_exists "$project" || die "Project '$project' not found. Run: worktree-helper init $project"

    local config_file source_path templates_dir
    config_file="$(project_config_path "$project")"
    source_path="$(project_config_get "$project" '.project.source_path')"
    templates_dir="$(project_templates_path "$project")"

    [[ -d "$source_path" ]] || die "Source path does not exist: $source_path"

    # Build exclude list from config
    local -a excludes=()
    while IFS= read -r exclude; do
        [[ -n "$exclude" ]] && excludes+=("$exclude")
    done < <(jq -r '.excludes[]? // empty' "$config_file")

    # Function to check if path should be excluded
    is_excluded() {
        local path="$1"
        for exclude in "${excludes[@]}"; do
            if [[ "$path" == *"/$exclude/"* || "$path" == "$exclude/"* || "$path" == *"/$exclude" ]]; then
                return 0
            fi
        done
        return 1
    }

    local count=0

    # Process explicit files
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        local src="$source_path/$file_path"
        local dst="$templates_dir/$file_path"

        if [[ ! -f "$src" ]]; then
            log_warn "File not found: $src"
            continue
        fi

        if $dry_run; then
            log_info "[dry-run] Would copy: $src → $dst"
        else
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            log_success "Copied: $file_path"
        fi
        ((count++)) || true || true
    done < <(jq -r '.files[].path // empty' "$config_file")

    # Process folders
    while IFS= read -r folder_entry; do
        [[ -z "$folder_entry" ]] && continue
        local folder_path follow_symlinks
        folder_path="$(echo "$folder_entry" | jq -r '.path')"
        follow_symlinks="$(echo "$folder_entry" | jq -r '.follow_symlinks // false')"

        local folder_src="$source_path/$folder_path"
        if [[ ! -d "$folder_src" ]]; then
            log_warn "Folder not found: $folder_src"
            continue
        fi

        local folder_dst="$templates_dir/$folder_path"

        # Build rsync exclude args from config excludes
        local -a rsync_excludes=()
        for exclude in "${excludes[@]}"; do
            rsync_excludes+=(--exclude="$exclude")
        done

        # Count files first (for reporting)
        local -a find_args=()
        if [[ "$follow_symlinks" == "true" ]]; then
            find_args+=(-L)
        fi
        find_args+=("$folder_src" -type f)

        # Count non-excluded files
        local folder_count=0
        while IFS= read -r src_file; do
            [[ -z "$src_file" ]] && continue
            local rel_path="${src_file#$source_path/}"
            if ! is_excluded "$rel_path"; then
                ((folder_count++)) || true
                if $verbose && $dry_run; then
                    log_info "[dry-run] Would copy: $rel_path"
                fi
            fi
        done < <(find "${find_args[@]}")

        if $dry_run; then
            log_info "[dry-run] Would copy folder: $folder_path/ ($folder_count files)"
        else
            # Use rsync for efficient folder copy with excludes
            mkdir -p "$folder_dst"
            local -a rsync_args=(-a --delete "${rsync_excludes[@]}")
            if [[ "$follow_symlinks" == "true" ]]; then
                rsync_args+=(-L)
            fi
            rsync "${rsync_args[@]}" "$folder_src/" "$folder_dst/"

            if $verbose; then
                # Show individual files that were copied
                while IFS= read -r src_file; do
                    [[ -z "$src_file" ]] && continue
                    local rel_path="${src_file#$source_path/}"
                    if ! is_excluded "$rel_path"; then
                        log_success "Copied: $rel_path"
                    fi
                done < <(find "${find_args[@]}")
            fi
            log_success "Copied folder: $folder_path/ ($folder_count files)"
        fi
        ((count += folder_count)) || true
    done < <(jq -c '.folders[]? // empty' "$config_file")

    # Process glob patterns
    while IFS= read -r glob_pattern; do
        [[ -z "$glob_pattern" ]] && continue

        # Use bash globstar to find matching files (process substitution to avoid subshell)
        while IFS= read -r rel_path; do
            [[ -z "$rel_path" ]] && continue

            # Check excludes
            if is_excluded "$rel_path"; then
                continue
            fi

            local src="$source_path/$rel_path"
            local dst="$templates_dir/$rel_path"

            if $dry_run; then
                log_info "[dry-run] Would copy: $src → $dst"
            else
                mkdir -p "$(dirname "$dst")"
                cp "$src" "$dst"
                log_success "Copied: $rel_path"
            fi
            ((count++)) || true
        done < <(cd "$source_path" && shopt -s globstar nullglob && for f in $glob_pattern; do [[ -f "$f" ]] && echo "$f"; done)
    done < <(jq -r '.patterns[].glob // empty' "$config_file")

    if $dry_run; then
        log_info "[dry-run] Would capture $count file(s)"
    else
        log_info "Captured $count file(s) to $templates_dir"
    fi
}
