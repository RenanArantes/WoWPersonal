# Uso (uma vez): autentique e publique
#   1) & "C:\Program Files\GitHub CLI\gh.exe" auth login -h github.com -p https -w
#   2) .\Push-ToGitHub.ps1

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
Set-Location $repoRoot

$gh = "C:\Program Files\GitHub CLI\gh.exe"
if (-not (Test-Path $gh)) {
    $gh = Join-Path $env:TEMP "gh-portable\bin\gh.exe"
}
if (-not (Test-Path $gh)) {
    Write-Error "Instale o GitHub CLI (winget install GitHub.cli) ou extraia gh para $env:TEMP\gh-portable\bin\"
}

$ErrorActionPreference = "SilentlyContinue"
& $gh auth status *> $null
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Execute primeiro: & `"$gh`" auth login -h github.com -p https -w"
    exit 1
}

if (git remote get-url origin 2>$null) {
    git remote remove origin
}

& $gh repo create WoWPersonal --public --source=. --remote=origin --push
