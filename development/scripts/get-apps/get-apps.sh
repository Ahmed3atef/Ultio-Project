#!/bin/bash

BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
APPS_TXT="$BENCH_DIR/sites/apps.txt"

cd "$BENCH_DIR" || exit 1

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# get_app APP_NAME BRANCH [REPO_URL]
#
#  No REPO_URL  → bench get-app APP_NAME --branch BRANCH
#                 Then expand refspec + fetch all branches & tags.
#                 Checkout is handled by a separate site-install script.
#
#  REPO_URL     → git clone REPO_URL (default branch, no -b flag)
#                 Then pip install + register in apps.txt.
#
#  App already exists → fix refspec + fetch all branches & tags. No checkout.
# ─────────────────────────────────────────────────────────────────────────────
get_app() {
    local APP_NAME=$1
    local BRANCH=$2
    local REPO_URL=$3

    local FOLDER_NAME
    if [ -z "$REPO_URL" ]; then
        FOLDER_NAME="$APP_NAME"
    else
        FOLDER_NAME=$(basename "$REPO_URL" .git)
    fi

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}GETTING APP: $FOLDER_NAME${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # ── App directory already present (e.g. frappe pre-installed by bench) ───
    if [ -d "$APPS_DIR/$FOLDER_NAME" ]; then
        echo -e "${YELLOW}⚠ App '$FOLDER_NAME' already exists. Fixing refspec and fetching all branches/tags...${NC}"

        # bench init uses 'upstream' as remote name; manual clones use 'origin'
        if git -C "$APPS_DIR/$FOLDER_NAME" remote get-url upstream &>/dev/null; then
            REMOTE_NAME="upstream"
        else
            REMOTE_NAME="origin"
        fi

        CURRENT_REFSPEC=$(git -C "$APPS_DIR/$FOLDER_NAME" config --get remote.${REMOTE_NAME}.fetch)
        if [ "$CURRENT_REFSPEC" != "+refs/heads/*:refs/remotes/${REMOTE_NAME}/*" ]; then
            echo -e "${YELLOW}Fixing refspec: '$CURRENT_REFSPEC' → '+refs/heads/*:refs/remotes/${REMOTE_NAME}/*'${NC}"
            git -C "$APPS_DIR/$FOLDER_NAME" config remote.${REMOTE_NAME}.fetch "+refs/heads/*:refs/remotes/${REMOTE_NAME}/*"
        else
            echo -e "${GREEN}✔ Refspec already correct.${NC}"
        fi

        git -C "$APPS_DIR/$FOLDER_NAME" fetch ${REMOTE_NAME} --tags
        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Failed to fetch all branches/tags for: $FOLDER_NAME${NC}"
            exit 1
        fi
        echo -e "${GREEN}✔ All branches and tags fetched for $FOLDER_NAME${NC}"
        return
    fi

    # ── Fresh install ─────────────────────────────────────────────────────────

    if [ -z "$REPO_URL" ]; then
        # ── App name only: bench get-app with explicit branch ─────────────────
        echo -e "${YELLOW}Running: bench get-app $APP_NAME --branch $BRANCH${NC}"
        bench get-app "$APP_NAME" --branch "$BRANCH"

        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ bench get-app failed for: $APP_NAME${NC}"
            echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
            exit 1
        fi

        # bench get-app clones with a shallow single-branch refspec — expand it
        echo -e "${YELLOW}Expanding refspec to fetch all branches and tags...${NC}"

        if git -C "$APPS_DIR/$FOLDER_NAME" remote get-url upstream &>/dev/null; then
            REMOTE_NAME="upstream"
        else
            REMOTE_NAME="origin"
        fi

        git -C "$APPS_DIR/$FOLDER_NAME" config remote.${REMOTE_NAME}.fetch "+refs/heads/*:refs/remotes/${REMOTE_NAME}/*"
        git -C "$APPS_DIR/$FOLDER_NAME" fetch ${REMOTE_NAME} --tags
        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Failed to fetch all branches/tags for: $APP_NAME${NC}"
            exit 1
        fi
        echo -e "${GREEN}✔ $APP_NAME installed on branch $BRANCH with all branches/tags fetched${NC}"

    else
        # ── URL provided: clone default branch, no -b flag ────────────────────
        echo -e "${YELLOW}Cloning $FOLDER_NAME from: $REPO_URL (default branch)${NC}"
        git clone "$REPO_URL" "$APPS_DIR/$FOLDER_NAME"

        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Failed to clone: $FOLDER_NAME${NC}"
            echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
            exit 1
        fi

        # Install Python package
        echo -e "${YELLOW}Installing $FOLDER_NAME into bench (pip)...${NC}"
        cd "$BENCH_DIR" && bench pip install -e "apps/$FOLDER_NAME"

        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Failed pip install: $FOLDER_NAME${NC}"
            echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
            exit 1
        fi

        # Register in apps.txt
        if ! grep -qx "$FOLDER_NAME" "$APPS_TXT"; then
            if [ -s "$APPS_TXT" ] && [ "$(tail -c1 "$APPS_TXT" | wc -l)" -eq 0 ]; then
                echo "" >> "$APPS_TXT"
            fi
            echo "$FOLDER_NAME" >> "$APPS_TXT"
            echo -e "${GREEN}✔ Added '$FOLDER_NAME' to apps.txt${NC}"
        else
            echo -e "${YELLOW}⚠ '$FOLDER_NAME' already in apps.txt. Skipping.${NC}"
        fi

        echo -e "${GREEN}✔ $FOLDER_NAME done (default branch)${NC}"
    fi
}

# ── Public apps — bench get-app with explicit branch ─────────────────────────
get_app "frappe"   "version-15"
get_app "erpnext"  "version-15"
get_app "hrms"     "version-15"
get_app "lending"  "version-15"
get_app "insights" "version-3"

# ── Public HTTPS — clone default branch ──────────────────────────────────────
get_app "" "" "https://github.com/iptelephony/persona.git"

# ── Private SSH — clone default branch ───────────────────────────────────────
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/erp_fabrica.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/fabrica_pwa.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/alerts.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/mail_job_application.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/hr_fabrica.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/bio_time_software.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/alqamzi_system.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/fabrica_factoring.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/fabrica_leasing.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/child_table_pagination.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/learning_center.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/zk_bio_device.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/fabrica_accounting.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/fabrica_construction.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/crm_integration.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/aljar_system.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/fabrica_pos_awesome.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/biography_erp.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/coverage_erp.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/imarrae_system.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/salary_tax_eg.git"
get_app "" "" "git@git.fabrica-dev.com:frappe_erp/kunouz_erp.git"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All apps fetched and registered successfully!${NC}"
echo -e "${GREEN}Now run your site installation script.${NC}"
echo -e "${GREEN}========================================${NC}"