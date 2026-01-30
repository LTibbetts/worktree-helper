# config.sh - Project configuration helpers

# Get project config path
project_config_path() {
    local project="$1"
    echo "$CONFIG_DIR/projects/$project/config.json"
}

# Get project templates path
project_templates_path() {
    local project="$1"
    echo "$CONFIG_DIR/projects/$project/templates"
}

# Check if project exists
project_exists() {
    local project="$1"
    [[ -f "$(project_config_path "$project")" ]]
}

# Read a value from project config
project_config_get() {
    local project="$1"
    local key="$2"
    local config_file
    config_file="$(project_config_path "$project")"
    jq -r "$key // empty" "$config_file" 2>/dev/null
}

# Detect project from current directory
detect_project() {
    local search_path="${1:-$(pwd)}"
    local root remote_url root_name
    root="$(git -C "$search_path" rev-parse --show-toplevel 2>/dev/null)" || die "Not in a git repository: $search_path"
    remote_url="$(git -C "$search_path" remote get-url origin 2>/dev/null || echo "")"
    root_name="$(basename "$root")"

    # Check each project config for a match
    for config_file in "$CONFIG_DIR/projects"/*/config.json; do
        [[ -f "$config_file" ]] || continue
        local project_name
        project_name="$(jq -r '.project.name' "$config_file")"

        # Check remote patterns
        local patterns
        patterns="$(jq -r '.project.match.remote_patterns[]? // empty' "$config_file" 2>/dev/null)"
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            if [[ "$remote_url" =~ $pattern ]]; then
                echo "$project_name"
                return 0
            fi
        done <<< "$patterns"

        # Check root name
        local match_root
        match_root="$(jq -r '.project.match.root_name // empty' "$config_file" 2>/dev/null)"
        if [[ -n "$match_root" && "$root_name" == "$match_root" ]]; then
            echo "$project_name"
            return 0
        fi
    done

    # Fallback: use root directory name
    echo "$root_name"
}
