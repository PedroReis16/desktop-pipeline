#!/usr/bin/env bash
# Monta os artefatos Linux (.deb + AppImage) a partir dos payloads publicados.
set -euo pipefail

VERSION="${1:?Informe a versao}"
OUTPUT_DIR="${2:?Informe o diretorio de saida}"
STAGING_ROOT="${3:?Informe o diretorio de staging com os payloads}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_DIR="$(mktemp -d)"
trap 'rm -rf "$LAYOUT_DIR"' EXIT

DEB_LAYOUT="$(bash "${ROOT}/stage-payload.sh" "$VERSION" "$STAGING_ROOT" "${LAYOUT_DIR}/deb")"
APPIMAGE_LAYOUT="$(bash "${ROOT}/stage-appimage-payload.sh" "$VERSION" "$STAGING_ROOT" "${LAYOUT_DIR}/appimage")"

mkdir -p "$OUTPUT_DIR"
bash "${ROOT}/package-deb.sh" "$VERSION" "$OUTPUT_DIR" "$DEB_LAYOUT"
bash "${ROOT}/package-appimage.sh" "$VERSION" "$OUTPUT_DIR" "$APPIMAGE_LAYOUT"

printf 'Artefatos Linux gerados em: %s\n' "$OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
