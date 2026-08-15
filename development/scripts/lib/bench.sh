#!/usr/bin/env bash
# bench.sh — bench init and bench start steps.
#
# Reads/writes the globals set by installer.sh (BENCH_PATH, BENCH_NAME,
# VERBOSE, FRAPPE_REPO, FRAPPE_BRANCH, NODE_VERSION, PY_VERSION, DB_TYPE).

init_bench() {
    if [[ -d "$BENCH_PATH" ]]; then
        log_info "Bench already exists — skipping init."
        return
    fi

    log_info "Initialising bench: $BENCH_NAME"

    local -a init_cmd=(bench init --skip-redis-config-generation)
    [[ "$VERBOSE" == true ]] && init_cmd+=(--verbose)
    init_cmd+=(--frappe-path="$FRAPPE_REPO")
    init_cmd+=(--frappe-branch="$FRAPPE_BRANCH")
    init_cmd+=("$BENCH_NAME")

    local -a login_cmd=()
    [[ -n "$NODE_VERSION" ]] && login_cmd=(nvm use "$NODE_VERSION" '&&')
    login_cmd+=("${init_cmd[@]}")

    [[ -n "$PY_VERSION" ]] && export PYENV_VERSION="$PY_VERSION"

    bash -ic "${login_cmd[*]}"

    pushd "$BENCH_PATH" > /dev/null

    log_info "Configuring bench..."

    bench set-config -g db_type        "$DB_TYPE"
    bench set-config -g redis_cache    "redis://redis-cache:6379"
    bench set-config -g redis_queue    "redis://redis-queue:6379"
    bench set-config -g redis_socketio "redis://redis-queue:6379"
    bench set-config -gp developer_mode "1"

    popd > /dev/null

    log_ok "Bench initialised."
}

start_bench() {
    pushd "$BENCH_PATH" > /dev/null

    log_info "Starting bench..."
    log_info "Open the site in your browser and complete the initial setup manually."
    bench start
}
