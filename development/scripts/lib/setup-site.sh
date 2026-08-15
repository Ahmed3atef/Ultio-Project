#!/usr/bin/env bash
# setup-site.sh — create a site from a JSON config and install its apps.
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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="setup-site"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/prompts.sh"

CONFIG_FILE="${1:-}"

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    log_err "config file not found: '$CONFIG_FILE'"
    exit 1
fi

CONFIG_FILE="$(realpath "$CONFIG_FILE")"

BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
DB_TYPE="${DB_TYPE:-mariadb}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
WAIT_FOR_INITIAL_SETUP="${WAIT_FOR_INITIAL_SETUP:-1}"

SITE_NAME="$(json_field "$CONFIG_FILE" "site_name")"
if [[ -z "$SITE_NAME" ]]; then
    log_err "'site_name' missing in $CONFIG_FILE"
    exit 1
fi

# ── App installation ──────────────────────────────────────────────────────────

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

    if ! bench --site "$SITE_NAME" install-app "$app"; then
        log_err "Failed to install $app"
        if prompt_yes_no "Roll back $app and abort the install? (No = skip $app and continue with the rest)" "false"; then
            rollback_app "$app"
            exit 1
        fi
        log_info "Skipping $app — continuing with the remaining apps."
        return
    fi

    log_ok "$app installed"
}

run_node_requirements_for_apps() {
    if [[ "$#" -eq 0 ]]; then
        log_info "No apps selected for Node requirements refresh."
        return
    fi

    log_info "Refreshing Node requirements for: $*"
    bench setup requirements --node "$@"
}

build_assets_for_apps() {
    local app
    for app in "$@"; do
        if [[ -d "$APPS_DIR/$app" ]]; then
            log_info "Building assets for $app..."
            bench build --app "$app"
        fi
    done
}

site_app_names() {
    json_app_pairs "$CONFIG_FILE" | while IFS=$'\t' read -r app _branch; do
        printf '%s\n' "$app"
    done
}

# ── Automated initial setup ───────────────────────────────────────────────────

initial_setup() {
    if [[ "$WAIT_FOR_INITIAL_SETUP" != "1" ]]; then
        return
    fi

    cd "$BENCH_DIR"

    local args_json
    args_json="$(json_setup_args "$CONFIG_FILE")"

    echo
    log_info "Running headless initial setup for $SITE_NAME (demo data enabled)."

    bench --site "$SITE_NAME" execute \
        frappe.desk.page.setup_wizard.setup_wizard.setup_complete \
        --args "$args_json"

    log_info "Draining demo data background job (bench worker, burst mode)..."
    bench worker --queue default --burst

    log_ok "Automated initial setup finished; resuming app installation."
}

# ── Site creation ─────────────────────────────────────────────────────────────

create_site() {
    cd "$BENCH_DIR"

    if [[ -d "$BENCH_DIR/sites/$SITE_NAME" ]]; then
        log_info "Site already exists: $SITE_NAME — skipping creation."
        return
    fi

    local frappe_branch
    frappe_branch="$(json_app_branch "$CONFIG_FILE" "frappe")"
    if [[ -z "$frappe_branch" ]]; then
        log_err "frappe app missing in $CONFIG_FILE"
        exit 1
    fi
    checkout_branch "frappe" "$frappe_branch"

    log_info "Creating site: $SITE_NAME (db_type=$DB_TYPE)"

    local cmd=()
    build_new_site_cmd cmd "$DB_TYPE" "$SITE_NAME" "$ADMIN_PASSWORD"
    "${cmd[@]}"
    log_ok "Site created: $SITE_NAME"
}

# ── Install all apps from JSON ────────────────────────────────────────────────

install_all_apps() {
    cd "$BENCH_DIR"

    log_info "Reading apps from: $(basename "$CONFIG_FILE")"

    local core_app branch app
    for core_app in frappe erpnext hrms; do
        branch="$(json_app_branch "$CONFIG_FILE" "$core_app")"
        if [[ -z "$branch" ]]; then
            log_err "$core_app app missing in $CONFIG_FILE"
            exit 1
        fi
        install_app "$core_app" "$branch"
    done

    initial_setup

    # json_app_pairs emits "name<TAB>branch" - read both fields in one loop
    while IFS=$'\t' read -r app branch; do
        case "$app" in
            frappe|erpnext|hrms) continue ;;
        esac
        install_app "$app" "$branch"
    done < <(json_app_pairs "$CONFIG_FILE")

    log_info "Running migrations for $SITE_NAME..."
    bench --site "$SITE_NAME" migrate

    mapfile -t site_apps < <(site_app_names)

    run_node_requirements_for_apps "${site_apps[@]}"
    build_assets_for_apps "${site_apps[@]}"
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
