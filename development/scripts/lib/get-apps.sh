#!/usr/bin/env bash
# get-apps.sh — fetch and register apps into the bench.
#
# Usage:
#   BENCH_DIR=/path/to/bench bash get-apps.sh [apps.json]
#
# Behaviour per app entry:
#   - name set, no url  -> `bench get-app NAME --branch BRANCH`, then expand
#                          the refspec and fetch all branches/tags so later
#                          site scripts can checkout any configured ref.
#   - url set           -> clone the repo (default branch), uv-install it,
#                          register it in sites/apps.txt, then fetch all refs.
#   - folder already exists -> only fix the refspec and fetch all refs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="get-apps"
source "$SCRIPT_DIR/common.sh"

APPS_CONFIG="${1:-$SCRIPT_DIR/../apps/apps.json}"
BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
APPS_TXT="$BENCH_DIR/sites/apps.txt"

if [[ ! -f "$APPS_CONFIG" ]]; then
    log_err "Apps JSON not found: $APPS_CONFIG"
    exit 1
fi

APPS_CONFIG="$(realpath "$APPS_CONFIG")"
cd "$BENCH_DIR"

# ── Config reader ─────────────────────────────────────────────────────────────

# app_rows — prints "name\x1fbranch\x1furl" for every entry (empty fields kept).
app_rows() {
    python3 - "$APPS_CONFIG" << 'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
apps = data.get("apps", data if isinstance(data, list) else [])

for app in apps:
    name = app.get("name") or ""
    branch = app.get("branch") or ""
    url = app.get("url") or app.get("repo_url") or ""
    print("\x1f".join([name, branch, url]))
PY
}

# ── Git helpers ───────────────────────────────────────────────────────────────

# app_folder_name APP_NAME REPO_URL — echoes the folder name for an app entry.
app_folder_name() {
    local app_name="$1"
    local repo_url="$2"

    if [[ -n "$repo_url" ]]; then
        basename "$repo_url" .git
    else
        printf '%s\n' "$app_name"
    fi
}

# remote_name_for APP_DIR — echoes the remote bench uses (upstream or origin).
remote_name_for() {
    local app_dir="$1"
    if git -C "$app_dir" remote get-url upstream &>/dev/null; then
        printf 'upstream\n'
    else
        printf 'origin\n'
    fi
}

# expand_remote_refs APP_DIR FOLDER_NAME — fetch all branches/tags of the app.
expand_remote_refs() {
    local app_dir="$1"
    local folder_name="$2"
    local remote_name remote_refspec

    remote_name="$(remote_name_for "$app_dir")"
    remote_refspec="$(git -C "$app_dir" config --get "remote.${remote_name}.fetch" || true)"

    if [[ "$folder_name" == "frappe" || "$folder_name" == "erpnext" ]]; then
        local current_branch
        current_branch="$(git -C "$app_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "version-15")"
        [[ "$current_branch" == "HEAD" ]] && current_branch="version-15"

        if [[ "$remote_refspec" == "+refs/heads/*:refs/remotes/${remote_name}/*" ]]; then
            log_info "Restricting refspec for $folder_name to $current_branch to prevent huge downloads"
            git -C "$app_dir" config "remote.${remote_name}.fetch" "+refs/heads/${current_branch}:refs/remotes/${remote_name}/${current_branch}"
        fi
    else
        if [[ "$remote_refspec" != "+refs/heads/*:refs/remotes/${remote_name}/*" ]]; then
            log_info "Fixing refspec: '$remote_refspec' -> '+refs/heads/*:refs/remotes/${remote_name}/*'"
            git -C "$app_dir" config "remote.${remote_name}.fetch" "+refs/heads/*:refs/remotes/${remote_name}/*"
        else
            log_ok "Refspec already correct."
        fi
    fi

    git -C "$app_dir" fetch "$remote_name" --tags --depth=1
    log_ok "All branches and tags fetched for $folder_name"
}

# register_app_in_bench FOLDER_NAME — install the app and add it to apps.txt.
register_app_in_bench() {
    local folder_name="$1"
    local app_path="$BENCH_DIR/apps/$folder_name"

    log_info "Installing $folder_name into bench (uv)..."
    uv pip install --python "$BENCH_DIR/env/bin/python" --editable "$app_path" --no-deps

    if [[ -f "$app_path/requirements.txt" ]]; then
        log_info "Installing $folder_name requirements (uv)..."
        uv pip install --python "$BENCH_DIR/env/bin/python" --requirement "$app_path/requirements.txt" --no-deps
    fi

    if grep -qx "$folder_name" "$APPS_TXT" 2>/dev/null; then
        log_info "'$folder_name' already in apps.txt. Skipping."
        return
    fi

    if [[ -s "$APPS_TXT" ]] && [[ "$(tail -c1 "$APPS_TXT" | wc -l)" -eq 0 ]]; then
        echo "" >> "$APPS_TXT"
    fi
    echo "$folder_name" >> "$APPS_TXT"
    log_ok "Added '$folder_name' to apps.txt"
}

# ── Install paths ─────────────────────────────────────────────────────────────

fetch_existing_app() {
    local app_dir="$1"
    local folder_name="$2"

    log_info "App '$folder_name' already exists. Registering it and fetching all branches/tags..."
    register_app_in_bench "$folder_name"
    expand_remote_refs "$app_dir" "$folder_name"
}

install_by_name() {
    local app_name="$1"
    local branch="$2"
    local app_dir="$APPS_DIR/$app_name"

    if [[ -n "$branch" ]]; then
        log_info "Running: bench get-app $app_name --branch $branch --resolve-deps"
        bench get-app "$app_name" --branch "$branch" --resolve-deps
    else
        log_info "Running: bench get-app $app_name --resolve-deps"
        bench get-app "$app_name" --resolve-deps
    fi

    log_info "Expanding refspec to fetch all branches and tags..."
    expand_remote_refs "$app_dir" "$app_name"
    log_ok "$app_name installed with all branches/tags fetched"
}

clone_and_register() {
    local repo_url="$1"
    local folder_name="$2"
    local app_dir="$APPS_DIR/$folder_name"

    log_info "Cloning $folder_name from: $repo_url (default branch)"
    git clone "$repo_url" "$app_dir"

    register_app_in_bench "$folder_name"
    expand_remote_refs "$app_dir" "$folder_name"
    log_ok "$folder_name done (default branch)"
}

get_app() {
    local app_name="${1:-}"
    local branch="${2:-}"
    local repo_url="${3:-}"
    local folder_name app_dir

    folder_name="$(app_folder_name "$app_name" "$repo_url")"
    if [[ -z "$folder_name" ]]; then
        log_info "Skipping app entry with empty name and empty url."
        return
    fi

    app_dir="$APPS_DIR/$folder_name"

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}GETTING APP: $folder_name${NC}"
    echo -e "${YELLOW}========================================${NC}"

    if [[ -d "$app_dir" ]]; then
        fetch_existing_app "$app_dir" "$folder_name"
    elif [[ -n "$repo_url" ]]; then
        clone_and_register "$repo_url" "$folder_name"
    else
        install_by_name "$app_name" "$branch"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

while IFS=$'\x1f' read -r app branch url; do
    get_app "$app" "$branch" "$url"
done < <(app_rows)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All selected apps fetched and registered successfully!${NC}"
echo -e "${GREEN}Now run your site installation script.${NC}"
echo -e "${GREEN}========================================${NC}"
