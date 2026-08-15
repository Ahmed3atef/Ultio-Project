#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# switch-site-app-refs.sh
#
# Switch existing bench apps to the branches/tags listed in one site JSON file.
# This does not create sites, fetch/install apps with bench, migrate, or build.
#
# Usage:
#   bash scripts/switch-site-app-refs.sh
#   bash scripts/switch-site-app-refs.sh aljar
#   BENCH_DIR=/path/to/frappe-bench bash scripts/switch-site-app-refs.sh scripts/sites/aljar.json
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SITES_DIR="$SCRIPT_DIR/sites"
BENCH_DIR="${BENCH_DIR:-$ROOT_DIR/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
CONFIG_INPUT="${1:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[switch-refs] $*${NC}"; }
log_ok()   { echo -e "${GREEN}[switch-refs] ✔ $*${NC}"; }
log_err()  { echo -e "${RED}[switch-refs] ✘ $*${NC}"; }
log_step() { echo -e "${BLUE}[switch-refs] $*${NC}"; }

prompt_yes_no() {
    local label="$1"
    local default_value="$2"
    local prompt="y/N"
    local answer

    if [[ "$default_value" == "true" ]]; then
        prompt="Y/n"
    fi

    while true; do
        read -r -p "$label [$prompt]: " answer
        answer="${answer:-}"

        if [[ -z "$answer" ]]; then
            [[ "$default_value" == "true" ]] && return 0 || return 1
        fi

        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

json_field() {
    python3 - "$CONFIG_FILE" "$1" << 'PY'
import json
import sys

with open(sys.argv[1]) as handle:
    data = json.load(handle)

print(data.get(sys.argv[2], "") or "")
PY
}

json_app_pairs() {
    python3 - "$CONFIG_FILE" << 'PY'
import json
import sys

with open(sys.argv[1]) as handle:
    data = json.load(handle)

for app in data.get("apps", []):
    name = app.get("name", "")
    branch = app.get("branch", "")
    if name and branch:
        print(name + "\t" + branch)
PY
}

resolve_config_from_input() {
    local input="$1"

    if [[ -z "$input" ]]; then
        return 1
    fi

    if [[ -f "$input" ]]; then
        realpath "$input"
        return
    fi

    if [[ -f "$SITES_DIR/$input" ]]; then
        realpath "$SITES_DIR/$input"
        return
    fi

    if [[ -f "$SITES_DIR/$input.json" ]]; then
        realpath "$SITES_DIR/$input.json"
        return
    fi

    return 1
}

site_config_label() {
    python3 - "$1" << 'PY'
import json
import os
import sys

path = sys.argv[1]
try:
    with open(path) as handle:
        site_name = json.load(handle).get("site_name", "")
except Exception:
    site_name = ""

suffix = f" ({site_name})" if site_name else ""
print(os.path.basename(path) + suffix)
PY
}

choose_config() {
    local configs=()
    local config selection index

    if [[ ! -d "$SITES_DIR" ]]; then
        log_err "Site config directory not found: $SITES_DIR"
        exit 1
    fi

    for config in "$SITES_DIR"/*.json; do
        [[ -f "$config" ]] || continue
        configs+=("$config")
    done

    if [[ "${#configs[@]}" -eq 0 ]]; then
        log_err "No JSON configs found in: $SITES_DIR"
        exit 1
    fi

    echo -e "\n${GREEN}════════════════════════════════════════${NC}" >&2
    echo -e "${GREEN}[switch-refs] ✔ Switch app branches/tags from site JSON${NC}" >&2
    echo -e "${GREEN}════════════════════════════════════════${NC}" >&2
    echo >&2
    echo "Bench: $BENCH_DIR" >&2
    echo "Choose the site config to apply:" >&2
    echo >&2

    index=1
    for config in "${configs[@]}"; do
        printf "%2d) %s\n" "$index" "$(site_config_label "$config")" >&2
        index=$((index + 1))
    done

    while true; do
        echo >&2
        read -r -p "Site config number, name, or path: " selection
        selection="${selection:-}"

        if [[ -z "$selection" ]]; then
            echo "Pick a config number, config name, or JSON path." >&2
            continue
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            index=$((selection - 1))
            if (( index >= 0 && index < ${#configs[@]} )); then
                realpath "${configs[$index]}"
                return
            fi
            echo "Invalid selection: $selection" >&2
            continue
        fi

        if resolve_config_from_input "$selection"; then
            return
        fi

        echo "Could not find config: $selection" >&2
    done
}

ensure_bench() {
    if [[ ! -d "$APPS_DIR" ]]; then
        log_err "Bench apps directory not found: $APPS_DIR"
        log_err "Set BENCH_DIR=/path/to/frappe-bench if your bench is somewhere else."
        exit 1
    fi
}

checkout_ref() {
    local app="$1"
    local ref="$2"
    local app_dir="$APPS_DIR/$app"
    local current_ref=""

    if [[ ! -d "$app_dir/.git" ]]; then
        log_err "Missing app git repo: $app_dir"
        return 1
    fi

    current_ref="$(git -C "$app_dir" describe --tags --exact-match 2>/dev/null || git -C "$app_dir" branch --show-current || true)"
    [[ -n "$current_ref" ]] || current_ref="$(git -C "$app_dir" rev-parse --short HEAD 2>/dev/null || true)"

    echo -e "\n${YELLOW}────────────────────────────────────────${NC}"
    log_step "$app: ${current_ref:-unknown} → $ref"
    echo -e "${YELLOW}────────────────────────────────────────${NC}"

    if git -C "$app_dir" diff --quiet && git -C "$app_dir" diff --cached --quiet; then
        :
    else
        log_err "$app has uncommitted changes. Commit/stash them, then run again."
        return 1
    fi

    if [[ "$FETCH_REFS" == "true" ]]; then
        log_info "Fetching branches and tags for $app..."
        git -C "$app_dir" fetch --all --tags --prune
    fi

    git -C "$app_dir" checkout "$ref"
    log_ok "$app is now on $ref"
}

switch_all_apps() {
    local app ref
    local total=0
    local switched=0
    local failed=0

    log_info "Reading app refs from: $(basename "$CONFIG_FILE")"

    while IFS=$'\t' read -r app ref; do
        total=$((total + 1))

        if checkout_ref "$app" "$ref"; then
            switched=$((switched + 1))
        else
            failed=$((failed + 1))
            if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
                log_err "Stopped after failure. Re-run with clean repos or choose continue-on-error."
                exit 1
            fi
        fi
    done < <(json_app_pairs)

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Done: $switched/$total app refs switched"
    if (( failed > 0 )); then
        log_err "$failed app(s) failed"
        exit 1
    fi
    echo -e "${GREEN}════════════════════════════════════════${NC}"
}

main() {
    ensure_bench

    if [[ -n "$CONFIG_INPUT" ]]; then
        if ! CONFIG_FILE="$(resolve_config_from_input "$CONFIG_INPUT")"; then
            log_err "Config not found: $CONFIG_INPUT"
            log_err "Use a JSON path or a config name from $SITES_DIR."
            exit 1
        fi
    else
        CONFIG_FILE="$(choose_config)"
    fi

    SITE_NAME="$(json_field "site_name")"

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Selected: $(basename "$CONFIG_FILE")${SITE_NAME:+ ($SITE_NAME)}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo "This will only run git checkout for existing apps."
    echo "It will not install apps, create sites, migrate, or build assets."
    echo

    if prompt_yes_no "Fetch latest branches/tags before checkout" "true"; then
        FETCH_REFS=true
    else
        FETCH_REFS=false
    fi

    if prompt_yes_no "Continue if one app fails" "false"; then
        CONTINUE_ON_ERROR=true
    else
        CONTINUE_ON_ERROR=false
    fi

    switch_all_apps
}

main
