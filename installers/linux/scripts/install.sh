#!/usr/bin/env bash
# Instala DesktopServices no Linux: servicos systemd + CLI desktop.
set -euo pipefail

MANUFACTURER="Vigia"
INSTALL_ROOT="/opt/vigia/desktopservices"
CLI_LINK="/usr/local/bin/desktop"
SERVICE_USER="desktopservices"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${SCRIPT_DIR}/payload"
TEMPLATE="${SCRIPT_DIR}/templates/systemd.service.template"
SERVICES_CONF="${SCRIPT_DIR}/services.conf"

log() { printf '[DesktopServices] %s\n' "$*"; }
die() { printf '[DesktopServices] ERRO: %s\n' "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Execute como root: sudo $0"
  fi
}

require_payload() {
  [[ -d "$PAYLOAD_DIR/services" ]] || die "Payload de servicos nao encontrado em ${PAYLOAD_DIR}/services"
  [[ -f "$PAYLOAD_DIR/cmd/desktop" ]] || die "CLI desktop nao encontrada em ${PAYLOAD_DIR}/cmd/desktop"
  [[ -f "$TEMPLATE" ]] || die "Template systemd nao encontrado: $TEMPLATE"
  [[ -f "$SERVICES_CONF" ]] || die "Manifesto de servicos nao encontrado: $SERVICES_CONF"
}

ensure_service_user() {
  if ! id -u "$SERVICE_USER" &>/dev/null; then
    log "Criando usuario de sistema ${SERVICE_USER}..."
    useradd --system --home "$INSTALL_ROOT" --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}

render_unit() {
  local unit_id="$1"
  local folder="$2"
  local binary="$3"
  local description="$4"
  local unit_path="/etc/systemd/system/${unit_id}.service"

  sed \
    -e "s|{{DESCRIPTION}}|${description}|g" \
    -e "s|{{INSTALL_ROOT}}|${INSTALL_ROOT}|g" \
    -e "s|{{FOLDER}}|${folder}|g" \
    -e "s|{{BINARY}}|${binary}|g" \
    "$TEMPLATE" > "$unit_path"

  log "Unidade systemd criada: ${unit_path}"
}

stop_existing_services() {
  while IFS='|' read -r unit_id _ _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    if systemctl is-active --quiet "${unit_id}.service" 2>/dev/null; then
      log "Parando ${unit_id}.service..."
      systemctl stop "${unit_id}.service"
    fi
  done < "$SERVICES_CONF"
}

install_files() {
  log "Instalando arquivos em ${INSTALL_ROOT}..."
  install -d -m 0755 "${INSTALL_ROOT}/services" "${INSTALL_ROOT}/cmd"

  while IFS='|' read -r unit_id folder _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    local src="${PAYLOAD_DIR}/services/${folder}"
    local dest="${INSTALL_ROOT}/services/${folder}"
    [[ -d "$src" ]] || die "Servico ausente no payload: ${folder}"
    rm -rf "$dest"
    cp -a "$src" "$dest"
    if [[ -f "${dest}/${folder}" ]]; then
      chmod 0755 "${dest}/${folder}"
    fi
  done < "$SERVICES_CONF"

  install -m 0755 "${PAYLOAD_DIR}/cmd/desktop" "${INSTALL_ROOT}/cmd/desktop"

  if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
    install -m 0644 "${SCRIPT_DIR}/VERSION" "${INSTALL_ROOT}/VERSION"
  fi

  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}/services"
  chown root:root "${INSTALL_ROOT}/cmd/desktop"
}

install_cli() {
  log "Registrando CLI em ${CLI_LINK}..."
  ln -sf "${INSTALL_ROOT}/cmd/desktop" "$CLI_LINK"
}

register_services() {
  while IFS='|' read -r unit_id folder binary description; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    render_unit "$unit_id" "$folder" "$binary" "$description"
    systemctl daemon-reload
    systemctl enable "${unit_id}.service"
  done < "$SERVICES_CONF"
}

start_services() {
  while IFS='|' read -r unit_id _ _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    log "Iniciando ${unit_id}.service..."
    systemctl start "${unit_id}.service"
  done < "$SERVICES_CONF"
}

main() {
  require_root
  require_payload
  command -v systemctl >/dev/null 2>&1 || die "systemd nao encontrado neste sistema"

  log "Iniciando instalacao (${MANUFACTURER} DesktopServices)..."
  stop_existing_services
  ensure_service_user
  install -d -m 0755 "$(dirname "$INSTALL_ROOT")"
  install_files
  install_cli
  register_services
  start_services

  log "Instalacao concluida."
  log "  Diretorio: ${INSTALL_ROOT}"
  log "  CLI: desktop (disponivel em ${CLI_LINK})"
  log "  Servicos: systemctl status Desktop.Export (e demais unidades Desktop.*)"
}

main "$@"
