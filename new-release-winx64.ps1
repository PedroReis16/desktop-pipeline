param(
    [string]$projectBuild = "",
    [string]$version = ""
)

if([string]::IsNullOrEmpty($projectBuild)){
    Write-Host "Necessario informar o tipo de build." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrEmpty($version)){
    Write-Host "Necessario informar a versao do release." -ForegroundColor Red
    exit 1
}
$version = $version.Trim()
if ([string]::IsNullOrEmpty($version)){
    Write-Host "Necessario informar a versao do release." -ForegroundColor Red
    exit 1
}

if($projectBuild -ne "ServicesWinX64" -and $projectBuild -ne "HomologWinX64") {
    Write-Host "Tipo de build invalido. Opcoes validas: ServicesWinX64, HomologWinX64" -ForegroundColor Red
    exit 1
}

# 1. Limpar diretórios bin e obj
Write-Host "1. Limpando diretorios de build..." -ForegroundColor Cyan
$solutionRoot = Get-Location
Write-Host "  Buscando diretorios bin e obj na solucao..." -ForegroundColor Cyan

$projectFiles = Get-ChildItem -Path $solutionRoot -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue

$buildDirs = @()

foreach ($projectFile in $projectFiles) {
    $projectDir = $projectFile.DirectoryName
    $binDir = Join-Path $projectDir "bin"
    $objDir = Join-Path $projectDir "obj"

    if (Test-Path $binDir) { $buildDirs += $binDir }
    if (Test-Path $objDir) { $buildDirs += $objDir }
}

foreach ($dir in $buildDirs | Select-Object -Unique) {
    try {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
        Write-Host "Removido diretorio: $dir"
    }
    catch {
        Write-Warning "Falha ao remover diretorio: $dir"
    }
}

# 2. Executar dotnet clean
Write-Host "2. Executando dotnet clean..." -ForegroundColor Cyan
dotnet clean ./workerservices/DesktopServices.sln --configuration $projectBuild

# 3. Restaurar pacotes
Write-Host "3. Restaurando pacotes NuGet..." -ForegroundColor Cyan

# Restore com RID, configuracao e plataforma para alinhar com os perfis de publish (evita NETSDK1047/NETSDK1094 com --no-restore)
dotnet restore ./workerservices/DesktopServices.sln -r win-x64 /p:Configuration=$projectBuild /p:Platform=x64 /p:PublishReadyToRun=true
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore da solucao workerservices com RID win-x64 falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== LIMPEZA CONCLUIDA ===" -ForegroundColor Green

Write-Host "=== INICIANDO PUBLICACAO DOS PROJETOS  ===" -ForegroundColor Cyan

dotnet build ./workerservices/DesktopServices.sln --configuration $projectBuild /p:Platform=x64 --no-restore
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto DesktopServices.sln falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== INICIANDO PUBLICACAO DO Desktop.Export ===" -ForegroundColor Cyan

dotnet publish ./workerservices/Desktop.Export/Desktop.Export.csproj /p:PublishProfile=./workerservices/Desktop.Export/Properties/PublishProfiles/win-x64.pubxml --configuration $projectBuild /p:Platform=x64 /p:Version=$version --no-restore
if($LASTEXITCODE -ne 0) {
    Write-Host "Publish do projeto Desktop.Export falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== INICIANDO PUBLICACAO DO Desktop.Import ===" -ForegroundColor Cyan

dotnet publish ./workerservices/Desktop.Import/Desktop.Import.csproj /p:PublishProfile=./workerservices/Desktop.Import/Properties/PublishProfiles/win-x64.pubxml --configuration $projectBuild /p:Platform=x64 /p:Version=$version --no-restore
if($LASTEXITCODE -ne 0) {
    Write-Host "Publish do projeto Desktop.Import falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== INICIANDO PUBLICACAO DO Desktop.Instance ===" -ForegroundColor Cyan

dotnet publish ./workerservices/Desktop.Instance/Desktop.Instance.csproj /p:PublishProfile=./workerservices/Desktop.Instance/Properties/PublishProfiles/win-x64.pubxml --configuration $projectBuild /p:Platform=x64 /p:Version=$version --no-restore
if($LASTEXITCODE -ne 0) {
    Write-Host "Publish do projeto Desktop.Instance falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== INICIANDO PUBLICACAO DO Desktop.Integration ===" -ForegroundColor Cyan

dotnet publish ./workerservices/Desktop.Integration/Desktop.Integration.csproj /p:PublishProfile=./workerservices/Desktop.Integration/Properties/PublishProfiles/win-x64.pubxml --configuration $projectBuild /p:Platform=x64 /p:Version=$version --no-restore
if($LASTEXITCODE -ne 0) {
    Write-Host "Publish do projeto Desktop.Integration falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== INICIANDO PUBLICACAO DO Desktop.InterfaceAPI ===" -ForegroundColor Cyan

dotnet publish ./workerservices/Desktop.InterfaceAPI/Desktop.InterfaceAPI.csproj /p:PublishProfile=./workerservices/Desktop.InterfaceAPI/Properties/PublishProfiles/win-x64.pubxml --configuration $projectBuild /p:Platform=x64 /p:Version=$version --no-restore
if($LASTEXITCODE -ne 0) {
    Write-Host "Publish do projeto Desktop.InterfaceAPI falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== INICIANDO BUILD DO Desktop CMD (Go -> desktop.exe) ===" -ForegroundColor Cyan
$cmdRoot = Join-Path $solutionRoot "desktop-cmd"
if (-not (Test-Path $cmdRoot)) {
    Write-Host "Pasta desktop-cmd nao encontrada em: $cmdRoot" -ForegroundColor Red
    exit 1
}
$prevGoos = $env:GOOS
$prevGoarch = $env:GOARCH
Push-Location $cmdRoot
try {
    $binDir = Join-Path $cmdRoot "bin"
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    go build -ldflags "-s -w" -o (Join-Path $binDir "desktop.exe") ./cmd/desktop
    if($LASTEXITCODE -ne 0) {
        Write-Host "go build em desktop-cmd falhou. Build cancelado." -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    if ([string]::IsNullOrEmpty($prevGoos)) { Remove-Item Env:GOOS -ErrorAction SilentlyContinue } else { $env:GOOS = $prevGoos }
    if ([string]::IsNullOrEmpty($prevGoarch)) { Remove-Item Env:GOARCH -ErrorAction SilentlyContinue } else { $env:GOARCH = $prevGoarch }
    Pop-Location
}
$cmdExe = Join-Path $cmdRoot "bin\desktop.exe"
if (-not (Test-Path $cmdExe)) {
    Write-Host "Executavel Desktop nao encontrado (esperado: $cmdExe)" -ForegroundColor Red
    exit 1
}
Write-Host "CLI Desktop gerado: $cmdExe" -ForegroundColor Green

Write-Host "=== INICIANDO BUILD DO DESKTOP-UI (Angular + Electron -> MSI) ===" -ForegroundColor Cyan
$uiDir = Join-Path $solutionRoot "desktop-ui"
if (-not (Test-Path $uiDir)) {
    Write-Host "Pasta desktop-ui nao encontrada em: $uiDir" -ForegroundColor Red
    exit 1
}
Push-Location $uiDir
try {
    if (Test-Path "package-lock.json") {
        npm ci
    } else {
        npm install
    }
    if($LASTEXITCODE -ne 0) {
        Write-Host "npm install/ci em desktop-ui falhou. Build cancelado." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    npm run build:electron
    if($LASTEXITCODE -ne 0) {
        Write-Host "build:electron falhou. Build cancelado." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    npx electron-builder build --win --config.extraMetadata.version=$version
    if($LASTEXITCODE -ne 0) {
        Write-Host "electron-builder (MSI Windows) falhou. Build cancelado." -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

$electronMsi = Join-Path $uiDir "dist_electron\Desktop.Desktop.msi"
if (-not (Test-Path $electronMsi)) {
    Write-Host "MSI do Electron nao encontrado (esperado: $electronMsi). Verifique build.win.artifactName em desktop-ui/package.json." -ForegroundColor Red
    exit 1
}
$bundlePayloadDir = Join-Path $solutionRoot "installers\windows\Desktop.ServicesInstaller\bundle-payloads"
New-Item -ItemType Directory -Force -Path $bundlePayloadDir | Out-Null
Copy-Item -Path $electronMsi -Destination (Join-Path $bundlePayloadDir "Desktop.Desktop.msi") -Force
Write-Host "MSI da interface copiado para o bundle: $(Join-Path $bundlePayloadDir 'Desktop.Desktop.msi')" -ForegroundColor Green


Write-Host "=== INICIANDO BUILD DOS INSTALADORES ===" -ForegroundColor Cyan

Write-Host "=== RESTAURANDO PROJETOS DE INSTALADORES (WIX) ===" -ForegroundColor Cyan
dotnet restore ./installers/windows/Desktop.InstallerShared/Desktop.InstallerShared.wixproj
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.InstallerShared falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.Export.Installer/Desktop.Export.Installer.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.Export.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.Import.Installer/Desktop.Import.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.Import.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.Instance.Installer/Desktop.Instance.Installer.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.Instance.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.Integration.Installer/Desktop.Integration.Installer.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.Integration.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.InterfaceAPI.Installer/Desktop.InterfaceAPI.Installer.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.InterfaceAPI.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.Cmd.Installer/Desktop.Cmd.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.Cmd.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet restore ./installers/windows/Desktop.ServicesInstaller/Desktop.ServicesInstaller.wixproj /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Restore do projeto Desktop.ServicesInstaller falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}


dotnet build ./installers/windows/Desktop.InstallerShared/ --configuration $projectBuild /p:Platform=x64

if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.InstallerShared falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet build ./installers/windows/Desktop.Export.Installer/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.Export.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet build ./installers/windows/Desktop.Import.Installer/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.Import.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet build ./installers/windows/Desktop.Instance.Installer/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.Instance.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet build ./installers/windows/Desktop.Integration.Installer/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.Integration.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet build ./installers/windows/Desktop.InterfaceAPI.Installer/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.InterfaceAPI.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}

dotnet build ./installers/windows/Desktop.Cmd.Installer/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"
if($LASTEXITCODE -ne 0) {
    Write-Host "Build do projeto Desktop.Cmd.Installer falhou. Build cancelado." -ForegroundColor Red
    exit $LASTEXITCODE
}


dotnet build ./installers/windows/Desktop.ServicesInstaller/ --configuration $projectBuild /p:Platform=x64 /p:VersionNumber="$version" /p:Version="$version"