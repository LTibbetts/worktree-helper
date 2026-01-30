# show.sh - Show templates command

cmd_show_templates() {
    require_jq
    local project="" show_contents=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} worktree-helper show-templates [options]

Show captured template files, optionally with their contents.

${BOLD}Options:${RESET}
  --project <name>  Project name (default: auto-detect)
  --contents        Show file contents
  --help, -h        Show this help message

${BOLD}Examples:${RESET}
  worktree-helper show-templates
  worktree-helper show-templates --contents
  worktree-helper show-templates --project myproject"
                return 0 ;;
            --project) project="$2"; shift 2 ;;
            --project=*) project="${1#*=}"; shift ;;
            --contents) show_contents=true; shift ;;
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

    local templates_dir
    templates_dir="$(project_templates_path "$project")"

    if [[ ! -d "$templates_dir" ]]; then
        log_warn "No templates directory found: $templates_dir"
        log_info "Run 'worktree-helper capture-templates' to capture files."
        return 0
    fi

    local count=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local rel_path="${file#$templates_dir/}"
        ((count++)) || true

        if $show_contents; then
            echo -e "${BOLD}━━━ $rel_path ━━━${RESET}"
            cat "$file"
            echo ""
        else
            echo "  $rel_path"
        fi
    done < <(find "$templates_dir" -type f | sort)

    if [[ $count -eq 0 ]]; then
        log_info "No template files captured yet."
        log_info "Run 'worktree-helper capture-templates' to capture files."
    elif ! $show_contents; then
        echo ""
        log_info "$count template file(s) in $templates_dir"
    fi
}
