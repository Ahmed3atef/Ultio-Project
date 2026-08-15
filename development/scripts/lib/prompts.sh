#!/usr/bin/env bash
# prompts.sh — interactive input helpers and the bench settings prompt.
#
# Reads/writes the globals set by installer.sh (BENCH_NAME, BENCH_PATH,
# FRAPPE_REPO, FRAPPE_BRANCH, PY_VERSION, NODE_VERSION, VERBOSE, DB_TYPE,
# ADMIN_PASSWORD).

prompt_value() {
    local label="$1"
    local default_value="$2"
    local value

    if [[ -n "$default_value" ]]; then
        read -r -p "$label [$default_value]: " value
        printf '%s' "${value:-$default_value}"
    else
        read -r -p "$label: " value
        printf '%s' "$value"
    fi
}

prompt_yes_no() {
    local label="$1"
    local default_value="$2"
    local prompt="y/N"
    local answer

    if [[ "$default_value" == "true" ]]; then
        prompt="Y/n"
    fi

    while true; do
        read -r -p "$label [$prompt]: " answer
        answer="${answer:-}"

        if [[ -z "$answer" ]]; then
            [[ "$default_value" == "true" ]] && return 0 || return 1
        fi

        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

prompt_db_type() {
    local value

    while true; do
        value="$(prompt_value "Database type (mariadb/postgresql)" "$DB_TYPE")"
        case "$value" in
            mariadb|postgresql)
                DB_TYPE="$value"
                return
                ;;
            *) echo "Choose mariadb or postgresql." ;;
        esac
    done
}

configure_cli() {
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok "Frappe bench installer"
    echo -e "${GREEN}════════════════════════════════════════${NC}"

    if [[ -d "$BENCH_PATH" ]]; then
        log_info "Bench already exists at $BENCH_PATH — skipping bench init prompts."
    else
        echo "Press Enter to keep the default shown in brackets."
        echo

        BENCH_NAME="$(prompt_value "Bench directory name" "$BENCH_NAME")"
        BENCH_PATH="$(pwd)/${BENCH_NAME}"

        if [[ -d "$BENCH_PATH" ]]; then
            log_info "Bench already exists at $BENCH_PATH — skipping bench init prompts."
        else
            FRAPPE_REPO="$(prompt_value "Frappe git URL" "$FRAPPE_REPO")"
            FRAPPE_BRANCH="$(prompt_value "Frappe branch" "$FRAPPE_BRANCH")"
            PY_VERSION="$(prompt_value "pyenv Python version (optional)" "$PY_VERSION")"
            NODE_VERSION="$(prompt_value "nvm Node version (optional)" "$NODE_VERSION")"

            if prompt_yes_no "Pass --verbose to bench init" "$VERBOSE"; then
                VERBOSE=true
            else
                VERBOSE=false
            fi
        fi
    fi

    prompt_db_type
    ADMIN_PASSWORD="$(prompt_value "Site admin password" "$ADMIN_PASSWORD")"
}
