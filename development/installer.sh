#!/usr/bin/env bash
# installer.sh — interactive entrypoint.
#
# 1. Asks for bench settings
# 2. Lets you install all apps or select one/more apps from scripts/apps/apps.json,
#    independently of site creation
# 3. Initialises frappe-bench when needed
# 4. Optionally creates sites via setup-site.sh for every JSON file in scripts/sites/
# 5. Starts bench so initial setup can be completed manually
#
# The interactive logic lives in small modules under scripts/lib/:
#   prompts.sh — input helpers and the bench settings prompt
#   apps.sh    — app listing, app selection and the get-apps step
#   sites.sh   — site mode/config selection, site creation and the setup step
#   bench.sh   — bench init and bench start steps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="installer"

source "$SCRIPT_DIR/scripts/lib/common.sh"
source "$SCRIPT_DIR/scripts/lib/prompts.sh"
source "$SCRIPT_DIR/scripts/lib/apps.sh"
source "$SCRIPT_DIR/scripts/lib/sites.sh"
source "$SCRIPT_DIR/scripts/lib/bench.sh"

GET_APPS_SCRIPT="$SCRIPT_DIR/scripts/lib/get-apps.sh"
GET_APPS_CONFIG="$SCRIPT_DIR/scripts/apps/apps.json"
SITES_DIR="$SCRIPT_DIR/scripts/sites"
SETUP_SITE_SCRIPT="$SCRIPT_DIR/scripts/lib/setup-site.sh"

SELECTED_APPS_CONFIG="$GET_APPS_CONFIG"
APP_SELECTION_FILE=""
SITE_MODE="configured"
CLEAN_SITE_NAME="clean.localhost"
SELECTED_SITE_CONFIGS=()
SITE_CONFIG_APP_MODE="install"

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

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    configure_cli
    choose_apps
    choose_site_mode

    if [[ "$SITE_MODE" == "configured" ]]; then
        choose_site_configs
        choose_site_config_app_mode
    fi

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Starting install"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    init_bench

    case "$SITE_MODE" in
        configured)
            case "$SITE_CONFIG_APP_MODE" in
                install)
                    get_apps
                    setup_sites
                    ;;
                sites_only)
                    create_clean_sites_from_configs
                    ;;
            esac
            ;;
        apps_only)
            get_apps
            echo -e "\n${GREEN}════════════════════════════════════════${NC}"
            log_ok "Apps installed. No site was created."
            echo -e "${GREEN}════════════════════════════════════════${NC}\n"
            return
            ;;
        clean)
            create_clean_site
            ;;
    esac

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Install complete. Bench will start now."
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    start_bench
}

main
