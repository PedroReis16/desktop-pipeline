#!/usr/bin/env bash
# Remove DesktopServices instalado via install.sh ou AppImage --uninstall.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_CONF="${SCRIPT_DIR}/services.conf"

if [[ -f "${SCRIPT_DIR}/lib/install-common.sh" ]]; then
  # shellcheck source=lib/install-common.sh
  source "${SCRIPT_DIR}/lib/install-common.sh"
elif [[ -f "${SCRIPT_DIR}/../lib/install-common.sh" ]]; then
  # shellcheck source=../lib/install-common.sh
  source "${SCRIPT_DIR}/../lib/install-common.sh"
else
  echo "[DesktopServices] ERRO: install-common.sh nao encontrado." >&2
  exit 1
fi

main() {
  uninstall_desktopservices
}

main "$@"
