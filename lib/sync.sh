# sync.sh - Sync logic with conflict handling

cmd_sync() {
    require_jq
    local target_path="" project="" sync_all=false force=false dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper sync [worktree-path] [options]

Sync template files to worktree(s).

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --all             Sync to all worktrees
  --force           Overwrite without prompting
  --dry-run         Show what would be synced without syncing
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper sync
  worktree-helper sync --all
  worktree-helper sync /path/to/worktree
  worktree-helper sync --all --force"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --all) sync_all=true; shift ;;
            --force) force=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *)
                if [[ -z "$target_path" ]]; then
                    target_path="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift ;;
        esac
    done

    # Determine target worktrees first (needed for project detection)
    local -a targets=()
    if $sync_all; then
        while IFS= read -r wt; do
            targets+=("$wt")
        done < <(git_all_worktrees)
    elif [[ -n "$target_path" ]]; then
        targets+=("$target_path")
    else
        targets+=("$(git_root)")
    fi

    # Auto-detect project if not provided (use first target for detection)
    if [[ -z "$project" ]]; then
        project="$(detect_project "${targets[0]}")"
        log_info "Auto-detected project: $project"
    fi

    project_exists "$project" || die "Project '$project' not found. Run: worktree-helper init $project"

    local templates_dir
    templates_dir="$(project_templates_path "$project")"

    [[ -d "$templates_dir" ]] || die "Templates directory does not exist: $templates_dir (run capture-templates first)"

    local overwrite_all=false skip_all=false

    for target in "${targets[@]}"; do
        log_info "Syncing to ${BOLD}$target${RESET}..."

        # Sync all files from templates directory
        while IFS= read -r src_file; do
            [[ -z "$src_file" ]] && continue
            local rel_path="${src_file#$templates_dir/}"
            local dst_file="$target/$rel_path"

            if [[ -f "$dst_file" ]]; then
                # File exists - check if different
                if cmp -s "$src_file" "$dst_file"; then
                    echo -e "  ${BLUE}[same]${RESET} $rel_path"
                    continue
                fi

                if $dry_run; then
                    echo -e "  ${YELLOW}[dry-run]${RESET} Would overwrite: $rel_path"
                elif $force || $overwrite_all; then
                    cp "$src_file" "$dst_file"
                    echo -e "  ${YELLOW}[overwritten]${RESET} $rel_path"
                elif $skip_all; then
                    echo -e "  ${BLUE}[skipped]${RESET} $rel_path"
                else
                    # Interactive prompt (read from /dev/tty since stdin is used by the loop)
                    echo -e "  ${YELLOW}[conflict]${RESET} $rel_path"
                    local choice=""
                    while true; do
                        if ! choice=$(bash -c 'read -rp "    [o]verwrite | [s]kip | [d]iff | [b]ackup+overwrite | [O]verwrite all | [S]kip all: " c </dev/tty && echo "$c"' 2>/dev/null); then
                            # No TTY available, skip by default
                            echo "    Skipped (no TTY for interactive prompt, use --force to overwrite)"
                            break
                        fi
                        case "$choice" in
                            o)
                                if $dry_run; then
                                    echo "    [dry-run] Would overwrite"
                                else
                                    cp "$src_file" "$dst_file"
                                    echo "    Overwritten"
                                fi
                                break ;;
                            s)
                                echo "    Skipped"
                                break ;;
                            d)
                                diff --color=auto "$dst_file" "$src_file" || true
                                ;;
                            b)
                                if $dry_run; then
                                    echo "    [dry-run] Would backup and overwrite"
                                else
                                    cp "$dst_file" "$dst_file.backup"
                                    cp "$src_file" "$dst_file"
                                    echo "    Backed up to $rel_path.backup and overwritten"
                                fi
                                break ;;
                            O)
                                overwrite_all=true
                                if $dry_run; then
                                    echo "    [dry-run] Would overwrite"
                                else
                                    cp "$src_file" "$dst_file"
                                    echo "    Overwritten"
                                fi
                                break ;;
                            S)
                                skip_all=true
                                echo "    Skipped"
                                break ;;
                            *)
                                echo "    Invalid choice" ;;
                        esac
                    done
                fi
            else
                # New file
                if $dry_run; then
                    echo -e "  ${GREEN}[dry-run]${RESET} Would create: $rel_path"
                else
                    mkdir -p "$(dirname "$dst_file")"
                    cp "$src_file" "$dst_file"
                    echo -e "  ${GREEN}[new]${RESET} $rel_path"
                fi
            fi
        done < <(find "$templates_dir" -type f)
    done

    log_success "Sync complete"
}
