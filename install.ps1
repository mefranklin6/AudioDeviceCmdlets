param(
    [Parameter(Mandatory = $false)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
)

$ErrorActionPreference = 'Stop'

$repo = 'mefranklin6/AudioDeviceCmdlets'
$moduleName = 'AudioDeviceCmdlets'

if (-not $Version) {
    throw "Version is required (example: -Version 3.2). Install from 'latest' is intentionally not supported to keep installs deterministic."
}

$versionNoV = if ($Version.StartsWith('v')) { $Version.Substring(1) } else { $Version }
$tag = "v$versionNoV"
$assetName = "$moduleName-$versionNoV.zip"
$downloadUrl = "https://github.com/$repo/releases/download/$tag/$assetName"

$tempDir = Join-Path $env:TEMP "$moduleName-$versionNoV"
if (Test-Path $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$zipPath = Join-Path $tempDir $assetName
$iwrParams = @{ Uri = $downloadUrl; OutFile = $zipPath }
if ((Get-Command Invoke-WebRequest).Parameters.ContainsKey('UseBasicParsing')) {
    $iwrParams.UseBasicParsing = $true
}
Invoke-WebRequest @iwrParams

$modulePath = if ($Scope -eq 'AllUsers') {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Join-Path $env:ProgramFiles "PowerShell\\Modules"
    }
    else {
        Join-Path $env:ProgramFiles "WindowsPowerShell\\Modules"
    }
}
else {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Join-Path $HOME "Documents\\PowerShell\\Modules"
    }
    else {
        Join-Path $HOME "Documents\\WindowsPowerShell\\Modules"
    }
}

New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

$extractDir = Join-Path $tempDir 'extracted'
if (Test-Path $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

try {
    Unblock-File -LiteralPath $zipPath -ErrorAction SilentlyContinue
}
catch {
    # Best-effort only.
}

Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

# Find the module root (folder containing AudioDeviceCmdlets.psd1). GitHub release zips can
# include an extra top-level folder, so we locate the manifest rather than assuming layout.
$manifest = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter "$moduleName.psd1" | Select-Object -First 1
if (-not $manifest) {
    throw "Install failed: module manifest '$moduleName.psd1' not found inside the downloaded zip ($assetName)."
}

$sourceModuleDir = Split-Path -Parent $manifest.FullName
$destModuleDir = Join-Path $modulePath $moduleName

if (Test-Path $destModuleDir) {
    Remove-Item -LiteralPath $destModuleDir -Recurse -Force
}
New-Item -ItemType Directory -Path $destModuleDir -Force | Out-Null

Get-ChildItem -LiteralPath $sourceModuleDir -Force | Copy-Item -Destination $destModuleDir -Recurse -Force

try {
    Get-ChildItem -LiteralPath $destModuleDir -Recurse -File | ForEach-Object {
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }
}
catch {
    # Best-effort only.
}

Import-Module (Join-Path $destModuleDir "$moduleName.psd1") -Force

"Installed $moduleName $Version to: $destModuleDir" | Write-Host
