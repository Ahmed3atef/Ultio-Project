#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-site.sh
#
# Creates a Frappe site and installs the apps defined in a JSON config file.
# Uses python3 for JSON parsing — no jq required.
#
# Usage:
#   BENCH_DIR=/path/to/bench \
#   DB_TYPE=mariadb \
#   ADMIN_PASSWORD=admin \
#   bash setup-site.sh /path/to/sites/aljar.json
#
# JSON format:
#   {
#     "site_name": "aljar.localhost",
#     "apps": [
#       { "name": "frappe",  "branch": "v15.64.0" },
#       { "name": "erpnext", "branch": "v15.64.0" }
#     ]
#   }
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Inputs ────────────────────────────────────────────────────────────────────

CONFIG_FILE="${1:-}"

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    echo "[setup-site] ERROR: config file not found: '$CONFIG_FILE'"
    exit 1
fi

CONFIG_FILE="$(realpath "$CONFIG_FILE")"
BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
DB_TYPE="${DB_TYPE:-mariadb}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
WAIT_FOR_INITIAL_SETUP="${WAIT_FOR_INITIAL_SETUP:-1}"

# ── JSON helpers via python3 (always available in frappe bench) ───────────────

# Extract a top-level string field from the JSON config
json_field() {
    python3 - "$CONFIG_FILE" "$1" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
val = data.get(sys.argv[2], "")
print(val if val else "")
PY
}

# Print "name<TAB>branch" for every entry in .apps[]
json_app_pairs() {
    python3 - "$CONFIG_FILE" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for app in data.get("apps", []):
    print(app["name"] + "\t" + app["branch"])
PY
}

json_app_branch() {
    python3 - "$CONFIG_FILE" "$1" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
target = sys.argv[2]
for app in data.get("apps", []):
    if app.get("name") == target:
        print(app.get("branch", ""))
        break
PY
}


SITE_NAME="$(json_field "site_name")"

if [[ -z "$SITE_NAME" ]]; then
    echo "[setup-site] ERROR: 'site_name' missing in $CONFIG_FILE"
    exit 1
fi

# ── Colors ────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[setup-site] $*${NC}"; }
log_ok()   { echo -e "${GREEN}[setup-site] ✔ $*${NC}"; }
log_err()  { echo -e "${RED}[setup-site] ✘ $*${NC}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

rollback_app() {
    local app="$1"
    log_err "Rolling back: $app"
    echo "y" | bench --site "$SITE_NAME" uninstall-app "$app" \
        --force --no-backup 2>&1 || true
    log_info "Rollback attempted for $app (errors above can be ignored if app was never registered)."
}

checkout_branch() {
    local app="$1"
    local branch="$2"

    if [[ ! -d "$APPS_DIR/$app" ]]; then
        log_err "App folder not found: $APPS_DIR/$app — run get-apps.sh first."
        exit 1
    fi

    log_info "Switching $app → $branch"
    git -C "$APPS_DIR/$app" checkout "$branch" || {
        log_err "Failed to checkout '$branch' for $app"
        exit 1
    }
    log_ok "On branch $branch"
}

install_app() {
    local app="$1"
    local branch="$2"

    echo -e "\n${YELLOW}────────────────────────────────────────${NC}"
    log_info "Installing: $app @ $branch"
    echo -e "${YELLOW}────────────────────────────────────────${NC}"

    checkout_branch "$app" "$branch"

    bench --site "$SITE_NAME" install-app "$app" || {
        log_err "Failed to install $app"
        rollback_app "$app"
        exit 1
    }

    log_ok "$app installed"
}

prepare_initial_setup_assets() {
    cd "$BENCH_DIR"

    log_info "Refreshing Node requirements for the checked-out app versions..."
    bench setup requirements --node

    local app
    for app in frappe erpnext hrms; do
        if [[ -d "$APPS_DIR/$app" ]]; then
            log_info "Building assets for $app..."
            bench build --app "$app"
        fi
    done

    bench --site "$SITE_NAME" clear-cache || true
}

# ── Manual initial setup ───────────────────────────────────────────────────────────────

manual_initial_setup() {
    if [[ "$WAIT_FOR_INITIAL_SETUP" != "1" ]]; then
        return
    fi

    cd "$BENCH_DIR"

    local bench_status=0
    local interrupted=false

    echo
    log_info "Starting bench for manual initial setup."
    log_info "Open: http://$SITE_NAME:8000"
    log_info "Complete the initial setup, then press Ctrl+C once to stop bench and resume app installation."

    manual_setup_interrupt() {
        interrupted=true
        log_info "Stopping bench and resuming installer..."
    }

    trap manual_setup_interrupt INT

    set +e
    bench start
    bench_status="$?"
    set -e

    trap - INT
    unset -f manual_setup_interrupt

    if [[ "$interrupted" == true ]]; then
        log_info "bench start was stopped by user."
    else
        log_info "bench start exited with status $bench_status."
    fi

    log_ok "Manual initial setup step finished; resuming app installation."
}

# ── Create site ───────────────────────────────────────────────────────────────

create_site() {
    cd "$BENCH_DIR"

    if [[ -d "$BENCH_DIR/sites/$SITE_NAME" ]]; then
        echo $BENCH_DIR
        log_info "Site already exists: $SITE_NAME — skipping creation."
        return
    fi

    local frappe_branch
    frappe_branch="$(json_app_branch "frappe")"
    if [[ -z "$frappe_branch" ]]; then
        log_err "frappe app missing in $CONFIG_FILE"
        exit 1
    fi
    checkout_branch "frappe" "$frappe_branch"

    log_info "Creating site: $SITE_NAME (db_type=$DB_TYPE)"

    local cmd=(
        bench new-site
        --db-root-username=root
        --db-root-password=123
        --db-type="$DB_TYPE"
        --admin-password="$ADMIN_PASSWORD"
        "$SITE_NAME"
    )

    if [[ "$DB_TYPE" == "mariadb" ]]; then
        bench set-config -g db_host "mariadb"
        cmd+=(--db-host="mariadb" --mariadb-user-host-login-scope=%)
    else
        bench set-config -g db_host "postgresql"
        cmd+=(--db-host="postgresql")
    fi

    "${cmd[@]}"
    log_ok "Site created: $SITE_NAME"
}

# ── Install all apps from JSON ────────────────────────────────────────────────

install_all_apps() {
    cd "$BENCH_DIR"

    log_info "Reading apps from: $(basename "$CONFIG_FILE")"

    local core_app branch

    for core_app in frappe erpnext hrms; do
        branch="$(json_app_branch "$core_app")"
        if [[ -z "$branch" ]]; then
            log_err "$core_app app missing in $CONFIG_FILE"
            exit 1
        fi

        install_app "$core_app" "$branch"
    done

    prepare_initial_setup_assets
    manual_initial_setup

    # json_app_pairs emits "name<TAB>branch" - read both fields in one loop
    while IFS=$'\t' read -r app branch; do
        case "$app" in
            frappe|erpnext|hrms) continue ;;
        esac

        install_app "$app" "$branch"
    done < <(json_app_pairs)

    log_info "Running migrations for $SITE_NAME..."
    bench --site "$SITE_NAME" migrate

    log_info "Refreshing Node requirements before final build..."
    bench setup requirements --node

    log_info "Building assets after app installation..."
    bench build
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
log_ok "Processing config: $(basename "$CONFIG_FILE")"
echo -e "${GREEN}════════════════════════════════════════${NC}"

create_site
install_all_apps

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
log_ok "Site ready: $SITE_NAME"
echo -e "${GREEN}════════════════════════════════════════${NC}\n"
