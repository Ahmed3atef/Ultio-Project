#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_CONFIG="${1:-$SCRIPT_DIR/apps.json}"
BENCH_DIR="${BENCH_DIR:-/workspace/development/frappe-bench}"
APPS_DIR="$BENCH_DIR/apps"
APPS_TXT="$BENCH_DIR/sites/apps.txt"

cd "$BENCH_DIR" || exit 1

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ ! -f "$APPS_CONFIG" ]]; then
    echo -e "${RED}✘ Apps JSON not found: $APPS_CONFIG${NC}"
    exit 1
fi

app_rows() {
    python3 - "$APPS_CONFIG" << 'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
apps = data.get("apps", data if isinstance(data, list) else [])

for app in apps:
    name = app.get("name") or ""
    branch = app.get("branch") or ""
    url = app.get("url") or app.get("repo_url") or ""
    print("\x1f".join([name, branch, url]))
PY
}

# ─────────────────────────────────────────────────────────────────────────────
# get_app APP_NAME BRANCH [REPO_URL]
#
#  No REPO_URL  -> bench get-app APP_NAME --branch BRANCH
#                 Then expand refspec + fetch all branches & tags.
#                 Checkout is handled by a separate site-install script.
#
#  REPO_URL     -> git clone REPO_URL (default branch, no -b flag)
#                 Then pip install + register in apps.txt.
#
#  App already exists -> fix refspec + fetch all branches & tags. No checkout.
# ─────────────────────────────────────────────────────────────────────────────
get_app() {
    local APP_NAME="${1:-}"
    local BRANCH="${2:-}"
    local REPO_URL="${3:-}"

    local FOLDER_NAME
    if [[ -z "$REPO_URL" ]]; then
        FOLDER_NAME="$APP_NAME"
    else
        FOLDER_NAME=$(basename "$REPO_URL" .git)
    fi

    if [[ -z "$FOLDER_NAME" ]]; then
        echo -e "${YELLOW}⚠ Skipping app entry with empty name and empty url.${NC}"
        return
    fi

    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}GETTING APP: $FOLDER_NAME${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # ── App directory already present (e.g. frappe pre-installed by bench) ───
    if [[ -d "$APPS_DIR/$FOLDER_NAME" ]]; then
        echo -e "${YELLOW}⚠ App '$FOLDER_NAME' already exists. Fixing refspec and fetching all branches/tags...${NC}"

        # bench init uses 'upstream' as remote name; manual clones use 'origin'
        if git -C "$APPS_DIR/$FOLDER_NAME" remote get-url upstream &>/dev/null; then
            REMOTE_NAME="upstream"
        else
            REMOTE_NAME="origin"
        fi

        CURRENT_REFSPEC=$(git -C "$APPS_DIR/$FOLDER_NAME" config --get remote.${REMOTE_NAME}.fetch || true)
        if [[ "$CURRENT_REFSPEC" != "+refs/heads/*:refs/remotes/${REMOTE_NAME}/*" ]]; then
            echo -e "${YELLOW}Fixing refspec: '$CURRENT_REFSPEC' -> '+refs/heads/*:refs/remotes/${REMOTE_NAME}/*'${NC}"
            git -C "$APPS_DIR/$FOLDER_NAME" config remote.${REMOTE_NAME}.fetch "+refs/heads/*:refs/remotes/${REMOTE_NAME}/*"
        else
            echo -e "${GREEN}✔ Refspec already correct.${NC}"
        fi

        git -C "$APPS_DIR/$FOLDER_NAME" fetch ${REMOTE_NAME} --tags
        echo -e "${GREEN}✔ All branches and tags fetched for $FOLDER_NAME${NC}"
        return
    fi

    # ── Fresh install ─────────────────────────────────────────────────────────

    if [[ -z "$REPO_URL" ]]; then
        # ── App name only: bench get-app with explicit branch when provided ───
        if [[ -n "$BRANCH" ]]; then
            echo -e "${YELLOW}Running: bench get-app $APP_NAME --branch $BRANCH${NC}"
            bench get-app "$APP_NAME" --branch "$BRANCH"
        else
            echo -e "${YELLOW}Running: bench get-app $APP_NAME${NC}"
            bench get-app "$APP_NAME"
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
        echo -e "${GREEN}✔ $APP_NAME installed with all branches/tags fetched${NC}"

    else
        # ── URL provided: clone default branch, no -b flag ────────────────────
        echo -e "${YELLOW}Cloning $FOLDER_NAME from: $REPO_URL (default branch)${NC}"
        git clone "$REPO_URL" "$APPS_DIR/$FOLDER_NAME"

        # Install Python package
        echo -e "${YELLOW}Installing $FOLDER_NAME into bench (pip)...${NC}"
        cd "$BENCH_DIR" && bench pip install -e "apps/$FOLDER_NAME"

        # Register in apps.txt
        if ! grep -qx "$FOLDER_NAME" "$APPS_TXT"; then
            if [[ -s "$APPS_TXT" ]] && [[ "$(tail -c1 "$APPS_TXT" | wc -l)" -eq 0 ]]; then
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

while IFS=$'\x1f' read -r app branch url; do
    get_app "$app" "$branch" "$url"
done < <(app_rows)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All selected apps fetched and registered successfully!${NC}"
echo -e "${GREEN}Now run your site installation script.${NC}"
echo -e "${GREEN}========================================${NC}"
