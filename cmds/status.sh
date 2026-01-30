# status.sh - Status command

cmd_status() {
    require_jq
    local project="" verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper status [options]

Show sync status for all worktrees.

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --verbose, -v     Show individual files instead of folder summaries
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper status
  worktree-helper status --verbose
  worktree-helper status --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --verbose|-v) verbose=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *) die "Unexpected argument: $1" ;;
        esac
    done

    # Auto-detect project if not provided
    if [[ -z "$project" ]]; then
        project="$(detect_project)"
    fi

    project_exists "$project" || die "Project '$project' not found. Run: worktree-helper init $project"

    local templates_dir source_path
    templates_dir="$(project_templates_path "$project")"
    source_path="$(project_config_get "$project" '.project.source_path')"

    echo -e "${BOLD}Project:${RESET} $project"
    echo -e "${BOLD}Source:${RESET} $source_path"
    echo -e "${BOLD}Templates:${RESET} $templates_dir"
    echo ""

    # Count template files
    local template_count=0
    if [[ -d "$templates_dir" ]]; then
        template_count=$(find "$templates_dir" -type f | wc -l)
    fi
    echo -e "${BOLD}Template files:${RESET} $template_count"

    if [[ $template_count -gt 0 ]]; then
        echo ""
        find "$templates_dir" -type f | while read -r f; do
            echo "  - ${f#$templates_dir/}"
        done
    fi

    echo ""
    echo -e "${BOLD}Worktrees:${RESET}"

    while IFS= read -r worktree; do
        [[ -z "$worktree" ]] && continue
        echo -e "  ${BOLD}$worktree${RESET}"

        if $verbose; then
            # Verbose mode: show each file individually
            find "$templates_dir" -type f 2>/dev/null | while read -r src_file; do
                local rel_path="${src_file#$templates_dir/}"
                local dst_file="$worktree/$rel_path"

                if [[ ! -f "$dst_file" ]]; then
                    echo -e "    ${RED}[missing]${RESET} $rel_path"
                elif cmp -s "$src_file" "$dst_file"; then
                    echo -e "    ${GREEN}[synced]${RESET} $rel_path"
                else
                    echo -e "    ${YELLOW}[differs]${RESET} $rel_path"
                fi
            done
        else
            # Collapsed mode: group by top-level folder
            declare -A folder_synced folder_differs folder_missing
            local -a root_files=()

            while IFS= read -r src_file; do
                [[ -z "$src_file" ]] && continue
                local rel_path="${src_file#$templates_dir/}"
                local dst_file="$worktree/$rel_path"
                local status

                if [[ ! -f "$dst_file" ]]; then
                    status="missing"
                elif cmp -s "$src_file" "$dst_file"; then
                    status="synced"
                else
                    status="differs"
                fi

                # Check if file is in a folder or at root
                if [[ "$rel_path" == */* ]]; then
                    local top_folder="${rel_path%%/*}"
                    case "$status" in
                        synced) folder_synced[$top_folder]=$((${folder_synced[$top_folder]:-0} + 1)) ;;
                        differs) folder_differs[$top_folder]=$((${folder_differs[$top_folder]:-0} + 1)) ;;
                        missing) folder_missing[$top_folder]=$((${folder_missing[$top_folder]:-0} + 1)) ;;
                    esac
                else
                    root_files+=("$status:$rel_path")
                fi
            done < <(find "$templates_dir" -type f 2>/dev/null)

            # Display root files first
            for entry in "${root_files[@]}"; do
                local status="${entry%%:*}"
                local file="${entry#*:}"
                case "$status" in
                    synced) echo -e "    ${GREEN}[synced]${RESET} $file" ;;
                    differs) echo -e "    ${YELLOW}[differs]${RESET} $file" ;;
                    missing) echo -e "    ${RED}[missing]${RESET} $file" ;;
                esac
            done

            # Display folder summaries
            local -a all_folders=()
            for folder in "${!folder_synced[@]}" "${!folder_differs[@]}" "${!folder_missing[@]}"; do
                [[ " ${all_folders[*]} " == *" $folder "* ]] || all_folders+=("$folder")
            done

            for folder in "${all_folders[@]}"; do
                local synced=${folder_synced[$folder]:-0}
                local differs=${folder_differs[$folder]:-0}
                local missing=${folder_missing[$folder]:-0}

                # Build status parts
                local -a parts=()
                [[ $synced -gt 0 ]] && parts+=("$synced synced")
                [[ $differs -gt 0 ]] && parts+=("$differs differs")
                [[ $missing -gt 0 ]] && parts+=("$missing missing")

                local summary
                summary=$(IFS=', '; echo "${parts[*]}")

                # Color based on worst status
                if [[ $missing -gt 0 ]]; then
                    echo -e "    ${RED}$folder/${RESET} ($summary)"
                elif [[ $differs -gt 0 ]]; then
                    echo -e "    ${YELLOW}$folder/${RESET} ($summary)"
                else
                    echo -e "    ${GREEN}$folder/${RESET} ($summary)"
                fi
            done

            unset folder_synced folder_differs folder_missing
        fi
    done < <(git_all_worktrees)
}
