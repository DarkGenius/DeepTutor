#!/usr/bin/env bash
# Wrapper around `podman compose up` that first ensures the local CONNECT
# proxy is running on the Mac host. The proxy gives the Linux VM a way to
# reach IPv6-only internal endpoints (see scripts/ipv6-proxy.py).
#
# Usage:
#   ./scripts/up.sh                 # foreground
#   ./scripts/up.sh -d              # detached
#   ./scripts/up.sh --build         # rebuild image(s) then bring the stack up
#   ./scripts/up.sh --build -d      # rebuild and run detached
#   IPV6_PROXY_PORT=9000 ./scripts/up.sh -d
set -euo pipefail

PROXY_PORT="${IPV6_PROXY_PORT:-8899}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROXY_SCRIPT="$REPO_DIR/scripts/ipv6-proxy.py"
PID_FILE="/tmp/deeptutor-ipv6-proxy.pid"
LOG_FILE="/tmp/deeptutor-ipv6-proxy.log"

ensure_proxy() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "[ipv6-proxy] already running (pid $pid)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    if lsof -nP -iTCP:"$PROXY_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "[ipv6-proxy] port $PROXY_PORT is already in use by an untracked process — leaving it alone"
        return 0
    fi
    echo "[ipv6-proxy] starting on :$PROXY_PORT (log: $LOG_FILE)"
    nohup python3 "$PROXY_SCRIPT" "$PROXY_PORT" >"$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    disown || true
}

# Strip --build out of the argv before forwarding the rest to `podman compose
# up`, then run the build step explicitly. Doing this separately gives clearer
# build progress and avoids edge cases where `up --build` skips rebuilding
# images that compose considers "fresh enough".
do_build=0
up_args=()
for arg in "$@"; do
    if [[ "$arg" == "--build" ]]; then
        do_build=1
    else
        up_args+=("$arg")
    fi
done

cd "$REPO_DIR"
ensure_proxy
if [[ "$do_build" -eq 1 ]]; then
    echo "[up] rebuilding images (--build requested)"
    podman compose build
fi
exec podman compose up "${up_args[@]}"
