#!/usr/bin/env bash
# apps.sh — app listing, app selection and the get-apps step.
#
# Reads/writes the globals set by installer.sh (GET_APPS_CONFIG,
# SELECTED_APPS_CONFIG, APP_SELECTION_FILE, GET_APPS_SCRIPT, BENCH_PATH).

app_label_rows() {
    python3 - "$GET_APPS_CONFIG" << 'PY'
import json
import os
import sys
from urllib.parse import urlparse

def folder_name(app):
    name = app.get("name") or ""
    url = app.get("url") or app.get("repo_url") or ""
    if name:
        return name
    if not url:
        return "<empty>"
    path = urlparse(url).path if "://" in url else url.rsplit(":", 1)[-1]
    return os.path.basename(path).removesuffix(".git")

data = json.load(open(sys.argv[1]))
apps = data.get("apps", data if isinstance(data, list) else [])
for index, app in enumerate(apps, start=1):
    name = folder_name(app)
    branch = app.get("branch") or "default"
    url = app.get("url") or app.get("repo_url") or "bench get-app"
    print(f"{index:2d}) {name:<28} {branch:<12} {url}")
PY
}

choose_apps() {
    local mode selection

    if [[ ! -f "$GET_APPS_CONFIG" ]]; then
        log_err "Apps JSON not found: $GET_APPS_CONFIG"
        exit 1
    fi

    echo -e "\n${YELLOW}Apps to fetch${NC}"
    echo "1) All apps from apps.json"
    echo "2) Select one or more apps"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|all|a)
                SELECTED_APPS_CONFIG="$GET_APPS_CONFIG"
                log_ok "Selected all apps."
                return
                ;;
            2|select|s)
                break
                ;;
            *) echo "Choose 1 for all apps or 2 to select apps." ;;
        esac
    done

    echo
    app_label_rows
    echo
    echo "Enter numbers separated by spaces or commas. Example: 1 2 7,10"
    echo "Type 'all' to use the full list."

    while true; do
        read -r -p "Apps: " selection
        selection="${selection:-}"

        if [[ "${selection,,}" == "all" ]]; then
            SELECTED_APPS_CONFIG="$GET_APPS_CONFIG"
            log_ok "Selected all apps."
            return
        fi

        if [[ -z "$selection" ]]; then
            echo "Pick at least one app, or type all."
            continue
        fi

        APP_SELECTION_FILE="$(mktemp /tmp/get-apps-selected.XXXXXX.json)"
        if python3 - "$GET_APPS_CONFIG" "$APP_SELECTION_FILE" "$selection" << 'PY'
import json
import sys

source, target, raw_selection = sys.argv[1:4]
data = json.load(open(source))
apps = data.get("apps", data if isinstance(data, list) else [])
selected = []
seen = set()
errors = []

for token in raw_selection.replace(",", " ").split():
    if not token.isdigit():
        errors.append(token)
        continue
    index = int(token)
    if index < 1 or index > len(apps):
        errors.append(token)
        continue
    if index not in seen:
        selected.append(apps[index - 1])
        seen.add(index)

if errors:
    print("Invalid selection: " + ", ".join(errors), file=sys.stderr)
    sys.exit(1)
if not selected:
    print("No apps selected.", file=sys.stderr)
    sys.exit(1)

with open(target, "w") as handle:
    json.dump({"apps": selected}, handle, indent=2)
    handle.write("\n")
PY
        then
            SELECTED_APPS_CONFIG="$APP_SELECTION_FILE"
            log_ok "Selected app list prepared."
            return
        fi

        rm -f "$APP_SELECTION_FILE"
        APP_SELECTION_FILE=""
    done
}

get_apps() {
    if [[ ! -f "$GET_APPS_SCRIPT" ]]; then
        log_err "get-apps.sh not found: $GET_APPS_SCRIPT"
        exit 1
    fi

    log_info "Fetching apps from: $SELECTED_APPS_CONFIG"
    BENCH_DIR="$BENCH_PATH" bash "$GET_APPS_SCRIPT" "$SELECTED_APPS_CONFIG"
    log_ok "Apps fetched."
}
