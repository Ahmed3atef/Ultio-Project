#!/bin/bash
set -euo pipefail

SITE_NAME="${SITE_NAME:-alqamzi.localhost}"
BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"

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

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Installing: $APP_NAME${NC}"
    echo -e "${YELLOW}========================================${NC}"

    bench --site "$SITE_NAME" install-app "$APP_NAME"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✔ $APP_NAME installed successfully${NC}"
    else
        echo -e "${RED}✘ Failed to install $APP_NAME${NC}"
        rollback_failed_app "$APP_NAME"
        exit 1
    fi
}

# Install apps in order
install_app "erpnext"
install_app "hrms"
install_app "erp_fabrica"
install_app "fabrica_pwa"
install_app "mail_job_application"
install_app "fabrica_accounting"
install_app "fabrica_construction"
install_app "hr_fabrica"
install_app "bio_time_software"
install_app "lending"
install_app "alqamzi_system"
install_app "fabrica_factoring"
install_app "fabrica_leasing"
install_app "child_table_pagination"
install_app "learning_center"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All apps installed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"