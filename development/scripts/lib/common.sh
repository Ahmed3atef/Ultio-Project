#!/usr/bin/env bash
# common.sh — shared helpers for installer.sh, get-apps.sh and setup-site.sh.
#
# Responsibilities:
#   - colored logging with a per-script LOG_PREFIX
#   - python3 based JSON readers for the apps/site config files
#   - the bench new-site command builder shared by all site creation paths
#
# Each script must set LOG_PREFIX before sourcing this file.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_PREFIX="${LOG_PREFIX:-}"

# ── Logging ───────────────────────────────────────────────────────────────────

_log() {
    local color="$1"
    shift
    if [[ -n "$LOG_PREFIX" ]]; then
        echo -e "${color}[${LOG_PREFIX}] $*${NC}"
    else
        echo -e "${color}$*${NC}"
    fi
}

log_info() { _log "$YELLOW" "$*"; }
log_ok()   { _log "$GREEN" "✔ $*"; }
log_err()  { _log "$RED" "✘ $*"; }

# ── JSON helpers (python3, no jq required) ────────────────────────────────────

# json_field CONFIG_FILE FIELD — prints a top-level string field (or "").
json_field() {
    local config_file="$1"
    local field="$2"
    python3 - "$config_file" "$field" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print(data.get(sys.argv[2], ""))
PY
}

# json_app_pairs CONFIG_FILE — prints "name<TAB>branch" for every .apps[] entry.
json_app_pairs() {
    local config_file="$1"
    python3 - "$config_file" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for app in data.get("apps", []):
    print(app.get("name", "") + "\t" + app.get("branch", ""))
PY
}

# json_app_branch CONFIG_FILE APP — prints the branch of the named app (or "").
json_app_branch() {
    local config_file="$1"
    local target="$2"
    python3 - "$config_file" "$target" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
target = sys.argv[2]
for app in data.get("apps", []):
    if app.get("name") == target:
        print(app.get("branch", ""))
        break
PY
}

# json_setup_args CONFIG_FILE — prints the wizard args JSON (a list) for the
# automated initial setup. fy dates are derived from the country like the
# erpnext wizard does; demo data is enabled (setup_demo=1).
json_setup_args() {
    local config_file="$1"
    python3 - "$config_file" << 'PY'
import json, sys
from datetime import date

data = json.load(open(sys.argv[1]))
setup = data.get("setup", {})

country = setup.get("country", "Egypt")
fy = {
    "Australia": ("07-01", "06-30"),
    "Bangladesh": ("07-01", "06-30"),
    "Costa Rica": ("10-01", "09-30"),
    "Egypt": ("07-01", "06-30"),
    "Ethiopia": ("07-08", "07-07"),
    "Hong Kong": ("04-01", "03-31"),
    "India": ("04-01", "03-31"),
    "Iran": ("06-23", "06-22"),
    "Kenya": ("07-01", "06-30"),
    "Malaysia": ("07-01", "06-30"),
    "Myanmar": ("04-01", "03-31"),
    "Nepal": ("07-16", "07-15"),
    "New Zealand": ("04-01", "03-31"),
    "Pakistan": ("07-01", "06-30"),
    "Singapore": ("04-01", "03-31"),
    "South Africa": ("03-01", "02-28"),
    "Thailand": ("10-01", "09-30"),
    "United Kingdom": ("04-01", "03-31"),
    "United States": ("01-01", "12-31"),
}.get(country, ("01-01", "12-31"))

current_year = date.today().year
next_year = current_year + 1
year_start_date = f"{current_year}-{fy[0]}"
if year_start_date > date.today().isoformat():
    next_year = current_year
    current_year -= 1

args = {
    "language": setup.get("language", "English"),
    "country": country,
    "currency": setup.get("currency", "EGP"),
    "timezone": setup.get("timezone", "Africa/Cairo"),
    "full_name": setup.get("full_name", "Admin"),
    "email": setup.get("email", "admin@localhost"),
    "password": setup.get("password", "admin"),
    "company_name": setup.get("company_name", ""),
    "company_abbr": setup.get("company_abbr", ""),
    "chart_of_accounts": setup.get("chart_of_accounts", "Standard"),
    "domain": setup.get("domain", ""),
    "fy_start_date": f"{current_year}-{fy[0]}",
    "fy_end_date": f"{next_year}-{fy[1]}",
    "enable_telemetry": 0,
    "allow_recording_first_session": 0,
    "setup_demo": 1,
}
print(json.dumps([args]))
PY
}

# ── Bench site creation ───────────────────────────────────────────────────────

# build_new_site_cmd OUT_VAR DB_TYPE SITE_NAME ADMIN_PASSWORD
#   Configures the global db_host for DB_TYPE and fills OUT_VAR (nameref) with
#   the bench new-site argv, including the mariadb/postgresql specific flags.
build_new_site_cmd() {
    local -n _cmd="$1"
    local db_type="$2"
    local site_name="$3"
    local admin_password="$4"

    _cmd=(bench new-site
        --db-root-username=root
        --db-root-password=123
        --db-type="$db_type"
        --admin-password="$admin_password"
        "$site_name"
    )

    if [[ "$db_type" == "mariadb" ]]; then
        bench set-config -g db_host "mariadb"
        if bench new-site --help | grep -q -- "--mariadb-user-host-login-scope"; then
            _cmd+=(--db-host="mariadb" --mariadb-user-host-login-scope=%)
        elif bench new-site --help | grep -q -- "--no-mariadb-socket"; then
            _cmd+=(--db-host="mariadb" --no-mariadb-socket)
        else
            _cmd+=(--db-host="mariadb")
        fi
    else
        bench set-config -g db_host "postgresql"
        _cmd+=(--db-host="postgresql")
    fi
}
