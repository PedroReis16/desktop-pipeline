#!/usr/bin/env bash
# Gera pacote .deb a partir do layout de instalacao.
set -euo pipefail

VERSION="${1:?Informe a versao}"
OUTPUT_DIR="${2:?Informe o diretorio de saida}"
LAYOUT="${3:?Informe o layout de instalacao}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_VERSION="${VERSION//-/.}"
[[ "$DEB_VERSION" =~ ^[0-9] ]] || DEB_VERSION="0${DEB_VERSION}"
PACKAGE_FILE="${OUTPUT_DIR}/desktopservices_${DEB_VERSION}_amd64.deb"
PKG_ROOT="$(mktemp -d)"
trap 'rm -rf "$PKG_ROOT"' EXIT

install -d -m 0755 \
  "${PKG_ROOT}/DEBIAN" \
  "${PKG_ROOT}/opt/vigia/desktopservices/services" \
  "${PKG_ROOT}/opt/vigia/desktopservices/cmd" \
  "${PKG_ROOT}/usr/share/desktopservices" \
  "${PKG_ROOT}/usr/local/bin" \
  "${PKG_ROOT}/lib/systemd/system"

cp -a "${LAYOUT}/payload/services/." "${PKG_ROOT}/opt/vigia/desktopservices/services/"
install -m 0755 "${LAYOUT}/payload/cmd/desktop" "${PKG_ROOT}/opt/vigia/desktopservices/cmd/desktop"
install -m 0644 "${LAYOUT}/VERSION" "${PKG_ROOT}/opt/vigia/desktopservices/VERSION"
install -m 0644 "${LAYOUT}/services.conf" "${PKG_ROOT}/usr/share/desktopservices/services.conf"
install -m 0644 "${LAYOUT}/templates/systemd.service.template" \
  "${PKG_ROOT}/usr/share/desktopservices/systemd.service.template"
install -m 0644 "${ROOT}/lib/install-common.sh" "${PKG_ROOT}/usr/share/desktopservices/install-common.sh"

while IFS='|' read -r unit_id folder binary description; do
  [[ -z "$unit_id" || "$unit_id" == \#* ]] && continue
  sed \
    -e "s|{{DESCRIPTION}}|${description}|g" \
    -e "s|{{INSTALL_ROOT}}|/opt/vigia/desktopservices|g" \
    -e "s|{{FOLDER}}|${folder}|g" \
    -e "s|{{BINARY}}|${binary}|g" \
    "${LAYOUT}/templates/systemd.service.template" \
    > "${PKG_ROOT}/lib/systemd/system/${unit_id}.service"
done < "${LAYOUT}/services.conf"

ln -sf /opt/vigia/desktopservices/cmd/desktop "${PKG_ROOT}/usr/local/bin/desktop"

installed_size="$(du -sk "$PKG_ROOT" | awk '{print $1}')"

cat > "${PKG_ROOT}/DEBIAN/control" <<EOF
Package: desktopservices
Version: ${DEB_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Vigia <suporte@vigia.com.br>
Depends: systemd, adduser
Installed-Size: ${installed_size}
Homepage: https://github.com/vigia/desktop-pipeline
Description: Vigia Desktop Services (CLI + servicos)
 Servicos em background e CLI para integracao do Desktop Vigia.
 .
 Inclui Desktop.Export, Desktop.Import, Desktop.Instance,
 Desktop.Integration e Desktop.InterfaceAPI.
 O runtime .NET 10 e instalado automaticamente na configuracao.
EOF

cat > "${PKG_ROOT}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e
case "$1" in
  configure)
    . /usr/share/desktopservices/install-common.sh
    configure_deb_installation
    ;;
esac
exit 0
EOF

cat > "${PKG_ROOT}/DEBIAN/prerm" <<'EOF'
#!/bin/bash
set -e
case "$1" in
  remove|upgrade|deconfigure)
    if [[ -f /usr/share/desktopservices/install-common.sh ]]; then
      # shellcheck source=/dev/null
      . /usr/share/desktopservices/install-common.sh
      SERVICES_CONF="/usr/share/desktopservices/services.conf"
      REMOVE_SYSTEMD_UNITS=0
      stop_and_disable_services
      remove_cli
    fi
    ;;
esac
exit 0
EOF

cat > "${PKG_ROOT}/DEBIAN/postrm" <<'EOF'
#!/bin/bash
set -e
case "$1" in
  purge)
    if [[ -f /usr/share/desktopservices/install-common.sh ]]; then
      # shellcheck source=/dev/null
      . /usr/share/desktopservices/install-common.sh
      remove_install_root
      remove_service_user
    fi
    ;;
esac
exit 0
EOF

chmod 0755 "${PKG_ROOT}/DEBIAN/postinst" "${PKG_ROOT}/DEBIAN/prerm" "${PKG_ROOT}/DEBIAN/postrm"

mkdir -p "$OUTPUT_DIR"
fakeroot dpkg-deb --build --root-owner-group "$PKG_ROOT" "$PACKAGE_FILE"

printf 'Pacote .deb gerado: %s\n' "$PACKAGE_FILE"
