#!/usr/bin/env bash
# Wrapper around `podman compose up` that first ensures the local CONNECT
# proxy is running on the Mac host. The proxy gives the Linux VM a way to
# reach IPv6-only internal endpoints (see scripts/ipv6-proxy.py).
#
# Usage:
#   ./scripts/up.sh           # foreground
#   ./scripts/up.sh -d        # detached
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

cd "$REPO_DIR"
ensure_proxy
exec podman compose up "$@"
