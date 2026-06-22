#!/usr/bin/env bash
# Instala DesktopServices no Linux: servicos systemd + CLI desktop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${SCRIPT_DIR}/payload"
TEMPLATE="${SCRIPT_DIR}/templates/systemd.service.template"
SERVICES_CONF="${SCRIPT_DIR}/services.conf"
VERSION_FILE="${SCRIPT_DIR}/VERSION"

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

require_payload() {
  [[ -d "$PAYLOAD_DIR/services" ]] || die "Payload de servicos nao encontrado em ${PAYLOAD_DIR}/services"
  [[ -f "$PAYLOAD_DIR/cmd/desktop" ]] || die "CLI desktop nao encontrada em ${PAYLOAD_DIR}/cmd/desktop"
  [[ -f "$TEMPLATE" ]] || die "Template systemd nao encontrado: $TEMPLATE"
  [[ -f "$SERVICES_CONF" ]] || die "Manifesto de servicos nao encontrado: $SERVICES_CONF"
}

main() {
  require_payload
  install_from_staging
}

main "$@"
