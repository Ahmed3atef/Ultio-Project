#!/usr/bin/env bash
# sites.sh — site mode/config selection, site creation and the site setup step.
#
# Reads/writes the globals set by installer.sh (SITES_DIR, SITE_MODE,
# CLEAN_SITE_NAME, SELECTED_SITE_CONFIGS, SITE_CONFIG_APP_MODE, BENCH_PATH,
# DB_TYPE, ADMIN_PASSWORD, SETUP_SITE_SCRIPT).

choose_site_mode() {
    local mode

    echo -e "\n${YELLOW}What to set up${NC}"
    echo "1) Use site JSON configs from scripts/sites (install the selected apps on each site)"
    echo "2) Create one clean site (no app installs)"
    echo "3) Install the selected apps only (no site creation)"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|configured|config|c)
                SITE_MODE="configured"
                log_ok "Selected site JSON config mode."
                return
                ;;
            2|clean)
                SITE_MODE="clean"
                CLEAN_SITE_NAME="$(prompt_value "Clean site name" "$CLEAN_SITE_NAME")"
                log_ok "Selected clean site: $CLEAN_SITE_NAME"
                return
                ;;
            3|apps|apps-only|no-sites)
                SITE_MODE="apps_only"
                log_ok "Selected apps-only mode (no site creation)."
                return
                ;;
            *) echo "Choose 1 for site configs, 2 for a clean site, or 3 for apps only." ;;
        esac
    done
}

site_config_rows() {
    local index=1
    local config

    for config in "$SITES_DIR"/*.json; do
        [[ -f "$config" ]] || continue
        printf "%2d) %s\n" "$index" "$(basename "$config")"
        index=$((index + 1))
    done
}

choose_site_configs() {
    local mode selection
    local configs=()
    local config

    if [[ ! -d "$SITES_DIR" ]]; then
        log_err "Sites config directory not found: $SITES_DIR"
        exit 1
    fi

    for config in "$SITES_DIR"/*.json; do
        [[ -f "$config" ]] || continue
        configs+=("$config")
    done

    if [[ "${#configs[@]}" -eq 0 ]]; then
        log_err "No JSON configs found in: $SITES_DIR"
        exit 1
    fi

    echo -e "\n${YELLOW}Site configs${NC}"
    echo "1) All site configs"
    echo "2) Select one or more site configs"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|all|a)
                SELECTED_SITE_CONFIGS=("${configs[@]}")
                log_ok "Selected all site configs."
                return
                ;;
            2|select|s)
                break
                ;;
            *) echo "Choose 1 for all site configs or 2 to select configs." ;;
        esac
    done

    echo
    site_config_rows
    echo
    echo "Enter numbers separated by spaces or commas. Example: 1 3,5"
    echo "Type 'all' to use the full list."

    while true; do
        local selected=()
        local seen=" "
        local token index
        local invalid=false

        read -r -p "Site configs: " selection
        selection="${selection:-}"

        if [[ "${selection,,}" == "all" ]]; then
            SELECTED_SITE_CONFIGS=("${configs[@]}")
            log_ok "Selected all site configs."
            return
        fi

        if [[ -z "$selection" ]]; then
            echo "Pick at least one site config, or type all."
            continue
        fi

        for token in ${selection//,/ }; do
            if [[ ! "$token" =~ ^[0-9]+$ ]]; then
                echo "Invalid selection: $token"
                invalid=true
                break
            fi

            index=$((token - 1))
            if (( index < 0 || index >= ${#configs[@]} )); then
                echo "Invalid selection: $token"
                invalid=true
                break
            fi

            if [[ "$seen" != *" $token "* ]]; then
                selected+=("${configs[$index]}")
                seen+="$token "
            fi
        done

        if [[ "$invalid" == true ]]; then
            continue
        fi

        if [[ "${#selected[@]}" -eq 0 ]]; then
            echo "No site configs selected."
            continue
        fi

        SELECTED_SITE_CONFIGS=("${selected[@]}")
        log_ok "Selected ${#SELECTED_SITE_CONFIGS[@]} site config(s)."
        return
    done
}

choose_site_config_app_mode() {
    local mode

    echo -e "\n${YELLOW}Selected site configs${NC}"
    echo "1) Create sites and install apps listed in each site JSON"
    echo "2) Create sites only (no app installs)"

    while true; do
        read -r -p "Choose an option [1]: " mode
        mode="${mode:-1}"
        case "$mode" in
            1|install|apps)
                SITE_CONFIG_APP_MODE="install"
                log_ok "Selected app-install mode for site configs."
                return
                ;;
            2|clean|sites-only|no-apps)
                SITE_CONFIG_APP_MODE="sites_only"
                log_ok "Selected sites-only mode for site configs."
                return
                ;;
            *) echo "Choose 1 to install apps, or 2 to create sites only." ;;
        esac
    done
}

site_name_from_config() {
    json_field "$1" "site_name"
}

create_site_by_name() {
    local site_name="$1"

    pushd "$BENCH_PATH" > /dev/null

    if [[ -d "$BENCH_PATH/sites/$site_name" ]]; then
        log_info "Site already exists: $site_name — skipping creation."
        popd > /dev/null
        return
    fi

    log_info "Creating site: $site_name (db_type=$DB_TYPE)"

    local cmd=()
    build_new_site_cmd cmd "$DB_TYPE" "$site_name" "$ADMIN_PASSWORD"
    "${cmd[@]}"
    log_ok "Site created: $site_name"

    popd > /dev/null
}

create_clean_sites_from_configs() {
    local config site_name

    if [[ "${#SELECTED_SITE_CONFIGS[@]}" -eq 0 ]]; then
        log_err "No site configs selected."
        exit 1
    fi

    for config in "${SELECTED_SITE_CONFIGS[@]}"; do
        site_name="$(site_name_from_config "$config")"
        if [[ -z "$site_name" ]]; then
            log_err "site_name missing in $(basename "$config")"
            exit 1
        fi

        echo -e "\n${GREEN}════════════════════════════════════════${NC}"
        log_info "Creating clean site from: $(basename "$config")"
        echo -e "${GREEN}════════════════════════════════════════${NC}"
        create_site_by_name "$site_name"
    done
}

create_clean_site() {
    create_site_by_name "$CLEAN_SITE_NAME"
}

setup_sites() {
    if [[ ! -f "$SETUP_SITE_SCRIPT" ]]; then
        log_err "setup-site.sh not found: $SETUP_SITE_SCRIPT"
        exit 1
    fi

    if [[ "${#SELECTED_SITE_CONFIGS[@]}" -eq 0 ]]; then
        log_err "No site configs selected."
        exit 1
    fi

    for config in "${SELECTED_SITE_CONFIGS[@]}"; do
        echo -e "\n${GREEN}════════════════════════════════════════${NC}"
        log_info "Setting up site from: $(basename "$config")"
        echo -e "${GREEN}════════════════════════════════════════${NC}"

        BENCH_DIR="$BENCH_PATH" \
        DB_TYPE="$DB_TYPE" \
        ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        bash "$SETUP_SITE_SCRIPT" "$config"
    done
}
