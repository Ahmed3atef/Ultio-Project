#!/bin/bash
set -euo pipefail

SITE_NAME="${SITE_NAME:-aljar.localhost}"
BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"

cd "$BENCH_DIR" || exit 1

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

rollback_failed_app() {
    local FAILED_APP=$1

    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}ROLLING BACK FAILED APP: $FAILED_APP${NC}"
    echo -e "${RED}========================================${NC}"

    # Always attempt uninstall — even partial installs leave DB artifacts
    echo "y" | bench --site "$SITE_NAME" uninstall-app "$FAILED_APP" --force --no-backup 2>&1

    # Don't fail the script if uninstall itself errors (app may not be registered at all)
    echo -e "${YELLOW}⚠ Rollback attempted for $FAILED_APP (errors above, if any, can be ignored if app was never registered).${NC}"
    echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
}

install_app() {
    local APP_NAME=$1
    local BRANCH=$2

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Installing: $APP_NAME${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # Switch to the specified branch before installing
    if [ -d "$APPS_DIR/$APP_NAME" ]; then
        echo -e "${YELLOW}Switching $APP_NAME to branch: $BRANCH${NC}"
        git -C "$APPS_DIR/$APP_NAME" checkout "$BRANCH" || {
            echo -e "${RED}✘ Failed to checkout branch '$BRANCH' for: $APP_NAME${NC}"
            echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
            exit 1
        }
        echo -e "${GREEN}✔ Switched to branch: $BRANCH${NC}"
    else
        echo -e "${RED}✘ App folder not found: $APPS_DIR/$APP_NAME${NC}"
        echo -e "${RED}Run the get_apps script first.${NC}"
        exit 1
    fi

    bench --site "$SITE_NAME" install-app "$APP_NAME"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✔ $APP_NAME installed successfully${NC}"
    else
        echo -e "${RED}✘ Failed to install $APP_NAME${NC}"
        rollback_failed_app "$APP_NAME"
        exit 1
    fi
}

# Install apps in order — args: APP_NAME  BRANCH
install_app "frappe"                "v15.64.0"
install_app "erpnext"               "v15.64.0"
install_app "hrms"                  "v15.47.1"
install_app "erp_fabrica"           "stage"
install_app "fabrica_pwa"           "main"
install_app "hr_fabrica"            "develop"
install_app "zk_bio_device"         "master"
install_app "lending"               "version-15"
install_app "fabrica_accounting"    "develop"
install_app "fabrica_construction"  "develop"
install_app "crm_integration"       "develop"
install_app "aljar_system"          "develop"
install_app "learning_center"       "main"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All apps installed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"