# main.sh - Command dispatcher

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init) cmd_init "$@" ;;
        sync) cmd_sync "$@" ;;
        status) cmd_status "$@" ;;
        add-file) cmd_add_file "$@" ;;
        add-folder) cmd_add_folder "$@" ;;
        add-files) cmd_add_files "$@" ;;
        capture-templates) cmd_capture_templates "$@" ;;
        show-templates) cmd_show_templates "$@" ;;
        install-alias) cmd_install_alias "$@" ;;
        list) cmd_list "$@" ;;
        help|--help|-h) cmd_help ;;
        version|--version|-v) cmd_version ;;
        *) die "Unknown command: $cmd. Run 'worktree-helper help' for usage." ;;
    esac
}
