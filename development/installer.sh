#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# installer.sh — interactive entrypoint
#
# 1. Asks for bench settings
# 2. Lets you fetch all apps or select one/more apps from scripts/get-apps/apps.json
# 3. Initialises frappe-bench when needed
# 4. Calls setup-site.sh for every JSON file in scripts/sites/
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Resolve script root (works regardless of cwd) ────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GET_APPS_SCRIPT="$SCRIPT_DIR/scripts/get-apps/get-apps.sh"
GET_APPS_CONFIG="$SCRIPT_DIR/scripts/get-apps/apps.json"
SITES_DIR="$SCRIPT_DIR/scripts/sites"
SETUP_SITE_SCRIPT="$SCRIPT_DIR/scripts/setup-site.sh"
SELECTED_APPS_CONFIG="$GET_APPS_CONFIG"
APP_SELECTION_FILE=""
SITE_MODE="configured"
CLEAN_SITE_NAME="clean.localhost"
SELECTED_SITE_CONFIGS=()
SITE_CONFIG_APP_MODE="with_apps"

# ── Colors ────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[installer] $*${NC}"; }
log_ok()   { echo -e "${GREEN}[installer] ✔ $*${NC}"; }
log_err()  { echo -e "${RED}[installer] ✘ $*${NC}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────

BENCH_NAME="frappe-bench"
FRAPPE_REPO="https://github.com/frappe/frappe"
FRAPPE_BRANCH="version-15"
PY_VERSION=""
NODE_VERSION=""
DB_TYPE="mariadb"
ADMIN_PASSWORD="admin"
VERBOSE=false
BENCH_PATH="$(pwd)/${BENCH_NAME}"

cleanup() {
    if [[ -n "$APP_SELECTION_FILE" && -f "$APP_SELECTION_FILE" ]]; then
        rm -f "$APP_SELECTION_FILE"
    fi
}
trap cleanup EXIT

if [[ $# -gt 0 ]]; then
    log_err "installer.sh is interactive now. Run: bash installer.sh"
    exit 1
fi

prompt_value() {
    local label="$1"
    local default_value="$2"
    local value

    if [[ -n "$default_value" ]]; then
        read -r -p "$label [$default_value]: " value
        printf '%s' "${value:-$default_value}"
    else
        read -r -p "$label: " value
        printf '%s' "$value"
    fi
}

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

prompt_db_type() {
    local value

    while true; do
        value="$(prompt_value "Database type (mariadb/postgresql)" "$DB_TYPE")"
        case "$value" in
            mariadb|postgresql)
                DB_TYPE="$value"
                return
                ;;
            *) echo "Choose mariadb or postgresql." ;;
        esac
    done
}

configure_cli() {
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Frappe bench installer"
    echo -e "${GREEN}════════════════════════════════════════${NC}"

    if [[ -d "$BENCH_PATH" ]]; then
        log_info "Bench already exists at $BENCH_PATH — skipping bench init prompts."
    else
        echo "Press Enter to keep the default shown in brackets."
        echo

        BENCH_NAME="$(prompt_value "Bench directory name" "$BENCH_NAME")"
        BENCH_PATH="$(pwd)/${BENCH_NAME}"

        if [[ -d "$BENCH_PATH" ]]; then
            log_info "Bench already exists at $BENCH_PATH — skipping bench init prompts."
        else
            FRAPPE_REPO="$(prompt_value "Frappe git URL" "$FRAPPE_REPO")"
            FRAPPE_BRANCH="$(prompt_value "Frappe branch" "$FRAPPE_BRANCH")"
            PY_VERSION="$(prompt_value "pyenv Python version (optional)" "$PY_VERSION")"
            NODE_VERSION="$(prompt_value "nvm Node version (optional)" "$NODE_VERSION")"

            if prompt_yes_no "Pass --verbose to bench init" "$VERBOSE"; then
                VERBOSE=true
            else
                VERBOSE=false
            fi
        fi
    fi

    prompt_db_type
    ADMIN_PASSWORD="$(prompt_value "Site admin password" "$ADMIN_PASSWORD")"
}

app_label_rows() {
    python3 - "$GET_APPS_CONFIG" << 'PY'
import json
import os
import sys
from urllib.parse import urlparse

def folder_name(app):
    name = app.get("name") or ""
    url = app.get("url") or app.get("repo_url") or ""
    if name:
        return name
    if not url:
        return "<empty>"
    path = urlparse(url).path if "://" in url else url.rsplit(":", 1)[-1]
    return os.path.basename(path).removesuffix(".git")

data = json.load(open(sys.argv[1]))
apps = data.get("apps", data if isinstance(data, list) else [])
for index, app in enumerate(apps, start=1):
    name = folder_name(app)
    branch = app.get("branch") or "default"
    url = app.get("url") or app.get("repo_url") or "bench get-app"
    print(f"{index:2d}) {name:<28} {branch:<12} {url}")
PY
}

choose_apps() {
    local mode selection

    if [[ ! -f "$GET_APPS_CONFIG" ]]; then
        log_err "Apps JSON not found: $GET_APPS_CONFIG"
        exit 1
    fi

    echo -e "\n${YELLOW}Apps to fetch${NC}"
    echo "1) All apps from apps.json"
    echo "2) Select one or more apps"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|all|a)
                SELECTED_APPS_CONFIG="$GET_APPS_CONFIG"
                log_ok "Selected all apps."
                return
                ;;
            2|select|s)
                break
                ;;
            *) echo "Choose 1 for all apps or 2 to select apps." ;;
        esac
    done

    echo
    app_label_rows
    echo
    echo "Enter numbers separated by spaces or commas. Example: 1 2 7,10"
    echo "Type 'all' to use the full list."

    while true; do
        read -r -p "Apps: " selection
        selection="${selection:-}"

        if [[ "${selection,,}" == "all" ]]; then
            SELECTED_APPS_CONFIG="$GET_APPS_CONFIG"
            log_ok "Selected all apps."
            return
        fi

        if [[ -z "$selection" ]]; then
            echo "Pick at least one app, or type all."
            continue
        fi

        APP_SELECTION_FILE="$(mktemp /tmp/get-apps-selected.XXXXXX.json)"
        if python3 - "$GET_APPS_CONFIG" "$APP_SELECTION_FILE" "$selection" << 'PY'
import json
import sys

source, target, raw_selection = sys.argv[1:4]
data = json.load(open(source))
apps = data.get("apps", data if isinstance(data, list) else [])
selected = []
seen = set()
errors = []

for token in raw_selection.replace(",", " ").split():
    if not token.isdigit():
        errors.append(token)
        continue
    index = int(token)
    if index < 1 or index > len(apps):
        errors.append(token)
        continue
    if index not in seen:
        selected.append(apps[index - 1])
        seen.add(index)

if errors:
    print("Invalid selection: " + ", ".join(errors), file=sys.stderr)
    sys.exit(1)
if not selected:
    print("No apps selected.", file=sys.stderr)
    sys.exit(1)

with open(target, "w") as handle:
    json.dump({"apps": selected}, handle, indent=2)
    handle.write("\n")
PY
        then
            SELECTED_APPS_CONFIG="$APP_SELECTION_FILE"
            log_ok "Selected app list prepared."
            return
        fi

        rm -f "$APP_SELECTION_FILE"
        APP_SELECTION_FILE=""
    done
}

choose_site_mode() {
    local mode

    echo -e "\n${YELLOW}Site setup${NC}"
    echo "1) Use site JSON configs from scripts/sites (install apps listed per site)"
    echo "2) Create one clean site (no app installs)"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|configured|config|c)
                SITE_MODE="configured"
                log_ok "Selected site JSON config mode."
                return
                ;;
            2|clean)
                SITE_MODE="clean"
                CLEAN_SITE_NAME="$(prompt_value "Clean site name" "$CLEAN_SITE_NAME")"
                log_ok "Selected clean site: $CLEAN_SITE_NAME"
                return
                ;;
            *) echo "Choose 1 for site configs or 2 for a clean site." ;;
        esac
    done
}

site_config_rows() {
    local index=1
    local config

    for config in "$SITES_DIR"/*.json; do
        [[ -f "$config" ]] || continue
        printf "%2d) %s\n" "$index" "$(basename "$config")"
        index=$((index + 1))
    done
}

choose_site_configs() {
    local mode selection
    local configs=()
    local config

    if [[ ! -d "$SITES_DIR" ]]; then
        log_err "Sites config directory not found: $SITES_DIR"
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

    echo -e "\n${YELLOW}Site configs${NC}"
    echo "1) All site configs"
    echo "2) Select one or more site configs"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|all|a)
                SELECTED_SITE_CONFIGS=("${configs[@]}")
                log_ok "Selected all site configs."
                return
                ;;
            2|select|s)
                break
                ;;
            *) echo "Choose 1 for all site configs or 2 to select configs." ;;
        esac
    done

    echo
    site_config_rows
    echo
    echo "Enter numbers separated by spaces or commas. Example: 1 3,5"
    echo "Type 'all' to use the full list."

    while true; do
        local selected=()
        local seen=" "
        local token index
        local invalid=false

        read -r -p "Site configs: " selection
        selection="${selection:-}"

        if [[ "${selection,,}" == "all" ]]; then
            SELECTED_SITE_CONFIGS=("${configs[@]}")
            log_ok "Selected all site configs."
            return
        fi

        if [[ -z "$selection" ]]; then
            echo "Pick at least one site config, or type all."
            continue
        fi

        for token in ${selection//,/ }; do
            if [[ ! "$token" =~ ^[0-9]+$ ]]; then
                echo "Invalid selection: $token"
                invalid=true
                break
            fi

            index=$((token - 1))
            if (( index < 0 || index >= ${#configs[@]} )); then
                echo "Invalid selection: $token"
                invalid=true
                break
            fi

            if [[ "$seen" != *" $token "* ]]; then
                selected+=("${configs[$index]}")
                seen+="$token "
            fi
        done

        if [[ "$invalid" == true ]]; then
            continue
        fi

        if [[ "${#selected[@]}" -eq 0 ]]; then
            echo "No site configs selected."
            continue
        fi

        SELECTED_SITE_CONFIGS=("${selected[@]}")
        log_ok "Selected ${#SELECTED_SITE_CONFIGS[@]} site config(s)."
        return
    done
}

choose_site_config_app_mode() {
    local mode

    echo -e "\n${YELLOW}Selected site configs${NC}"
    echo "1) Create sites and install apps listed in each site JSON"
    echo "2) Create sites only (no app installs)"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|apps|with-apps)
                SITE_CONFIG_APP_MODE="with_apps"
                log_ok "Selected app install mode for site configs."
                return
                ;;
            2|clean|sites-only|no-apps)
                SITE_CONFIG_APP_MODE="sites_only"
                log_ok "Selected sites-only mode for site configs."
                return
                ;;
            *) echo "Choose 1 to install apps or 2 to create sites only." ;;
        esac
    done
}

site_name_from_config() {
    python3 - "$1" << 'PY'
import json
import sys

with open(sys.argv[1]) as handle:
    print(json.load(handle).get("site_name", ""))
PY
}

create_site_by_name() {
    local site_name="$1"

    pushd "$BENCH_PATH" > /dev/null

    if [[ -d "$BENCH_PATH/sites/$site_name" ]]; then
        log_info "Site already exists: $site_name — skipping creation."
        popd > /dev/null
        return
    fi

    log_info "Creating site: $site_name (db_type=$DB_TYPE)"

    local cmd=(
        bench new-site
        --db-root-username=root
        --db-root-password=123
        --db-type="$DB_TYPE"
        --admin-password="$ADMIN_PASSWORD"
        "$site_name"
    )

    if [[ "$DB_TYPE" == "mariadb" ]]; then
        bench set-config -g db_host "mariadb"
        cmd+=(--db-host="mariadb" --mariadb-user-host-login-scope=%)
    else
        bench set-config -g db_host "postgresql"
        cmd+=(--db-host="postgresql")
    fi

    "${cmd[@]}"
    log_ok "Site created: $site_name"

    popd > /dev/null
}

create_clean_sites_from_configs() {
    local config site_name

    if [[ "${#SELECTED_SITE_CONFIGS[@]}" -eq 0 ]]; then
        log_err "No site configs selected."
        exit 1
    fi

    for config in "${SELECTED_SITE_CONFIGS[@]}"; do
        site_name="$(site_name_from_config "$config")"
        if [[ -z "$site_name" ]]; then
            log_err "site_name missing in $(basename "$config")"
            exit 1
        fi

        echo -e "\n${GREEN}════════════════════════════════════════${NC}"
        log_info "Creating clean site from: $(basename "$config")"
        echo -e "${GREEN}════════════════════════════════════════${NC}"
        create_site_by_name "$site_name"
    done
}

create_clean_site() {
    create_site_by_name "$CLEAN_SITE_NAME"
}

# ── Step 1: Init bench ────────────────────────────────────────────────────────

init_bench() {
    if [[ -d "$BENCH_PATH" ]]; then
        log_info "Bench already exists — skipping init."
        return
    fi

    log_info "Initialising bench: $BENCH_NAME"

    local cmd=""

    [[ -n "$NODE_VERSION" ]] && cmd+="nvm use ${NODE_VERSION} && "
    [[ -n "$PY_VERSION"   ]] && export PYENV_VERSION="$PY_VERSION"

    cmd+="bench init"
    cmd+=" --skip-redis-config-generation"
    [[ "$VERBOSE" == true ]] && cmd+=" --verbose"
    cmd+=" --frappe-path=${FRAPPE_REPO}"
    cmd+=" --frappe-branch=${FRAPPE_BRANCH}"
    cmd+=" ${BENCH_NAME}"

    bash -ic "$cmd"

    pushd "$BENCH_PATH" > /dev/null

    log_info "Configuring bench..."

    bench set-config -g db_type        "$DB_TYPE"
    bench set-config -g redis_cache    "redis://redis-cache:6379"
    bench set-config -g redis_queue    "redis://redis-queue:6379"
    bench set-config -g redis_socketio "redis://redis-queue:6379"
    bench set-config -gp developer_mode "1"

    popd > /dev/null

    log_ok "Bench initialised."
}

# ── Step 2: Get selected apps ─────────────────────────────────────────────────

get_apps() {
    if [[ ! -f "$GET_APPS_SCRIPT" ]]; then
        log_err "get-apps.sh not found: $GET_APPS_SCRIPT"
        exit 1
    fi

    log_info "Fetching apps from: $SELECTED_APPS_CONFIG"
    BENCH_DIR="$BENCH_PATH" bash "$GET_APPS_SCRIPT" "$SELECTED_APPS_CONFIG"
    log_ok "Apps fetched."
}

# ── Step 3: Setup each site ───────────────────────────────────────────────────

setup_sites() {
    if [[ ! -f "$SETUP_SITE_SCRIPT" ]]; then
        log_err "setup-site.sh not found: $SETUP_SITE_SCRIPT"
        exit 1
    fi

    if [[ "${#SELECTED_SITE_CONFIGS[@]}" -eq 0 ]]; then
        log_err "No site configs selected."
        exit 1
    fi

    for config in "${SELECTED_SITE_CONFIGS[@]}"; do
        echo -e "\n${GREEN}════════════════════════════════════════${NC}"
        log_info "Setting up site from: $(basename "$config")"
        echo -e "${GREEN}════════════════════════════════════════${NC}"

        BENCH_DIR="$BENCH_PATH" \
        DB_TYPE="$DB_TYPE" \
        ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        bash "$SETUP_SITE_SCRIPT" "$config"
    done
}

# ── Step 4: Build assets & migrate ───────────────────────────────────────────

finalize() {
    pushd "$BENCH_PATH" > /dev/null

    log_info "Installing Node requirements..."
    bench setup requirements --node

    log_info "Building assets..."
    bench build

    log_info "Running migrations..."
    bench --site all migrate

    popd > /dev/null
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    configure_cli
    choose_site_mode

    if [[ "$SITE_MODE" == "configured" ]]; then
        choose_site_configs
        choose_site_config_app_mode

        if [[ "$SITE_CONFIG_APP_MODE" == "with_apps" ]]; then
            choose_apps
        fi
    fi

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Starting install"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    init_bench

    if [[ "$SITE_MODE" == "configured" ]]; then
        if [[ "$SITE_CONFIG_APP_MODE" == "with_apps" ]]; then
            get_apps
            setup_sites
        else
            create_clean_sites_from_configs
        fi
    else
        create_clean_site
    fi

    finalize

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "All done."
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"
}

main
