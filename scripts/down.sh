#!/usr/bin/env bash
# Counterpart to scripts/up.sh — stops compose and the local CONNECT proxy.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="/tmp/deeptutor-ipv6-proxy.pid"

cd "$REPO_DIR"
podman compose down "$@"

if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "[ipv6-proxy] stopping (pid $pid)"
        kill "$pid" || true
    fi
    rm -f "$PID_FILE"
fi
