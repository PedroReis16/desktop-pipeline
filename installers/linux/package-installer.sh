#!/usr/bin/env bash
# Monta o tarball instalavel a partir dos payloads publicados.
set -euo pipefail

VERSION="${1:?Informe a versao}"
OUTPUT_DIR="${2:?Informe o diretorio de saida}"
STAGING_ROOT="${3:?Informe o diretorio de staging com os payloads}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="DesktopServices-${VERSION}-linux-x64"
STAGE="${STAGING_ROOT}/${PACKAGE_NAME}"
TARBALL="${OUTPUT_DIR}/${PACKAGE_NAME}.tar.gz"

rm -rf "$STAGE"
mkdir -p "${STAGE}/payload/services" "${STAGE}/payload/cmd" "${STAGE}/templates"

cp "${ROOT}/services.conf" "$STAGE/"
cp "${ROOT}/templates/systemd.service.template" "${STAGE}/templates/"
cp "${ROOT}/scripts/install.sh" "${STAGE}/install.sh"
cp "${ROOT}/scripts/uninstall.sh" "${STAGE}/uninstall.sh"
echo "$VERSION" > "${STAGE}/VERSION"

copy_service() {
  local artifact_name="$1"
  local folder="$2"
  local src="${STAGING_ROOT}/${artifact_name}"
  [[ -d "$src" ]] || { echo "Payload ausente: $src" >&2; exit 1; }
  mkdir -p "${STAGE}/payload/services/${folder}"
  cp -a "${src}/." "${STAGE}/payload/services/${folder}/"
}

copy_service "payload-desktop-export" "Desktop.Export"
copy_service "payload-desktop-import" "Desktop.Import"
copy_service "payload-desktop-instance" "Desktop.Instance"
copy_service "payload-desktop-integration" "Desktop.Integration"
copy_service "payload-desktop-interfaceapi" "Desktop.InterfaceAPI"

cmd_src="${STAGING_ROOT}/payload-desktop-cmd/desktop"
[[ -f "$cmd_src" ]] || { echo "CLI desktop ausente: $cmd_src" >&2; exit 1; }
install -m 0755 "$cmd_src" "${STAGE}/payload/cmd/desktop"

mkdir -p "$OUTPUT_DIR"
tar -czf "$TARBALL" -C "$(dirname "$STAGE")" "$(basename "$STAGE")"

printf 'Pacote gerado: %s\n' "$TARBALL"
