#!/usr/bin/env bash
# Build local/CI do instalador Linux (servicos + desktop-cmd).
set -euo pipefail

PROJECT_BUILD="${1:?Informe ServicesLinuxX64 ou HomologLinuxX64}"
VERSION="${2:?Informe a versao}"
OUT_DIR="${OUT_DIR:-/out}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGING="${OUT_DIR}/staging"
RID="linux-x64"

log() { printf '[release-linux] %s\n' "$*"; }

declare -A SERVICES=(
  ["Desktop.Export"]="workerservices/Desktop.Export/Desktop.Export.csproj|workerservices/Desktop.Export/Properties/PublishProfiles/linux-x64.pubxml"
  ["Desktop.Import"]="workerservices/Desktop.Import/Desktop.Import.csproj|workerservices/Desktop.Import/Properties/PublishProfiles/linux-x64.pubxml"
  ["Desktop.Instance"]="workerservices/Desktop.Instance/Desktop.Instance.csproj|workerservices/Desktop.Instance/Properties/PublishProfiles/linux-x64.pubxml"
  ["Desktop.Integration"]="workerservices/Desktop.Integration/Desktop.Integration.csproj|workerservices/Desktop.Integration/Properties/PublishProfiles/linux-x64.pubxml"
  ["Desktop.InterfaceAPI"]="workerservices/Desktop.InterfaceAPI/Desktop.InterfaceAPI.csproj|workerservices/Desktop.InterfaceAPI/Properties/PublishProfiles/linux-x64.pubxml"
)

cd "$REPO_ROOT"

log "Instalando dependencias de build (.NET, Go)..."
bash "${REPO_ROOT}/installers/linux/install-build-deps.sh"

log "Limpando staging..."
rm -rf "$STAGING"
mkdir -p "$STAGING/payload-desktop-cmd"

log "Restore + build solucao .NET..."
dotnet clean ./workerservices/DesktopServices.slnx --configuration "$PROJECT_BUILD"
dotnet restore ./workerservices/DesktopServices.slnx \
  -r "$RID" \
  /p:Configuration="$PROJECT_BUILD" /p:Platform=x64 /p:PublishReadyToRun=true
dotnet build ./workerservices/DesktopServices.slnx \
  --configuration "$PROJECT_BUILD" /p:Platform=x64 --no-restore

for name in "${!SERVICES[@]}"; do
  IFS='|' read -r csproj profile <<< "${SERVICES[$name]}"
  artifact_id="$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr '.' '-')"
  dest="${STAGING}/payload-${artifact_id}"
  log "Publicando ${name}..."
  dotnet publish "$csproj" \
    /p:PublishProfile="$profile" \
    --configuration "$PROJECT_BUILD" /p:Platform=x64 \
    /p:Version="$VERSION" --no-restore
  publish_dir="${REPO_ROOT}/workerservices/${name}/bin/x64/${PROJECT_BUILD}/net10.0/publish/${name}"
  mkdir -p "$dest"
  cp -a "${publish_dir}/." "$dest/"
done

log "Compilando desktop-cmd..."
pushd desktop-cmd >/dev/null
mkdir -p bin
GOOS=linux GOARCH=amd64 go build -ldflags "-s -w -X main.version=${VERSION}" -o bin/desktop ./cmd/desktop
popd >/dev/null
cp desktop-cmd/bin/desktop "${STAGING}/payload-desktop-cmd/"

log "Compilando desktop-ui..."
INSTALL_ELECTRON_DEPS=1 bash "${REPO_ROOT}/installers/linux/install-build-deps.sh"
pushd desktop-ui >/dev/null
if command -v npm >/dev/null 2>&1; then
  npm ci
  npm run build:electron
  npx electron-builder build --linux dir --config.extraMetadata.version="${VERSION}"
  mkdir -p "${STAGING}/payload-desktop-ui"
  cp -a dist_electron/linux-unpacked/. "${STAGING}/payload-desktop-ui/"
else
  log "ERRO: npm nao encontrado — necessario para compilar desktop-ui no AppImage"
  exit 1
fi
popd >/dev/null

log "Empacotando artefatos Linux (.deb + AppImage)..."
bash "${REPO_ROOT}/installers/linux/package-installer.sh" "$VERSION" "$OUT_DIR" "$STAGING"

log "Build Linux concluido."
