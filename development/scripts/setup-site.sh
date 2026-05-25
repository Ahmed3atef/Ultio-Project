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

BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
DB_TYPE="${DB_TYPE:-mariadb}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

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

setup_wizard_args() {
    python3 << 'PY'
import json
import os
from datetime import date

year = date.today().year
args = {
    "language": os.environ.get("SETUP_LANGUAGE", "English"),
    "email": os.environ.get("SETUP_EMAIL", "test@erpnext.com"),
    "full_name": os.environ.get("SETUP_FULL_NAME", "Test User"),
    "password": os.environ.get("SETUP_PASSWORD", "test"),
    "country": os.environ.get("SETUP_COUNTRY", "United States"),
    "timezone": os.environ.get("SETUP_TIMEZONE", "America/New_York"),
    "currency": os.environ.get("SETUP_CURRENCY", "USD"),
    "company_name": os.environ.get("SETUP_COMPANY_NAME", "$Test Company"),
    "company_abbr": os.environ.get("SETUP_COMPANY_ABBR", "TC"),
    "industry": os.environ.get("SETUP_INDUSTRY", "Manufacturing"),
    "fy_start_date": os.environ.get("SETUP_FY_START_DATE", f"{year}-01-01"),
    "fy_end_date": os.environ.get("SETUP_FY_END_DATE", f"{year}-12-31"),
    "chart_of_accounts": os.environ.get("SETUP_CHART_OF_ACCOUNTS", "Standard"),
    "company_tagline": os.environ.get("SETUP_COMPANY_TAGLINE", ""),
}
print(json.dumps({"args": args}))
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

run_setup_wizard() {
    local kwargs

    log_info "Running setup wizard after frappe, erpnext, and hrms are installed"
    kwargs="$(setup_wizard_args)"
    bench --site "$SITE_NAME" execute \
        frappe.desk.page.setup_wizard.setup_wizard.setup_complete \
        --kwargs "$kwargs"
    log_ok "Setup wizard completed"
}

# ── Create site ───────────────────────────────────────────────────────────────

create_site() {
    cd "$BENCH_DIR"

    if [[ -d "$BENCH_DIR/sites/$SITE_NAME" ]]; then
        echo $BENCH_DIR
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

    log_info "Reading apps from: $(basename "$CONFIG_FILE")"

    # json_app_pairs emits "name<TAB>branch" — read both fields in one loop
    while IFS=$'\t' read -r app branch; do
        install_app "$app" "$branch"

        if [[ "$app" == "hrms" ]]; then
            run_setup_wizard
        fi
    done < <(json_app_pairs)

    bench --site "$SITE_NAME" migrate
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