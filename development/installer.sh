#!/usr/bin/env bash

set -euo pipefail

# ============================================
# Colors
# ============================================

CRED="\033[31m"
CGRN="\033[92m"
CYLW="\033[93m"
CRESET="\033[0m"

cprint() {
    local level="${1:-1}"
    shift

    case "$level" in
        1) echo -e "${CRED}$*${CRESET}" ;;
        2) echo -e "${CGRN}$*${CRESET}" ;;
        3) echo -e "${CYLW}$*${CRESET}" ;;
        *) echo "$*" ;;
    esac
}

# ============================================
# Defaults
# ============================================

BENCH_NAME="frappe-bench"
SITE_NAME="development.localhost"

FRAPPE_REPO="https://github.com/frappe/frappe"
FRAPPE_BRANCH="version-15"

PY_VERSION=""
NODE_VERSION=""
VERBOSE=false

ADMIN_PASSWORD="admin"
DB_TYPE="mariadb"

# Your custom app installer
GET_APPS_SCRIPT="/workspace/development/scripts/get-apps/get-apps.sh"

# ============================================
# Parse Args
# ============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--bench-name)
            BENCH_NAME="$2"
            shift 2
            ;;
        -s|--site-name)
            SITE_NAME="$2"
            shift 2
            ;;
        -r|--frappe-repo)
            FRAPPE_REPO="$2"
            shift 2
            ;;
        -t|--frappe-branch)
            FRAPPE_BRANCH="$2"
            shift 2
            ;;
        -p|--py-version)
            PY_VERSION="$2"
            shift 2
            ;;
        -n|--node-version)
            NODE_VERSION="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -a|--admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        -d|--db-type)
            DB_TYPE="$2"
            shift 2
            ;;
        *)
            cprint 1 "Unknown argument: $1"
            exit 1
            ;;
    esac
done

BENCH_PATH="$(pwd)/${BENCH_NAME}"

# ============================================
# Helpers
# ============================================

run_bench_config() {
    local key="$1"
    local value="$2"
    local flags="${3:-}"

    bench set-config ${flags} "$key" "$value"
}

# ============================================
# Init Bench
# ============================================

init_bench_if_not_exist() {

    if [[ -d "$BENCH_NAME" ]]; then
        cprint 3 "Bench already exists. Skipping init."
        return
    fi

    cprint 2 "Initializing Bench..."

    local cmd=""

    if [[ -n "$NODE_VERSION" ]]; then
        cmd+="nvm use ${NODE_VERSION} && "
    fi

    if [[ -n "$PY_VERSION" ]]; then
        export PYENV_VERSION="$PY_VERSION"
    fi

    cmd+="bench init "
    cmd+="--skip-redis-config-generation "

    if [[ "$VERBOSE" == true ]]; then
        cmd+="--verbose "
    fi

    cmd+="--frappe-path=${FRAPPE_REPO} "
    cmd+="--frappe-branch=${FRAPPE_BRANCH} "
    cmd+="${BENCH_NAME}"

    bash -ic "$cmd"

    pushd "$BENCH_PATH" > /dev/null

    cprint 2 "Configuring Bench..."

    run_bench_config "db_type" "$DB_TYPE" "-g"

    run_bench_config \
        "redis_cache" \
        "redis://redis-cache:6379" \
        "-g"

    run_bench_config \
        "redis_queue" \
        "redis://redis-queue:6379" \
        "-g"

    run_bench_config \
        "redis_socketio" \
        "redis://redis-queue:6379" \
        "-g"

    run_bench_config \
        "developer_mode" \
        "1" \
        "-gp"

    popd > /dev/null
}

# ============================================
# Install Custom Apps
# ============================================

install_apps() {

    if [[ ! -f "$GET_APPS_SCRIPT" ]]; then
        cprint 1 "Apps installer script not found:"
        cprint 1 "$GET_APPS_SCRIPT"
        exit 1
    fi

    cprint 2 "Installing Apps..."

    BENCH_DIR="$BENCH_PATH" bash "$GET_APPS_SCRIPT"
}

# ============================================
# Create Site
# ============================================

create_site() {

    pushd "$BENCH_PATH" > /dev/null

    local DB_HOST=""
    local CMD=()

    if [[ "$DB_TYPE" == "mariadb" ]]; then

        DB_HOST="mariadb"

        run_bench_config "db_host" "$DB_HOST" "-g"

        CMD=(
            bench new-site
            --db-root-username=root
            --db-root-password=123
            --db-host="$DB_HOST"
            --db-type="$DB_TYPE"
            --mariadb-user-host-login-scope=%
            --admin-password="$ADMIN_PASSWORD"
        )

    else

        DB_HOST="postgresql"

        run_bench_config "db_host" "$DB_HOST" "-g"

        CMD=(
            bench new-site
            --db-root-username=root
            --db-root-password=123
            --db-host="$DB_HOST"
            --db-type="$DB_TYPE"
            --admin-password="$ADMIN_PASSWORD"
        )
    fi

    # Auto install all apps inside apps/
    for app_path in apps/*; do

        app_name="$(basename "$app_path")"

        if [[ "$app_name" == "frappe" ]]; then
            continue
        fi

        CMD+=(--install-app="$app_name")
    done

    CMD+=("$SITE_NAME")

    cprint 2 "Creating site: $SITE_NAME"

    "${CMD[@]}"

    popd > /dev/null
}

# ============================================
# Main
# ============================================

main() {

    init_bench_if_not_exist

    install_apps

    create_site

    cprint 2 "Done."
}

main