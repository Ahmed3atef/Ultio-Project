#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# installer.sh  —  entrypoint
#
# 1. Initialises frappe-bench (if not already present)
# 2. Runs get-apps/get-apps.sh to clone / fetch all apps
# 3. Calls setup-site.sh for every JSON file in scripts/sites/
#
# Usage:
#   bash installer.sh [options]
#
# Options:
#   -b | --bench-name      Bench directory name       (default: frappe-bench)
#   -r | --frappe-repo     Frappe git URL             (default: official GitHub)
#   -t | --frappe-branch   Frappe branch              (default: version-15)
#   -p | --py-version      pyenv Python version       (optional)
#   -n | --node-version    nvm Node version           (optional)
#   -d | --db-type         mariadb | postgresql        (default: mariadb)
#   -a | --admin-password  Site admin password        (default: admin)
#   -v | --verbose         Pass --verbose to bench init
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Resolve script root (works regardless of cwd) ────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GET_APPS_SCRIPT="$SCRIPT_DIR/scripts/get-apps/get-apps.sh"
SITES_DIR="$SCRIPT_DIR/sites"
SETUP_SITE_SCRIPT="$SCRIPT_DIR/scripts/setup-site.sh"

# ── Colors ────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[installer] $*${NC}"; }
log_ok()   { echo -e "${GREEN}[installer] ✔ $*${NC}"; }
log_err()  { echo -e "${RED}[installer] ✘ $*${NC}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────

BENCH_NAME="frappe-bench"
FRAPPE_REPO="https://github.com/frappe/frappe"
FRAPPE_BRANCH="version-15"
PY_VERSION=""
NODE_VERSION=""
DB_TYPE="mariadb"
ADMIN_PASSWORD="admin"
VERBOSE=false

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--bench-name)      BENCH_NAME="$2";      shift 2 ;;
        -r|--frappe-repo)     FRAPPE_REPO="$2";     shift 2 ;;
        -t|--frappe-branch)   FRAPPE_BRANCH="$2";   shift 2 ;;
        -p|--py-version)      PY_VERSION="$2";      shift 2 ;;
        -n|--node-version)    NODE_VERSION="$2";    shift 2 ;;
        -d|--db-type)         DB_TYPE="$2";         shift 2 ;;
        -a|--admin-password)  ADMIN_PASSWORD="$2";  shift 2 ;;
        -v|--verbose)         VERBOSE=true;         shift   ;;
        *)
            log_err "Unknown argument: $1"
            exit 1
            ;;
    esac
done

BENCH_PATH="$(pwd)/${BENCH_NAME}"

# ── Step 1: Init bench ────────────────────────────────────────────────────────

init_bench() {
    if [[ -d "$BENCH_NAME" ]]; then
        log_info "Bench already exists — skipping init."
        return
    fi

    log_info "Initialising bench: $BENCH_NAME"

    local cmd=""

    [[ -n "$NODE_VERSION" ]] && cmd+="nvm use ${NODE_VERSION} && "
    [[ -n "$PY_VERSION"   ]] && export PYENV_VERSION="$PY_VERSION"

    cmd+="bench init"
    cmd+=" --skip-redis-config-generation"
    [[ "$VERBOSE" == true ]] && cmd+=" --verbose"
    cmd+=" --frappe-path=${FRAPPE_REPO}"
    cmd+=" --frappe-branch=${FRAPPE_BRANCH}"
    cmd+=" ${BENCH_NAME}"

    bash -ic "$cmd"

    pushd "$BENCH_PATH" > /dev/null

    log_info "Configuring bench..."

    bench set-config -g db_type       "$DB_TYPE"
    bench set-config -g redis_cache   "redis://redis-cache:6379"
    bench set-config -g redis_queue   "redis://redis-queue:6379"
    bench set-config -g redis_socketio "redis://redis-queue:6379"
    bench set-config -gp developer_mode "1"

    popd > /dev/null

    log_ok "Bench initialised."
}

# ── Step 2: Get all apps ──────────────────────────────────────────────────────

get_apps() {
    if [[ ! -f "$GET_APPS_SCRIPT" ]]; then
        log_err "get-apps.sh not found: $GET_APPS_SCRIPT"
        exit 1
    fi

    log_info "Fetching apps..."
    BENCH_DIR="$BENCH_PATH" bash "$GET_APPS_SCRIPT"
    log_ok "Apps fetched."
}

# ── Step 3: Setup each site ───────────────────────────────────────────────────

setup_sites() {
    if [[ ! -d "$SITES_DIR" ]]; then
        log_err "Sites config directory not found: $SITES_DIR"
        exit 1
    fi

    if [[ ! -f "$SETUP_SITE_SCRIPT" ]]; then
        log_err "setup-site.sh not found: $SETUP_SITE_SCRIPT"
        exit 1
    fi

    local found=false

    for config in "$SITES_DIR"/*.json; do
        [[ -f "$config" ]] || continue
        found=true

        echo -e "\n${GREEN}════════════════════════════════════════${NC}"
        log_info "Setting up site from: $(basename "$config")"
        echo -e "${GREEN}════════════════════════════════════════${NC}"

        BENCH_DIR="$BENCH_PATH" \
        DB_TYPE="$DB_TYPE" \
        ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        bash "$SETUP_SITE_SCRIPT" "$config"
    done

    if [[ "$found" == false ]]; then
        log_err "No JSON configs found in: $SITES_DIR"
        exit 1
    fi
}

# ── Step 4: Build assets & migrate ───────────────────────────────────────────

finalize() {
    pushd "$BENCH_PATH" > /dev/null

    log_info "Installing Node requirements..."
    bench setup requirements --node

    log_info "Building assets..."
    bench build

    log_info "Running migrations..."
    bench --site all migrate

    popd > /dev/null
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok  "Frappe bench installer starting"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    init_bench
    get_apps
    setup_sites
    finalize

    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    log_ok  "All done."
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"
}

main