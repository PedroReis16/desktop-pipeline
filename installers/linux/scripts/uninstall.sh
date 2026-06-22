#!/usr/bin/env bash
# Remove DesktopServices instalado via install.sh.
set -euo pipefail

INSTALL_ROOT="/opt/vigia/desktopservices"
CLI_LINK="/usr/local/bin/desktop"
SERVICE_USER="desktopservices"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_CONF="${SCRIPT_DIR}/services.conf"

log() { printf '[DesktopServices] %s\n' "$*"; }
die() { printf '[DesktopServices] ERRO: %s\n' "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Execute como root: sudo $0"
  fi
}

stop_and_disable_services() {
  [[ -f "$SERVICES_CONF" ]] || return 0
  while IFS='|' read -r unit_id _ _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    local unit="${unit_id}.service"
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      log "Desabilitando ${unit}..."
      systemctl disable "$unit" || true
    fi
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
      log "Parando ${unit}..."
      systemctl stop "$unit" || true
    fi
    if [[ -f "/etc/systemd/system/${unit}" ]]; then
      rm -f "/etc/systemd/system/${unit}"
      log "Removido ${unit}"
    fi
  done < "$SERVICES_CONF"
  systemctl daemon-reload 2>/dev/null || true
}

remove_cli() {
  if [[ -L "$CLI_LINK" || -f "$CLI_LINK" ]]; then
    rm -f "$CLI_LINK"
    log "CLI removida: ${CLI_LINK}"
  fi
}

remove_install_root() {
  if [[ -d "$INSTALL_ROOT" ]]; then
    rm -rf "$INSTALL_ROOT"
    log "Diretorio removido: ${INSTALL_ROOT}"
  fi
}

remove_service_user() {
  if id -u "$SERVICE_USER" &>/dev/null; then
    userdel "$SERVICE_USER" 2>/dev/null || true
    log "Usuario ${SERVICE_USER} removido"
  fi
}

main() {
  require_root
  log "Iniciando desinstalacao..."
  stop_and_disable_services
  remove_cli
  remove_install_root
  remove_service_user
  log "Desinstalacao concluida."
}

main "$@"
