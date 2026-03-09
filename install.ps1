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

$tag = if ($Version.StartsWith('v')) { $Version } else { "v$Version" }
$assetName = "$moduleName-$Version.zip"
$downloadUrl = "https://github.com/$repo/releases/download/$tag/$assetName"

$tempDir = Join-Path $env:TEMP "$moduleName-$Version"
if (Test-Path $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$zipPath = Join-Path $tempDir $assetName
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

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

Expand-Archive -LiteralPath $zipPath -DestinationPath $modulePath -Force
Import-Module $moduleName -Force

"Installed $moduleName $Version to: $modulePath" | Write-Host
