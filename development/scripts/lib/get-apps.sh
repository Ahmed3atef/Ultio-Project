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
#   - url set           -> clone the repo (default branch), pip-install it,
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

    if [[ "$remote_refspec" != "+refs/heads/*:refs/remotes/${remote_name}/*" ]]; then
        log_info "Fixing refspec: '$remote_refspec' -> '+refs/heads/*:refs/remotes/${remote_name}/*'"
        git -C "$app_dir" config "remote.${remote_name}.fetch" "+refs/heads/*:refs/remotes/${remote_name}/*"
    else
        log_ok "Refspec already correct."
    fi

    git -C "$app_dir" fetch "$remote_name" --tags
    log_ok "All branches and tags fetched for $folder_name"
}

# register_app_in_bench FOLDER_NAME — pip install the app and add it to apps.txt.
register_app_in_bench() {
    local folder_name="$1"

    log_info "Installing $folder_name into bench (pip)..."
    bench pip install -e "apps/$folder_name"

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

    log_info "App '$folder_name' already exists. Fixing refspec and fetching all branches/tags..."
    expand_remote_refs "$app_dir" "$folder_name"
}

install_by_name() {
    local app_name="$1"
    local branch="$2"
    local app_dir="$APPS_DIR/$app_name"

    if [[ -n "$branch" ]]; then
        log_info "Running: bench get-app $app_name --branch $branch"
        bench get-app "$app_name" --branch "$branch"
    else
        log_info "Running: bench get-app $app_name"
        bench get-app "$app_name"
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
