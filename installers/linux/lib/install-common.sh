#!/usr/bin/env bash
# Funcoes compartilhadas entre install.sh, uninstall.sh e scripts do pacote .deb.
set -euo pipefail

MANUFACTURER="${MANUFACTURER:-Vigia}"
INSTALL_ROOT="${INSTALL_ROOT:-/opt/vigia/desktopservices}"
CLI_LINK="${CLI_LINK:-/usr/local/bin/desktop}"
SERVICE_USER="${SERVICE_USER:-desktopservices}"
SYSTEMD_UNIT_DIR="${SYSTEMD_UNIT_DIR:-/lib/systemd/system}"
DOTNET_INSTALL_DIR="${DOTNET_INSTALL_DIR:-/usr/share/dotnet}"
DOTNET_CHANNEL="${DOTNET_CHANNEL:-10.0}"
UI_DESKTOP_FILE="${UI_DESKTOP_FILE:-/usr/share/applications/desktopservices-ui.desktop}"
UI_LINK="${UI_LINK:-/usr/local/bin/desktop-ui}"

log() { printf '[DesktopServices] %s\n' "$*"; }
die() { printf '[DesktopServices] ERRO: %s\n' "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Execute como root: sudo $0"
  fi
}

services_conf_path() {
  if [[ -n "${SERVICES_CONF:-}" ]]; then
    printf '%s\n' "$SERVICES_CONF"
    return 0
  fi
  local script_dir="${SCRIPT_DIR:-}"
  if [[ -n "$script_dir" && -f "${script_dir}/services.conf" ]]; then
    printf '%s\n' "${script_dir}/services.conf"
    return 0
  fi
  if [[ -f /usr/share/desktopservices/services.conf ]]; then
    printf '%s\n' /usr/share/desktopservices/services.conf
    return 0
  fi
  die "Manifesto de servicos nao encontrado."
}

systemd_template_path() {
  if [[ -n "${TEMPLATE:-}" && -f "$TEMPLATE" ]]; then
    printf '%s\n' "$TEMPLATE"
    return 0
  fi
  local script_dir="${SCRIPT_DIR:-}"
  if [[ -n "$script_dir" && -f "${script_dir}/templates/systemd.service.template" ]]; then
    printf '%s\n' "${script_dir}/templates/systemd.service.template"
    return 0
  fi
  if [[ -f /usr/share/desktopservices/systemd.service.template ]]; then
    printf '%s\n' /usr/share/desktopservices/systemd.service.template
    return 0
  fi
  die "Template systemd nao encontrado."
}

ensure_service_user() {
  if ! id -u "$SERVICE_USER" &>/dev/null; then
    log "Criando usuario de sistema ${SERVICE_USER}..."
    useradd --system --home "$INSTALL_ROOT" --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}

ensure_dotnet_runtime() {
  require_root
  command -v curl >/dev/null 2>&1 || die "curl e necessario para instalar o runtime .NET"

  if [[ -x "${DOTNET_INSTALL_DIR}/dotnet" ]]; then
    if "${DOTNET_INSTALL_DIR}/dotnet" --list-runtimes 2>/dev/null \
      | grep -qE "Microsoft\.NETCore\.App ${DOTNET_CHANNEL}(\.[0-9]+)?"; then
      log "Runtime .NET ${DOTNET_CHANNEL} ja instalado em ${DOTNET_INSTALL_DIR}."
      export DOTNET_ROOT="${DOTNET_INSTALL_DIR}"
      return 0
    fi
  fi

  if command -v dotnet >/dev/null 2>&1; then
    if dotnet --list-runtimes 2>/dev/null \
      | grep -qE "Microsoft\.NETCore\.App ${DOTNET_CHANNEL}(\.[0-9]+)?"; then
      log "Runtime .NET ${DOTNET_CHANNEL} disponivel no sistema."
      export DOTNET_ROOT="$(cd "$(dirname "$(readlink -f "$(command -v dotnet)")")/.." && pwd)"
      return 0
    fi
  fi

  log "Baixando e instalando runtime .NET ${DOTNET_CHANNEL} em ${DOTNET_INSTALL_DIR}..."
  local installer="/tmp/dotnet-install-runtime.sh"
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
  bash "$installer" \
    --channel "$DOTNET_CHANNEL" \
    --runtime dotnet \
    --install-dir "$DOTNET_INSTALL_DIR"

  export DOTNET_ROOT="${DOTNET_INSTALL_DIR}"
  if [[ ! -e /usr/bin/dotnet ]]; then
    ln -sf "${DOTNET_INSTALL_DIR}/dotnet" /usr/bin/dotnet
  fi

  "${DOTNET_INSTALL_DIR}/dotnet" --list-runtimes | grep -q "Microsoft.NETCore.App" \
    || die "Falha ao instalar runtime .NET ${DOTNET_CHANNEL}"
  log "Runtime .NET ${DOTNET_CHANNEL} instalado com sucesso."
}

find_ui_executable() {
  local ui_dir="$1"
  local candidate
  for candidate in desktop-ui DesktopUI; do
    if [[ -x "${ui_dir}/${candidate}" ]]; then
      printf '%s\n' "${ui_dir}/${candidate}"
      return 0
    fi
  done
  die "Executavel da interface grafica nao encontrado em ${ui_dir}"
}

ui_desktop_template_path() {
  if [[ -n "${UI_DESKTOP_TEMPLATE:-}" && -f "$UI_DESKTOP_TEMPLATE" ]]; then
    printf '%s\n' "$UI_DESKTOP_TEMPLATE"
    return 0
  fi
  local script_dir="${SCRIPT_DIR:-}"
  if [[ -n "$script_dir" && -f "${script_dir}/templates/desktop-ui.desktop.template" ]]; then
    printf '%s\n' "${script_dir}/templates/desktop-ui.desktop.template"
    return 0
  fi
  if [[ -f /usr/share/desktopservices/desktop-ui.desktop.template ]]; then
    printf '%s\n' /usr/share/desktopservices/desktop-ui.desktop.template
    return 0
  fi
  die "Template desktop-ui nao encontrado."
}

install_ui_from_payload() {
  local payload_dir="${PAYLOAD_DIR:?Informe PAYLOAD_DIR}"
  local ui_src="${payload_dir}/ui"
  [[ -d "$ui_src" ]] || return 0

  local ui_dest="${INSTALL_ROOT}/ui"
  local ui_executable template
  ui_executable="$(find_ui_executable "$ui_src")"
  template="$(ui_desktop_template_path)"

  log "Instalando interface grafica em ${ui_dest}..."
  rm -rf "$ui_dest"
  cp -a "$ui_src" "$ui_dest"
  chmod -R a+rX "$ui_dest"
  chmod 0755 "$ui_executable"

  local installed_exe="${ui_dest}/$(basename "$ui_executable")"
  [[ -x "$installed_exe" ]] || die "Executavel da UI ausente apos copia: ${installed_exe}"

  install -d -m 0755 "$(dirname "$UI_DESKTOP_FILE")"
  sed "s|{{UI_EXECUTABLE}}|${installed_exe}|g" "$template" > "$UI_DESKTOP_FILE"
  chmod 0644 "$UI_DESKTOP_FILE"
  ln -sf "$installed_exe" "$UI_LINK"

  log "Interface grafica registrada: ${UI_DESKTOP_FILE}"
  log "Atalho CLI da UI: ${UI_LINK}"
}

remove_ui() {
  if [[ -f "$UI_DESKTOP_FILE" ]]; then
    rm -f "$UI_DESKTOP_FILE"
    log "Entrada de menu removida: ${UI_DESKTOP_FILE}"
  fi
  if [[ -L "$UI_LINK" || -f "$UI_LINK" ]]; then
    rm -f "$UI_LINK"
    log "Atalho da UI removido: ${UI_LINK}"
  fi
  if [[ -d "${INSTALL_ROOT}/ui" ]]; then
    rm -rf "${INSTALL_ROOT}/ui"
    log "Interface grafica removida: ${INSTALL_ROOT}/ui"
  fi
}

render_unit() {
  local unit_id="$1"
  local folder="$2"
  local binary="$3"
  local description="$4"
  local unit_path="${SYSTEMD_UNIT_DIR}/${unit_id}.service"
  local template
  template="$(systemd_template_path)"

  install -d -m 0755 "$SYSTEMD_UNIT_DIR"
  sed \
    -e "s|{{DESCRIPTION}}|${description}|g" \
    -e "s|{{INSTALL_ROOT}}|${INSTALL_ROOT}|g" \
    -e "s|{{FOLDER}}|${folder}|g" \
    -e "s|{{BINARY}}|${binary}|g" \
    "$template" > "$unit_path"

  log "Unidade systemd criada: ${unit_path}"
}

stop_existing_services() {
  local conf
  conf="$(services_conf_path)"
  while IFS='|' read -r unit_id _ _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    if systemctl is-active --quiet "${unit_id}.service" 2>/dev/null; then
      log "Parando ${unit_id}.service..."
      systemctl stop "${unit_id}.service"
    fi
  done < "$conf"
}

install_files_from_payload() {
  local payload_dir="${PAYLOAD_DIR:?Informe PAYLOAD_DIR}"
  local conf
  conf="$(services_conf_path)"

  [[ -d "${payload_dir}/services" ]] || die "Payload de servicos nao encontrado em ${payload_dir}/services"
  [[ -f "${payload_dir}/cmd/desktop" ]] || die "CLI desktop nao encontrada em ${payload_dir}/cmd/desktop"

  log "Instalando arquivos em ${INSTALL_ROOT}..."
  install -d -m 0755 "${INSTALL_ROOT}/services" "${INSTALL_ROOT}/cmd"

  while IFS='|' read -r unit_id folder _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    local src="${payload_dir}/services/${folder}"
    local dest="${INSTALL_ROOT}/services/${folder}"
    [[ -d "$src" ]] || die "Servico ausente no payload: ${folder}"
    rm -rf "$dest"
    cp -a "$src" "$dest"
    if [[ -f "${dest}/${folder}" ]]; then
      chmod 0755 "${dest}/${folder}"
    fi
  done < "$conf"

  install -m 0755 "${payload_dir}/cmd/desktop" "${INSTALL_ROOT}/cmd/desktop"

  if [[ -n "${VERSION_FILE:-}" && -f "$VERSION_FILE" ]]; then
    install -m 0644 "$VERSION_FILE" "${INSTALL_ROOT}/VERSION"
  fi

  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}/services"
  chown root:root "${INSTALL_ROOT}/cmd/desktop"
}

configure_installed_payload() {
  local conf
  conf="$(services_conf_path)"

  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}/services"
  chown root:root "${INSTALL_ROOT}/cmd/desktop"
  chmod 0755 "${INSTALL_ROOT}/cmd/desktop"

  while IFS='|' read -r unit_id folder _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    if [[ -f "${INSTALL_ROOT}/services/${folder}/${folder}" ]]; then
      chmod 0755 "${INSTALL_ROOT}/services/${folder}/${folder}"
    fi
  done < "$conf"
}

install_cli() {
  log "Registrando CLI em ${CLI_LINK}..."
  ln -sf "${INSTALL_ROOT}/cmd/desktop" "$CLI_LINK"
}

register_services() {
  local conf
  conf="$(services_conf_path)"
  while IFS='|' read -r unit_id folder binary description; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    render_unit "$unit_id" "$folder" "$binary" "$description"
    systemctl daemon-reload
    systemctl enable "${unit_id}.service"
  done < "$conf"
}

start_services() {
  local conf
  conf="$(services_conf_path)"
  while IFS='|' read -r unit_id _ _ _; do
    [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
    log "Iniciando ${unit_id}.service..."
    systemctl start "${unit_id}.service"
  done < "$conf"
}

stop_and_disable_services() {
  local conf
  conf="$(services_conf_path)"
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
    if [[ "${REMOVE_SYSTEMD_UNITS:-1}" == "1" && -f "${SYSTEMD_UNIT_DIR}/${unit}" ]]; then
      rm -f "${SYSTEMD_UNIT_DIR}/${unit}"
      log "Removido ${unit}"
    fi
  done < "$conf"
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

install_from_staging() {
  require_root
  command -v systemctl >/dev/null 2>&1 || die "systemd nao encontrado neste sistema"

  log "Iniciando instalacao (${MANUFACTURER} DesktopServices)..."
  ensure_dotnet_runtime
  stop_existing_services
  ensure_service_user
  install -d -m 0755 "$(dirname "$INSTALL_ROOT")"
  install_files_from_payload
  install_ui_from_payload
  install_cli
  register_services
  start_services

  log "Instalacao concluida."
  log "  Diretorio: ${INSTALL_ROOT}"
  log "  CLI: desktop (disponivel em ${CLI_LINK})"
  if [[ -d "${INSTALL_ROOT}/ui" ]]; then
    log "  UI: desktop-ui (disponivel em ${UI_LINK})"
  fi
  log "  Servicos: systemctl status Desktop.Export (e demais unidades Desktop.*)"
}

configure_deb_installation() {
  require_root
  command -v systemctl >/dev/null 2>&1 || die "systemd nao encontrado neste sistema"

  SERVICES_CONF="/usr/share/desktopservices/services.conf"
  TEMPLATE="/usr/share/desktopservices/systemd.service.template"

  log "Configurando pacote Debian (${MANUFACTURER} DesktopServices)..."
  ensure_dotnet_runtime
  stop_existing_services
  ensure_service_user
  configure_installed_payload
  install_cli
  register_services
  start_services

  log "Configuracao do pacote concluida."
}

uninstall_desktopservices() {
  require_root
  log "Iniciando desinstalacao..."
  stop_and_disable_services
  remove_ui
  remove_cli
  remove_install_root
  remove_service_user
  log "Desinstalacao concluida."
}
