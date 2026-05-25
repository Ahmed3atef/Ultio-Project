#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-site.sh
#
# Creates a Frappe site and installs the apps defined in a JSON config file.
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

BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
DB_TYPE="${DB_TYPE:-mariadb}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

# ── Parse JSON (jq required) ──────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
    echo "[setup-site] ERROR: 'jq' is required but not installed."
    exit 1
fi

SITE_NAME="$(jq -r '.site_name' "$CONFIG_FILE")"

if [[ -z "$SITE_NAME" || "$SITE_NAME" == "null" ]]; then
    echo "[setup-site] ERROR: 'site_name' missing in $CONFIG_FILE"
    exit 1
fi

# ── Colors ────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${YELLOW}[setup-site] $*${NC}"; }
log_ok()    { echo -e "${GREEN}[setup-site] ✔ $*${NC}"; }
log_err()   { echo -e "${RED}[setup-site] ✘ $*${NC}"; }

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

# ── Create site ───────────────────────────────────────────────────────────────

create_site() {
    cd "$BENCH_DIR"

    if [[ -d "$BENCH_DIR/sites/$SITE_NAME" ]]; then
        log_info "Site already exists: $SITE_NAME — skipping creation."
        return
    fi

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

    local length
    length="$(jq '.apps | length' "$CONFIG_FILE")"

    log_info "Installing $length app(s) on $SITE_NAME"

    for i in $(seq 0 $((length - 1))); do
        local app branch
        app="$(jq -r ".apps[$i].name"   "$CONFIG_FILE")"
        branch="$(jq -r ".apps[$i].branch" "$CONFIG_FILE")"
        install_app "$app" "$branch"
    done
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