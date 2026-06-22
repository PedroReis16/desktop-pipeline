#!/usr/bin/env bash
# Gera AppImage portatil a partir do layout de instalacao.
set -euo pipefail

VERSION="${1:?Informe a versao}"
OUTPUT_DIR="${2:?Informe o diretorio de saida}"
LAYOUT="${3:?Informe o layout de instalacao}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE_NAME="DesktopServices-${VERSION}-x86_64.AppImage"
APPDIR="$(mktemp -d)"
APPIMAGETOOL="${APPIMAGETOOL:-/tmp/appimagetool-x86_64.AppImage}"
trap 'rm -rf "$APPDIR"' EXIT

cp -a "$LAYOUT/." "$APPDIR/"
install -d -m 0755 "${APPDIR}/lib"

cat > "${APPDIR}/AppRun" <<'EOF'
#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export APPIMAGE="${APPIMAGE:-$0}"
export DESKTOPSERVICES_ROOT="$HERE"

find_ui_executable() {
  local ui_dir="$1"
  local candidate
  for candidate in desktop-ui DesktopUI; do
    if [[ -x "${ui_dir}/${candidate}" ]]; then
      printf '%s\n' "${ui_dir}/${candidate}"
      return 0
    fi
  done
  return 1
}

launch_ui() {
  local ui_dir="$1"
  shift
  local exe
  exe="$(find_ui_executable "$ui_dir")" || {
    echo "Interface grafica nao encontrada em ${ui_dir}" >&2
    exit 1
  }
  exec "$exe" "$@"
}

case "${1:-}" in
  --install)
    shift
    exec bash "$HERE/install.sh" "$@"
    ;;
  --uninstall)
    shift
    exec bash "$HERE/uninstall.sh" "$@"
    ;;
  --ui)
    shift
    if [[ -d "${INSTALL_ROOT:-/opt/vigia/desktopservices}/ui" ]]; then
      launch_ui "${INSTALL_ROOT}/ui" "$@"
    fi
    launch_ui "$HERE/payload/ui" "$@"
    ;;
  --help|-h)
    cat <<USAGE
DesktopServices AppImage

Uso:
  $0 --ui               Abre a interface grafica (portatil ou instalada)
  $0 [opcoes]           Executa a CLI desktop
  $0 --install          Instala servicos systemd + UI (requer root)
  $0 --uninstall        Remove instalacao (requer root)
  $0 --help             Exibe esta ajuda

Instalacao:
  sudo $0 --install

Pacote .deb (Debian/Ubuntu, somente CLI + servicos):
  sudo dpkg -i desktopservices_<versao>_amd64.deb
USAGE
    exit 0
    ;;
  "")
    launch_ui "$HERE/payload/ui"
    ;;
  *)
    exec "$HERE/payload/cmd/desktop" "$@"
    ;;
esac
EOF
chmod 0755 "${APPDIR}/AppRun"

if [[ ! -x "$APPIMAGETOOL" ]]; then
  echo "Baixando appimagetool..."
  curl -fsSL \
    -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

mkdir -p "$OUTPUT_DIR"
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "${OUTPUT_DIR}/${APPIMAGE_NAME}"

printf 'AppImage gerado: %s\n' "${OUTPUT_DIR}/${APPIMAGE_NAME}"
