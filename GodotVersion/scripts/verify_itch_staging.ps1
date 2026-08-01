[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$StageDir,
    [string]$ExpectedChannel,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$itchRoot = Join-Path $projectDir 'build\itch'
if ([string]::IsNullOrWhiteSpace($StageDir)) {
    $StageDir = Join-Path $itchRoot "PCBuildingLife-$Version"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $itchRoot "itch-staging-audit-$Version.json"
}

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-File {
    param([string]$Path)
    Assert-Condition (Test-Path -LiteralPath $Path) "Required file not found: $Path"
}

function Read-Sha256File {
    param([string]$Path)
    Assert-File $Path
    return ((Get-Content -Raw -Encoding ASCII -LiteralPath $Path) -split '\s+')[0].Trim().ToLowerInvariant()
}

function Read-JsonFile {
    param([string]$Path)
    Assert-File $Path
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Test-HashMatch {
    param(
        [string]$Path,
        [string]$ExpectedHash
    )
    Assert-File $Path
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    return $actual -eq $ExpectedHash.ToLowerInvariant()
}

function Join-StagePath {
    param(
        [string]$Root,
        [string]$RelativePath
    )
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'Manifest contains an empty relative path.'
    Assert-Condition (-not [System.IO.Path]::IsPathRooted($RelativePath)) "Manifest path must be relative: $RelativePath"
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root ($RelativePath -replace '/', '\')))
    Assert-Condition ($fullPath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) "Manifest path escapes staging root: $RelativePath"
    return $fullPath
}

$stageFullPath = [System.IO.Path]::GetFullPath($StageDir)
$itchRootFullPath = [System.IO.Path]::GetFullPath($itchRoot)
Assert-Condition ($stageFullPath.StartsWith($itchRootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing staging path outside itch root: $stageFullPath"

$manifestPath = Join-Path $stageFullPath 'itch-upload-manifest.json'
$uploadManifestPath = Join-Path $stageFullPath 'upload-manifest.json'
$commandPath = Join-Path $stageFullPath 'butler-command.txt'

$manifest = Read-JsonFile -Path $manifestPath
$uploadManifest = Read-JsonFile -Path $uploadManifestPath
Assert-File $commandPath

Assert-Condition ([string]$manifest.version -eq $Version) "Manifest version mismatch: $($manifest.version)"
if ([string]::IsNullOrWhiteSpace($ExpectedChannel)) {
    $ExpectedChannel = [string]$manifest.channel
}
Assert-Condition (-not [string]::IsNullOrWhiteSpace($ExpectedChannel)) 'Expected itch channel is empty.'
Assert-Condition ([string]$manifest.channel -eq $ExpectedChannel) "Unexpected itch channel: $($manifest.channel)"
Assert-Condition ([string]$manifest.package_sha256 -match '^[0-9a-f]{64}$') 'Manifest package_sha256 is invalid.'
Assert-Condition ([string]$manifest.exe_sha256 -match '^[0-9a-f]{64}$') 'Manifest exe_sha256 is invalid.'
Assert-Condition ([string]$uploadManifest.package_sha256 -eq [string]$manifest.package_sha256) 'Upload manifest package hash does not match itch staging manifest.'
Assert-Condition ([string]$uploadManifest.exe_sha256 -eq [string]$manifest.exe_sha256) 'Upload manifest EXE hash does not match itch staging manifest.'

$packageZipPath = Join-StagePath -Root $stageFullPath -RelativePath ([string]$manifest.package_zip)
$packageShaPath = Join-StagePath -Root $stageFullPath -RelativePath ([string]$manifest.package_sha256_file)
$packageAuditPath = Join-Path $stageFullPath 'package\release-package-audit-report.json'

foreach ($required in @(
    $packageZipPath,
    $packageShaPath,
    $packageAuditPath,
    $uploadManifestPath,
    $commandPath
)) {
    Assert-File $required
}

$expectedPackageHash = Read-Sha256File -Path $packageShaPath
Assert-Condition ($expectedPackageHash -eq ([string]$manifest.package_sha256).ToLowerInvariant()) 'Staged package .sha256 does not match itch manifest.'
Assert-Condition (Test-HashMatch -Path $packageZipPath -ExpectedHash $expectedPackageHash) 'Staged package ZIP SHA-256 mismatch.'

$packageAudit = Read-JsonFile -Path $packageAuditPath
Assert-Condition ([bool]$packageAudit.ok) 'Staged package audit did not pass.'
Assert-Condition ([string]$packageAudit.package_sha256 -eq $expectedPackageHash) 'Staged package audit is stale or points at a different ZIP.'
Assert-Condition ([int]$packageAudit.player_flow_orders -eq 12) 'Staged package audit did not cover the 12-order player flow.'
Assert-Condition ([int]$packageAudit.first_order_audit_score -ge 90) 'Staged package first-order audit score is below S-grade threshold.'

$docFiles = @($manifest.doc_files)
Assert-Condition ($docFiles.Count -gt 0) 'itch staging manifest contains no documentation files.'
foreach ($docFile in $docFiles) {
    Assert-File (Join-Path $stageFullPath (Join-Path 'docs' ([string]$docFile)))
}

$requiredMedia = @(
    'cover-1920x1080.png',
    'channel-header-1920x620.png',
    'small-cover-630x500.png',
    'contact-sheet.png',
    'branding-sheet.png'
)
foreach ($mediaFile in $requiredMedia) {
    Assert-File (Join-Path $stageFullPath (Join-Path 'media' $mediaFile))
}

$commandText = Get-Content -Raw -Encoding UTF8 -LiteralPath $commandPath
foreach ($needle in @(
    'butler push',
    ":$ExpectedChannel",
    '--userversion',
    $Version,
    [string]$manifest.package_sha256,
    "verify_public_download.ps1 -PackageUrl '<ZIP URL>' -Sha256Url '<SHA-256 URL>'"
)) {
    Assert-Condition ($commandText.Contains($needle)) "butler-command.txt is missing expected content: $needle"
}
Assert-Condition ($commandText.Contains([System.IO.Path]::GetFileName($packageZipPath))) 'butler-command.txt does not reference the staged player ZIP.'
if ([bool]$manifest.hidden) {
    Assert-Condition ($commandText.Contains('--hidden')) 'butler-command.txt is missing --hidden for a hidden staging upload.'
}
else {
    Assert-Condition (-not $commandText.Contains('--hidden')) 'butler-command.txt contains --hidden, but manifest.hidden is false.'
}
if ([bool]$manifest.if_changed) {
    Assert-Condition ($commandText.Contains('--if-changed')) 'butler-command.txt is missing --if-changed for an if-changed staging upload.'
}

$report = [ordered]@{
    ok = $true
    version = $Version
    stage_path = $stageFullPath
    package_zip = $packageZipPath
    package_sha256 = $expectedPackageHash
    exe_sha256 = [string]$manifest.exe_sha256
    channel = [string]$manifest.channel
    pushed = [bool]$manifest.pushed
    doc_count = $docFiles.Count
    media_count = $requiredMedia.Count
    butler_available = [bool]$manifest.butler_available
    butler_command_file = $commandPath
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
}

$reportDir = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host '[itch-staging-verify] ok'
Write-Host "[itch-staging-verify] $stageFullPath"
Write-Host "[itch-staging-verify] sha256=$expectedPackageHash"
Write-Host "[itch-staging-verify] report=$ReportPath"
