#!/usr/bin/env bash
# Regenerate data/certs/ca-bundle.pem — Debian CA bundle + corporate root CA
# from the macOS keychain. Run this if the corporate CA rotates.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="$REPO_DIR/data/certs"
CA_NAME="${CORP_CA_NAME:-YandexInternalRootCA}"
BASE_IMAGE="${BASE_CA_IMAGE:-debian:trixie-slim}"

mkdir -p "$CERTS_DIR"

echo "[ca] exporting $CA_NAME from macOS System keychain"
security find-certificate -a -c "$CA_NAME" -p /Library/Keychains/System.keychain \
    > "$CERTS_DIR/corp-root-ca.pem"
if ! grep -q "BEGIN CERTIFICATE" "$CERTS_DIR/corp-root-ca.pem"; then
    echo "[ca] ERROR: no certificate found for '$CA_NAME'" >&2
    exit 1
fi

echo "[ca] pulling base bundle from $BASE_IMAGE"
podman run --rm "$BASE_IMAGE" cat /etc/ssl/certs/ca-certificates.crt \
    > "$CERTS_DIR/base-bundle.pem"

cat "$CERTS_DIR/base-bundle.pem" "$CERTS_DIR/corp-root-ca.pem" \
    > "$CERTS_DIR/ca-bundle.pem"

count=$(grep -c "BEGIN CERTIFICATE" "$CERTS_DIR/ca-bundle.pem")
echo "[ca] done: $count certificates -> $CERTS_DIR/ca-bundle.pem"
