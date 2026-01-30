# utils.sh - Utility functions for dependency checking

require_cmd() {
    command -v "$1" &>/dev/null || die "Required command not found: $1"
}

require_jq() {
    require_cmd jq
}

require_rsync() {
    require_cmd rsync
}
