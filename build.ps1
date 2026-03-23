param(
    [Parameter(Mandatory = $false)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "artifacts"
)

$ErrorActionPreference = 'Stop'

$moduleName = 'AudioDeviceCmdlets'
$repoRoot = Split-Path -Parent $PSCommandPath
$projectPath = Join-Path $repoRoot "$moduleName.csproj"
$outputDirFull = Join-Path $repoRoot $OutputDir
$moduleDir = Join-Path $outputDirFull $moduleName

if ([string]::IsNullOrWhiteSpace($Version)) {
    [xml]$project = Get-Content -LiteralPath $projectPath
    $Version = $project.Project.PropertyGroup.Version | Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw "Version property not found in $projectPath"
    }
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "dotnet SDK is required to build. Install from https://aka.ms/dotnet/download (GitHub Actions uses actions/setup-dotnet)."
}

if (Test-Path $moduleDir) {
    Remove-Item -LiteralPath $moduleDir -Recurse -Force
}
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

dotnet build $projectPath -c $Configuration

$dllPath = Join-Path $repoRoot "bin\$Configuration\netstandard2.0\$moduleName.dll"
if (-not (Test-Path $dllPath)) {
    throw "Build output not found: $dllPath"
}
Copy-Item -LiteralPath $dllPath -Destination (Join-Path $moduleDir "$moduleName.dll") -Force

$manifestPath = Join-Path $moduleDir "$moduleName.psd1"
$manifestParams = @{
    Path                 = $manifestPath
    RootModule           = "$moduleName.dll"
    ModuleVersion        = $Version
    Guid                 = '7156b1c0-8e86-4d19-8df1-058c15629f36'
    Author               = 'frgnca (fork: mefranklin6)'
    CompanyName          = 'frgnca'
    Description          = 'A suite of PowerShell Cmdlets to control audio devices on Windows.'
    CompatiblePSEditions = @('Desktop', 'Core')
    PowerShellVersion    = '5.1'
    CmdletsToExport      = @('Get-AudioDevice', 'Set-AudioDevice', 'Write-AudioDevice')
    FunctionsToExport    = @()
    AliasesToExport      = @()
}
New-ModuleManifest @manifestParams | Out-Null

"Built module to: $moduleDir" | Write-Host
