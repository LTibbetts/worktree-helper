# status.sh - Status command

cmd_status() {
    require_jq
    local project=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper status [options]

Show sync status for all worktrees.

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper status
  worktree-helper status --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
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

        # Check each template file
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
    done < <(git_all_worktrees)
}
