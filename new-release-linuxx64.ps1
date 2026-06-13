param(
    [string]$projectBuild = "",
    [string]$version = ""
)

$currentDir = Get-Location
$dockerImage = "mcr.microsoft.com/dotnet/sdk:8.0" # Imagem Docker com o SDK -> Ajustar confome a necessidade

if([string]::IsNullOrEmpty($projectBuild)){
    Write-Host "Necessario informar o tipo de build." -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrEmpty($version)){
    Write-Host "Necessario informar a versao do release." -ForegroundColor Red
    exit 1
}

if($projectBuild -ne "ServicesLinuxX64" -and $projectBuild -ne "HomologLinuxX64" ) {
    Write-Host "Tipo de build invalido. Opcoes validas: ServicesLinuxX64, HomologLinuxX64" -ForegroundColor Red
    exit 1
}

# 1. Limpar diretórios bin e obj
Write-Host "1. Limpando diretorios de build..." -ForegroundColor Cyan
$solutionRoot = Get-Location
Write-Host "  Buscando diretorios bin e obj na solucao..." -ForegroundColor Gray

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

Write-Host "=== LIMPEZA CONCLUIDA ===" -ForegroundColor Green

Write-Host "=== PREPARANDO AMBIENTE DOCKER ===" -ForegroundColor Cyan

# Verificando se Docker está rodando
docker info > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop nao esta rodando. Por favor, inicie o Docker." -ForegroundColor Red
    exit 1
}

# Diretório de saída no Windows
$outputDir = Join-Path $currentDir "Installers\Linux\bin\$projectBuild"
if (Test-Path $outputDir) { Remove-Item $outputDir -Recurse -Force }
New-Item -ItemType Directory -Path $outputDir | Out-Null

Write-Host "Iniciando compilacao no container Linux..." -ForegroundColor Yellow

# O comando Docker faz o seguinte:
# -v: Monta a pasta atual do Windows dentro do Linux em /src
# -v: Monta a pasta de saida do Windows dentro do Linux em /out
# -w: Define diretório de trabalho
# entrypoint: Executa bash
# O comando final converte o script para formato unix (caso haja erro de quebra de linha) e executa
docker run --rm `
    --name "desktopservices-linux-build" `
    -v "${currentDir}:/src" `
    -v "${outputDir}:/out" `
    -w "/src" `
    $dockerImage `
    /bin/bash -c "apt-get update && apt-get install -y dos2unix && dos2unix ./Installers/Linux/release-linux.sh && chmod +x ./Installers/Linux/release-linux.sh && ./Installers/Linux/release-linux.sh $projectBuild $version"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Linux concluido com sucesso!" -ForegroundColor Green
    Write-Host "Instalador disponivel em: $outputDir" -ForegroundColor Cyan
} else {
    Write-Host "Falha no Build Linux." -ForegroundColor Red
    exit 1
}