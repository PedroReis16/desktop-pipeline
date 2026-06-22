#!/usr/bin/env bash
# Monta o layout do AppImage (servicos + CLI + interface grafica).
set -euo pipefail

VERSION="${1:?Informe a versao}"
STAGING_ROOT="${2:?Informe o diretorio de staging com os payloads}"
OUTPUT_LAYOUT="${3:?Informe o diretorio de saida do layout}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT="$(bash "${ROOT}/stage-payload.sh" "$VERSION" "$STAGING_ROOT" "$OUTPUT_LAYOUT")"

ui_src="${STAGING_ROOT}/payload-desktop-ui"
[[ -d "$ui_src" ]] || { echo "Payload da interface grafica ausente: $ui_src" >&2; exit 1; }

mkdir -p "${LAYOUT}/payload/ui"
cp -a "${ui_src}/." "${LAYOUT}/payload/ui/"
cp "${ROOT}/templates/desktop-ui.desktop.template" "${LAYOUT}/templates/"

printf '%s\n' "$LAYOUT"
