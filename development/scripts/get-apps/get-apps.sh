#!/bin/bash

BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
APPS_TXT="$BENCH_DIR/sites/apps.txt"

cd "$BENCH_DIR" || exit 1

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_app() {
    local APP_NAME=$1
    local BRANCH=$2
    local REPO_URL=$3

    local FOLDER_NAME
    if [ -z "$REPO_URL" ]; then
        REPO_URL="https://github.com/frappe/${APP_NAME}.git"
        FOLDER_NAME="$APP_NAME"
    else
        FOLDER_NAME=$(basename "$REPO_URL" .git)
    fi

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}GETTING APP: $FOLDER_NAME${NC}"
    echo -e "${YELLOW}========================================${NC}"

    if [ -d "$APPS_DIR/$FOLDER_NAME" ]; then
        echo -e "${YELLOW}⚠ App '$FOLDER_NAME' already exists. Checking fetch refspec...${NC}"

        # Fix refspec if it's limited to a single branch
        CURRENT_REFSPEC=$(git -C "$APPS_DIR/$FOLDER_NAME" config --get remote.origin.fetch)
        if [ "$CURRENT_REFSPEC" != "+refs/heads/*:refs/remotes/origin/*" ]; then
            echo -e "${YELLOW}Fixing refspec: '$CURRENT_REFSPEC' → '+refs/heads/*:refs/remotes/origin/*'${NC}"
            git -C "$APPS_DIR/$FOLDER_NAME" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
            git -C "$APPS_DIR/$FOLDER_NAME" fetch --all
            if [ $? -ne 0 ]; then
                echo -e "${RED}✘ Failed to fetch all branches for: $FOLDER_NAME${NC}"
                exit 1
            fi
            echo -e "${GREEN}✔ Refspec fixed and all branches fetched${NC}"
        else
            echo -e "${GREEN}✔ Refspec already correct.${NC}"
        fi

        # Checkout the desired branch if provided
        if [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
            echo -e "${YELLOW}Switching to branch: $BRANCH${NC}"
            git -C "$APPS_DIR/$FOLDER_NAME" checkout "$BRANCH"
            if [ $? -ne 0 ]; then
                echo -e "${RED}✘ Failed to checkout branch '$BRANCH' for: $FOLDER_NAME${NC}"
                exit 1
            fi
        fi

    else
        # Fresh clone — full repo with all branches
        echo -e "${YELLOW}Cloning $FOLDER_NAME (all branches)...${NC}"
        git clone "$REPO_URL" "$APPS_DIR/$FOLDER_NAME"

        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Failed to clone: $FOLDER_NAME${NC}"
            echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
            exit 1
        fi

        # Checkout specific branch if provided
        if [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
            echo -e "${YELLOW}Checking out branch: $BRANCH${NC}"
            git -C "$APPS_DIR/$FOLDER_NAME" checkout "$BRANCH"
            if [ $? -ne 0 ]; then
                echo -e "${RED}✘ Failed to checkout branch '$BRANCH' for: $FOLDER_NAME${NC}"
                echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
                exit 1
            fi
        fi

        # Install the Python package
        echo -e "${YELLOW}Installing $FOLDER_NAME into bench (pip)...${NC}"
        cd "$BENCH_DIR" && bench pip install -e "apps/$FOLDER_NAME"

        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Failed pip install: $FOLDER_NAME${NC}"
            echo -e "${RED}Stopping script. Fix the error and re-run.${NC}"
            exit 1
        fi

        # Register app in apps.txt if not already there
        if ! grep -qx "$FOLDER_NAME" "$APPS_TXT"; then
            # Ensure the file ends with a newline before appending
            # (bench creates apps.txt with just "frappe" and no trailing newline)
            if [ -s "$APPS_TXT" ] && [ "$(tail -c1 "$APPS_TXT" | wc -l)" -eq 0 ]; then
                echo "" >> "$APPS_TXT"  # Add the missing newline first
            fi
            echo "$FOLDER_NAME" >> "$APPS_TXT"
            echo -e "${GREEN}✔ Added '$FOLDER_NAME' to apps.txt${NC}"
        else
            echo -e "${YELLOW}⚠ '$FOLDER_NAME' already in apps.txt. Skipping.${NC}"
        fi

        echo -e "${GREEN}✔ $FOLDER_NAME done${NC}"
    fi
}

# ── Public apps (URL auto-derived from frappe GitHub org) ────────────────────
get_app "frappe"   "version-15"
get_app "erpnext"  "version-15"
get_app "hrms"     "version-15"
get_app "lending"  "version-15"
get_app "insights" "version-3"
get_app "" "main"   "https://github.com/iptelephony/persona.git"

# ── Private apps (SSH URL passed explicitly) ──────────────────────────────────
get_app "" "stage"   "git@git.fabrica-dev.com:frappe_erp/erp_fabrica.git"
get_app "" "main"    "git@git.fabrica-dev.com:frappe_erp/fabrica_pwa.git"
get_app "" "main"    "git@git.fabrica-dev.com:frappe_erp/alerts.git"
get_app "" "master"  "git@git.fabrica-dev.com:frappe_erp/mail_job_application.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/hr_fabrica.git"
get_app "" "main"    "git@git.fabrica-dev.com:frappe_erp/bio_time_software.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/alqamzi_system.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/fabrica_factoring.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/fabrica_leasing.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/child_table_pagination.git"
get_app "" "main"    "git@git.fabrica-dev.com:frappe_erp/learning_center.git"
get_app "" "master"  "git@git.fabrica-dev.com:frappe_erp/zk_bio_device.git"
get_app "" "develop"  "git@git.fabrica-dev.com:frappe_erp/fabrica_accounting.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/fabrica_construction.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/crm_integration.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/aljar_system.git"
get_app "" "stage"  "git@git.fabrica-dev.com:frappe_erp/fabrica_pos_awesome.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/fabrica_pos_awesome.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/biography_erp.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/coverage_erp.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/imarrae_system.git"
get_app "" "main"    "git@git.fabrica-dev.com:frappe_erp/salary_tax_eg.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/kunouz_erp.git"
get_app "" "develop" "git@git.fabrica-dev.com:frappe_erp/biography_erp.git"



echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All apps fetched and registered successfully!${NC}"
echo -e "${GREEN}Now run your site installation script.${NC}"
echo -e "${GREEN}========================================${NC}"