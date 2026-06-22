#!/usr/bin/env bash
# Monta o layout de instalacao a partir dos payloads publicados.
set -euo pipefail

VERSION="${1:?Informe a versao}"
STAGING_ROOT="${2:?Informe o diretorio de staging com os payloads}"
OUTPUT_LAYOUT="${3:?Informe o diretorio de saida do layout}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="DesktopServices-${VERSION}-linux-x64"
LAYOUT="${OUTPUT_LAYOUT}/${PACKAGE_NAME}"

rm -rf "$LAYOUT"
mkdir -p "${LAYOUT}/payload/services" "${LAYOUT}/payload/cmd" "${LAYOUT}/templates"

cp "${ROOT}/services.conf" "$LAYOUT/"
cp "${ROOT}/templates/systemd.service.template" "${LAYOUT}/templates/"
cp "${ROOT}/scripts/install.sh" "${LAYOUT}/install.sh"
cp "${ROOT}/scripts/uninstall.sh" "${LAYOUT}/uninstall.sh"
cp "${ROOT}/lib/install-common.sh" "${LAYOUT}/lib/install-common.sh"
echo "$VERSION" > "${LAYOUT}/VERSION"

copy_service() {
  local artifact_name="$1"
  local folder="$2"
  local src="${STAGING_ROOT}/${artifact_name}"
  [[ -d "$src" ]] || { echo "Payload ausente: $src" >&2; exit 1; }
  mkdir -p "${LAYOUT}/payload/services/${folder}"
  cp -a "${src}/." "${LAYOUT}/payload/services/${folder}/"
}

copy_service "payload-desktop-export" "Desktop.Export"
copy_service "payload-desktop-import" "Desktop.Import"
copy_service "payload-desktop-instance" "Desktop.Instance"
copy_service "payload-desktop-integration" "Desktop.Integration"
copy_service "payload-desktop-interfaceapi" "Desktop.InterfaceAPI"

cmd_src="${STAGING_ROOT}/payload-desktop-cmd/desktop"
[[ -f "$cmd_src" ]] || { echo "CLI desktop ausente: $cmd_src" >&2; exit 1; }
install -m 0755 "$cmd_src" "${LAYOUT}/payload/cmd/desktop"

printf '%s\n' "$LAYOUT"
