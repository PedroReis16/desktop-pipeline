#!/usr/bin/env bash
# Instala dependencias de build (.NET SDK, Go e ferramentas auxiliares).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GO_MOD="${REPO_ROOT}/desktop-cmd/go.mod"

DOTNET_CHANNEL="${DOTNET_CHANNEL:-10.0}"
DOTNET_INSTALL_DIR="${DOTNET_INSTALL_DIR:-}"
GO_INSTALL_DIR="${GO_INSTALL_DIR:-}"

if [[ -z "$DOTNET_INSTALL_DIR" ]]; then
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    DOTNET_INSTALL_DIR="/usr/share/dotnet"
  else
    DOTNET_INSTALL_DIR="${HOME}/.dotnet"
  fi
fi

if [[ -z "$GO_INSTALL_DIR" ]]; then
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    GO_INSTALL_DIR="/usr/local/go"
  else
    GO_INSTALL_DIR="${HOME}/.local/go"
  fi
fi

log() { printf '[install-build-deps] %s\n' "$*"; }
die() { printf '[install-build-deps] ERRO: %s\n' "$*" >&2; exit 1; }

run_as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "Permissao negada para: $*"
  fi
}

# Instalacoes em $HOME nao precisam de elevacao; usar sudo ali cria ~/.local
# (e similares) como root e quebra o cache do NuGet em CI (~/.local/share).
needs_sudo_for_dir() {
  local dir="$1"
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && return 1
  [[ "$dir" == "${HOME}"/* || "$dir" == "${HOME}" ]] && return 1
  return 0
}

run_for_dir() {
  local dir="$1"
  shift
  if needs_sudo_for_dir "$dir"; then
    run_as_root "$@"
  else
    "$@"
  fi
}

apt_get() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    apt-get "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get "$@"
  else
    die "Permissao negada para apt-get (instale dependencias manualmente ou use root)."
  fi
}

is_debian_like() {
  [[ -f /etc/debian_version ]]
}

read_go_version() {
  [[ -f "$GO_MOD" ]] || die "go.mod nao encontrado: $GO_MOD"
  grep -E '^go [0-9]+\.[0-9]+(\.[0-9]+)?' "$GO_MOD" | awk '{print $2}'
}

version_ge() {
  # Retorna 0 se $1 >= $2
  [[ "$(printf '%s\n%s' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

ensure_path() {
  local dir="$1"
  if [[ ":${PATH}:" != *":${dir}:"* ]]; then
    export PATH="${dir}:${PATH}"
  fi
  if [[ -n "${GITHUB_PATH:-}" && -d "$dir" ]]; then
    echo "$dir" >> "$GITHUB_PATH"
  fi
}

ensure_system_packages() {
  if [[ "${SKIP_APT:-0}" == "1" ]]; then
    return 0
  fi

  if ! is_debian_like; then
    log "Sistema nao Debian/Ubuntu — pulando apt (defina SKIP_APT=1 se intencional)."
    return 0
  fi

  log "Instalando pacotes de sistema..."
  export DEBIAN_FRONTEND=noninteractive
  apt_get update
  apt_get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dos2unix \
    git \
    gzip \
    tar \
    wget
}

ensure_dotnet() {
  if command -v dotnet >/dev/null 2>&1; then
    local installed
    installed="$(dotnet --version 2>/dev/null || true)"
    if [[ "$installed" == "${DOTNET_CHANNEL}"* ]]; then
      log ".NET SDK ${installed} ja disponivel."
      ensure_path "$DOTNET_INSTALL_DIR"
      return 0
    fi
    log ".NET ${installed:-desconhecido} encontrado; instalando canal ${DOTNET_CHANNEL}..."
  else
    log "Instalando .NET SDK ${DOTNET_CHANNEL}..."
  fi

  local installer="/tmp/dotnet-install.sh"
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
  run_for_dir "$DOTNET_INSTALL_DIR" bash "$installer" \
    --channel "$DOTNET_CHANNEL" \
    --install-dir "$DOTNET_INSTALL_DIR"

  ensure_path "$DOTNET_INSTALL_DIR"
  command -v dotnet >/dev/null 2>&1 || die "dotnet nao encontrado apos instalacao."
  log ".NET SDK instalado: $(dotnet --version)"
}

ensure_go() {
  local required
  required="$(read_go_version)"
  local current=""

  if command -v go >/dev/null 2>&1; then
    current="$(go env GOVERSION 2>/dev/null | sed 's/^go//')"
    if [[ -n "$current" ]] && version_ge "$current" "$required"; then
      log "Go ${current} ja disponivel (requerido >= ${required})."
      ensure_go_modules
      return 0
    fi
    log "Go ${current:-desconhecido} insuficiente; instalando Go ${required}..."
  else
    log "Instalando Go ${required}..."
  fi

  local arch="amd64"
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Arquitetura nao suportada para instalacao automatica do Go: $(uname -m)" ;;
  esac

  local tarball="go${required}.linux-${arch}.tar.gz"
  local url="https://go.dev/dl/${tarball}"
  local tmp="/tmp/${tarball}"

  curl -fsSL "$url" -o "$tmp"

  local go_root
  go_root="$(dirname "$GO_INSTALL_DIR")"
  run_for_dir "$GO_INSTALL_DIR" rm -rf "$GO_INSTALL_DIR"
  run_for_dir "$GO_INSTALL_DIR" mkdir -p "$go_root"
  run_for_dir "$GO_INSTALL_DIR" tar -C "$go_root" -xzf "$tmp"
  rm -f "$tmp"

  ensure_path "${GO_INSTALL_DIR}/bin"
  command -v go >/dev/null 2>&1 || die "go nao encontrado apos instalacao."
  log "Go instalado: $(go version)"
  ensure_go_modules
}

ensure_go_modules() {
  [[ -f "$GO_MOD" ]] || return 0
  log "Baixando modulos Go (go mod download)..."
  (
    cd "${REPO_ROOT}/desktop-cmd"
    go mod download
  )
}

main() {
  log "Verificando dependencias de build..."
  ensure_system_packages
  ensure_dotnet
  ensure_go
  log "Dependencias de build prontas."
}

main "$@"
