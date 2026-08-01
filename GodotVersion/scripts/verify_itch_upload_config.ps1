[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$ConfigPath,
    [switch]$AllowPlaceholder,
    [switch]$RequireTarget,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseDir = Join-Path $projectDir 'release'
$itchRoot = Join-Path $projectDir 'build\itch'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $localConfigPath = Join-Path $releaseDir 'itch-upload-config.local.json'
    $exampleConfigPath = Join-Path $releaseDir 'itch-upload-config.example.json'
    if (Test-Path -LiteralPath $localConfigPath) {
        $ConfigPath = $localConfigPath
    }
    else {
        $ConfigPath = $exampleConfigPath
        $AllowPlaceholder = $true
    }
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $itchRoot "itch-upload-config-audit-$Version.json"
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

function Read-OptionalString {
    param(
        [object]$Config,
        [string]$Name,
        [string]$DefaultValue = ''
    )
    if ($Config.PSObject.Properties.Name -contains $Name -and $null -ne $Config.$Name) {
        return [string]$Config.$Name
    }
    return $DefaultValue
}

function Read-OptionalBool {
    param(
        [object]$Config,
        [string]$Name,
        [bool]$DefaultValue = $false
    )
    if ($Config.PSObject.Properties.Name -contains $Name -and $null -ne $Config.$Name) {
        return [bool]$Config.$Name
    }
    return $DefaultValue
}

$configFullPath = [System.IO.Path]::GetFullPath($ConfigPath)
Assert-File $configFullPath
$config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configFullPath | ConvertFrom-Json

$target = Read-OptionalString -Config $config -Name 'itch_target'
$channel = Read-OptionalString -Config $config -Name 'channel' -DefaultValue 'windows-demo'
$hidden = Read-OptionalBool -Config $config -Name 'hidden' -DefaultValue $true
$ifChanged = Read-OptionalBool -Config $config -Name 'if_changed' -DefaultValue $true
$packageUrl = Read-OptionalString -Config $config -Name 'public_package_url'
$shaUrl = Read-OptionalString -Config $config -Name 'public_sha256_url'

$isPlaceholderTarget = $target -eq '<itch-user>/<itch-game>'
$targetLooksValid = $target -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
$channelLooksValid = $channel -match '^[A-Za-z0-9_.-]+$'
$hasPackageUrl = -not [string]::IsNullOrWhiteSpace($packageUrl)
$hasShaUrl = -not [string]::IsNullOrWhiteSpace($shaUrl)

Assert-Condition (-not [string]::IsNullOrWhiteSpace($target)) 'itch_target is required.'
if ($RequireTarget) {
    Assert-Condition (-not $isPlaceholderTarget) 'RequireTarget was set, but itch_target is still the placeholder.'
}
if ($isPlaceholderTarget) {
    Assert-Condition $AllowPlaceholder 'itch_target is still the placeholder. Copy the example to itch-upload-config.local.json and set the real target.'
}
else {
    Assert-Condition $targetLooksValid "itch_target must look like itch-user/itch-game, got: $target"
}
Assert-Condition $channelLooksValid "channel must contain only letters, numbers, dot, dash, or underscore, got: $channel"
Assert-Condition ($hasPackageUrl -eq $hasShaUrl) 'public_package_url and public_sha256_url must be set together or both left empty.'
if ($hasPackageUrl) {
    Assert-Condition ($packageUrl -match '^https?://') "public_package_url must start with http:// or https://, got: $packageUrl"
    Assert-Condition ($shaUrl -match '^https?://') "public_sha256_url must start with http:// or https://, got: $shaUrl"
}

$audit = [ordered]@{
    ok = $true
    version = $Version
    config_path = $configFullPath
    itch_target = if ($isPlaceholderTarget) { $null } else { $target }
    itch_target_is_placeholder = $isPlaceholderTarget
    channel = $channel
    hidden = $hidden
    if_changed = $ifChanged
    public_urls_configured = ($hasPackageUrl -and $hasShaUrl)
    public_package_url = if ($hasPackageUrl) { $packageUrl } else { $null }
    public_sha256_url = if ($hasShaUrl) { $shaUrl } else { $null }
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
}

$reportDir = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
}
$audit | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host '[itch-config-verify] ok'
Write-Host "[itch-config-verify] config=$configFullPath"
Write-Host "[itch-config-verify] target_placeholder=$isPlaceholderTarget channel=$channel hidden=$hidden if_changed=$ifChanged public_urls=$($hasPackageUrl -and $hasShaUrl)"
Write-Host "[itch-config-verify] report=$ReportPath"
