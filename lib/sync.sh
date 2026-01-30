# sync.sh - Sync logic with conflict handling

cmd_sync() {
    require_jq
    local target_path="" project="" sync_all=false force=false dry_run=false verbose=false

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
  --verbose, -v     Show individual files instead of folder summaries
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
            --verbose|-v) verbose=true; shift ;;
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

        # Track stats per top-level folder
        declare -A folder_new folder_same folder_overwritten folder_skipped
        local root_new=0 root_same=0 root_overwritten=0 root_skipped=0

        # Sync all files from templates directory
        while IFS= read -r src_file; do
            [[ -z "$src_file" ]] && continue
            local rel_path="${src_file#$templates_dir/}"
            local dst_file="$target/$rel_path"

            # Get top-level folder (or empty for root files)
            local top_folder=""
            if [[ "$rel_path" == */* ]]; then
                top_folder="${rel_path%%/*}"
            fi

            local status=""

            if [[ -f "$dst_file" ]]; then
                # File exists - check if different
                if cmp -s "$src_file" "$dst_file"; then
                    status="same"
                    if $verbose; then
                        echo -e "  ${BLUE}[same]${RESET} $rel_path"
                    fi
                elif $dry_run; then
                    status="overwritten"
                    if $verbose; then
                        echo -e "  ${YELLOW}[dry-run]${RESET} Would overwrite: $rel_path"
                    fi
                elif $force || $overwrite_all; then
                    cp "$src_file" "$dst_file"
                    status="overwritten"
                    if $verbose; then
                        echo -e "  ${YELLOW}[overwritten]${RESET} $rel_path"
                    fi
                elif $skip_all; then
                    status="skipped"
                    if $verbose; then
                        echo -e "  ${BLUE}[skipped]${RESET} $rel_path"
                    fi
                else
                    # Interactive prompt (read from /dev/tty since stdin is used by the loop)
                    echo -e "  ${YELLOW}[conflict]${RESET} $rel_path"
                    local choice=""
                    while true; do
                        # Write prompt to tty, read from tty
                        echo -n "    [o]verwrite | [s]kip | [d]iff | [b]ackup+overwrite | [O]verwrite all | [S]kip all: " >/dev/tty 2>/dev/null || {
                            echo "    Skipped (no TTY for interactive prompt, use --force to overwrite)"
                            status="skipped"
                            break
                        }
                        read -r choice </dev/tty 2>/dev/null || {
                            echo "    Skipped (no TTY for interactive prompt, use --force to overwrite)"
                            status="skipped"
                            break
                        }
                        case "$choice" in
                            o)
                                cp "$src_file" "$dst_file"
                                echo "    Overwritten"
                                status="overwritten"
                                break ;;
                            s)
                                echo "    Skipped"
                                status="skipped"
                                break ;;
                            d)
                                diff --color=auto "$dst_file" "$src_file" || true
                                ;;
                            b)
                                cp "$dst_file" "$dst_file.backup"
                                cp "$src_file" "$dst_file"
                                echo "    Backed up to $rel_path.backup and overwritten"
                                status="overwritten"
                                break ;;
                            O)
                                overwrite_all=true
                                cp "$src_file" "$dst_file"
                                echo "    Overwritten"
                                status="overwritten"
                                break ;;
                            S)
                                skip_all=true
                                echo "    Skipped"
                                status="skipped"
                                break ;;
                            *)
                                echo "    Invalid choice" ;;
                        esac
                    done
                fi
            else
                # New file
                status="new"
                if $dry_run; then
                    if $verbose; then
                        echo -e "  ${GREEN}[dry-run]${RESET} Would create: $rel_path"
                    fi
                else
                    mkdir -p "$(dirname "$dst_file")"
                    cp "$src_file" "$dst_file"
                    if $verbose; then
                        echo -e "  ${GREEN}[new]${RESET} $rel_path"
                    fi
                fi
            fi

            # Track stats
            if [[ -z "$top_folder" ]]; then
                # Root-level file - always show (unless verbose already showed it)
                if ! $verbose; then
                    case "$status" in
                        new) echo -e "  ${GREEN}[new]${RESET} $rel_path" ;;
                        same) echo -e "  ${BLUE}[same]${RESET} $rel_path" ;;
                        overwritten) echo -e "  ${YELLOW}[overwritten]${RESET} $rel_path" ;;
                        skipped) echo -e "  ${BLUE}[skipped]${RESET} $rel_path" ;;
                    esac
                fi
                case "$status" in
                    new) ((root_new++)) || true ;;
                    same) ((root_same++)) || true ;;
                    overwritten) ((root_overwritten++)) || true ;;
                    skipped) ((root_skipped++)) || true ;;
                esac
            else
                # Track folder stats
                case "$status" in
                    new) folder_new[$top_folder]=$(( ${folder_new[$top_folder]:-0} + 1 )) ;;
                    same) folder_same[$top_folder]=$(( ${folder_same[$top_folder]:-0} + 1 )) ;;
                    overwritten) folder_overwritten[$top_folder]=$(( ${folder_overwritten[$top_folder]:-0} + 1 )) ;;
                    skipped) folder_skipped[$top_folder]=$(( ${folder_skipped[$top_folder]:-0} + 1 )) ;;
                esac
            fi
        done < <(find "$templates_dir" -type f | sort)

        # Show folder summaries (only if not verbose)
        if ! $verbose; then
            for folder in $(echo "${!folder_new[@]} ${!folder_same[@]} ${!folder_overwritten[@]} ${!folder_skipped[@]}" | tr ' ' '\n' | sort -u); do
                local new=${folder_new[$folder]:-0}
                local same=${folder_same[$folder]:-0}
                local overwritten=${folder_overwritten[$folder]:-0}
                local skipped=${folder_skipped[$folder]:-0}
                local total=$((new + same + overwritten + skipped))

                # Build status summary
                local parts=()
                [[ $new -gt 0 ]] && parts+=("${new} new")
                [[ $same -gt 0 ]] && parts+=("${same} same")
                [[ $overwritten -gt 0 ]] && parts+=("${overwritten} overwritten")
                [[ $skipped -gt 0 ]] && parts+=("${skipped} skipped")

                # Choose color based on what changed
                local color="$BLUE"
                if [[ $new -gt 0 ]]; then
                    color="$GREEN"
                elif [[ $overwritten -gt 0 ]]; then
                    color="$YELLOW"
                fi

                local summary
                summary=$(IFS=', '; echo "${parts[*]}")
                echo -e "  ${color}[folder]${RESET} $folder/ ($summary)"
            done
        fi

        # Clean up associative arrays for next target
        unset folder_new folder_same folder_overwritten folder_skipped
    done

    log_success "Sync complete"
}
