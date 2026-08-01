[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$ConfigPath,
    [switch]$Push,
    [string]$PackageUrl,
    [string]$Sha256Url,
    [switch]$RequireGo,
    [string]$ReportDir
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildDir = Join-Path $projectDir 'build\windows'
$releaseDir = Join-Path $projectDir 'release'
if ([string]::IsNullOrWhiteSpace($ReportDir)) {
    $ReportDir = Join-Path $projectDir 'build\public-release-go'
}
$ReportDir = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$localConfigPath = Join-Path $releaseDir 'itch-upload-config.local.json'
$exampleConfigPath = Join-Path $releaseDir 'itch-upload-config.example.json'
$publishEnvironmentPath = Join-Path $projectDir "build\publish\publish-environment-audit-$Version.json"
$releaseReadinessPath = Join-Path $projectDir "build\release-readiness\release-readiness-$Version.json"
$publicGatePath = Join-Path $projectDir "build\public-release-go\public-release-go-$Version.json"
$itchManifestPath = Join-Path $projectDir "build\itch\PCBuildingLife-$Version\itch-upload-manifest.json"

$steps = @()
$cycleFailed = $false
$pushPerformed = $false

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Read-OptionalString {
    param(
        [object]$Value,
        [string]$Name
    )
    if ($null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name -and $null -ne $Value.$Name) {
        return [string]$Value.$Name
    }
    return ''
}

function Add-Step {
    param(
        [string]$Name,
        [ValidateSet('pass', 'pending', 'skipped', 'fail')]
        [string]$Status,
        [string]$Detail
    )
    $script:steps += [ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
    }
    if ($Status -eq 'fail') {
        $script:cycleFailed = $true
    }
}

function Invoke-CycleStep {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [string]$SuccessDetail
    )

    try {
        $global:LASTEXITCODE = 0
        & $Action
        if ($LASTEXITCODE -ne 0) {
            throw "$Name exited with code $LASTEXITCODE."
        }
        Add-Step -Name $Name -Status 'pass' -Detail $SuccessDetail
        return $true
    }
    catch {
        Add-Step -Name $Name -Status 'fail' -Detail $_.Exception.Message
        return $false
    }
}

Assert-Condition (Test-Path -LiteralPath $zipPath) "Windows package not found: $zipPath"
Assert-Condition (Test-Path -LiteralPath $shaPath) "SHA-256 file not found: $shaPath"
$expectedPackageHash = ((Get-Content -Raw -Encoding ASCII -LiteralPath $shaPath) -split '\s+')[0].Trim().ToLowerInvariant()
$actualPackageHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
Assert-Condition ($actualPackageHash -eq $expectedPackageHash) 'Windows package does not match its SHA-256 file.'
Add-Step -Name 'windows_package_hash' -Status 'pass' -Detail "Current package matches $expectedPackageHash."

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = if (Test-Path -LiteralPath $localConfigPath) { $localConfigPath } else { $exampleConfigPath }
}
$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
Assert-Condition (Test-Path -LiteralPath $ConfigPath) "itch.io config not found: $ConfigPath"
$config = Read-JsonFile -Path $ConfigPath
$target = Read-OptionalString -Value $config -Name 'itch_target'
$targetConfigured = $target -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -and $target -ne '<itch-user>/<itch-game>'
$hidden = if ($config.PSObject.Properties.Name -contains 'hidden') { [bool]$config.hidden } else { $true }

$configOk = Invoke-CycleStep -Name 'itch_upload_config' -SuccessDetail 'itch.io configuration schema is valid.' -Action {
    & (Join-Path $PSScriptRoot 'verify_itch_upload_config.ps1') -Version $Version -ConfigPath $ConfigPath -AllowPlaceholder
}

if ($targetConfigured) {
    Add-Step -Name 'real_itch_target' -Status 'pass' -Detail "Real target is configured for $target."
}
else {
    Add-Step -Name 'real_itch_target' -Status 'pending' -Detail 'Create release/itch-upload-config.local.json with a real itch_target.'
}

if (-not $hidden) {
    Add-Step -Name 'hidden_channel_guard' -Status 'fail' -Detail 'advance_external_release.ps1 only permits hidden channel uploads; set hidden=true.'
}
else {
    Add-Step -Name 'hidden_channel_guard' -Status 'pass' -Detail 'Channel upload is configured as hidden.'
}

$preflightOk = Invoke-CycleStep -Name 'publish_environment_preflight' -SuccessDetail 'Publish environment preflight completed.' -Action {
    & (Join-Path $PSScriptRoot 'verify_publish_environment.ps1') -Version $Version
}
$publishEnvironment = Read-JsonFile -Path $publishEnvironmentPath
$butlerAvailable = $null -ne $publishEnvironment -and -not [string]::IsNullOrWhiteSpace([string]$publishEnvironment.butler_path)

if ($Push) {
    if (-not $configOk -or -not $targetConfigured) {
        Add-Step -Name 'channel_push' -Status 'fail' -Detail 'Push was requested, but a valid real itch target is not configured.'
    }
    elseif (-not $hidden) {
        Add-Step -Name 'channel_push' -Status 'fail' -Detail 'Push was requested with hidden=false; public channel upload is refused.'
    }
    elseif (-not $preflightOk -or -not $butlerAvailable) {
        Add-Step -Name 'channel_push' -Status 'fail' -Detail 'Push was requested, but butler is not ready.'
    }
    else {
        $pushPerformed = Invoke-CycleStep -Name 'channel_push' -SuccessDetail 'butler returned exit code 0 and the hidden channel manifest records pushed=true.' -Action {
            & (Join-Path $PSScriptRoot 'prepare_itch_upload.ps1') -Version $Version -ConfigPath $ConfigPath -Push
            $manifest = Read-JsonFile -Path $itchManifestPath
            Assert-Condition ($null -ne $manifest -and [bool]$manifest.pushed -and [int]$manifest.butler_exit_code -eq 0) 'butler returned without a verified pushed=true manifest.'
            & (Join-Path $PSScriptRoot 'verify_itch_staging.ps1') -Version $Version
        }
    }
}
else {
    Add-Step -Name 'channel_push' -Status 'skipped' -Detail 'No external upload was requested. Use -Push after target configuration and butler login.'
}

$resolvedPackageUrl = if ($PSBoundParameters.ContainsKey('PackageUrl')) { $PackageUrl } else { Read-OptionalString -Value $config -Name 'public_package_url' }
$resolvedSha256Url = if ($PSBoundParameters.ContainsKey('Sha256Url')) { $Sha256Url } else { Read-OptionalString -Value $config -Name 'public_sha256_url' }
$hasPackageUrl = -not [string]::IsNullOrWhiteSpace($resolvedPackageUrl)
$hasShaUrl = -not [string]::IsNullOrWhiteSpace($resolvedSha256Url)
if ($hasPackageUrl -ne $hasShaUrl) {
    Add-Step -Name 'public_download_validation' -Status 'fail' -Detail 'PackageUrl and Sha256Url must be supplied together.'
}
elseif ($hasPackageUrl) {
    [void](Invoke-CycleStep -Name 'public_download_validation' -SuccessDetail 'Real public ZIP and SHA-256 URLs passed download, hash, extract, and launch verification.' -Action {
        & (Join-Path $PSScriptRoot 'verify_public_download.ps1') -PackageUrl $resolvedPackageUrl -Sha256Url $resolvedSha256Url -ExpectedPackageSha256 $expectedPackageHash
    })
}
else {
    Add-Step -Name 'public_download_validation' -Status 'pending' -Detail 'Real public ZIP and SHA-256 URLs are not configured yet.'
}

[void](Invoke-CycleStep -Name 'clean_machine_report_intake' -SuccessDetail 'Clean-machine incoming reports were processed.' -Action {
    & (Join-Path $PSScriptRoot 'receive_clean_machine_reports.ps1') -Version $Version
})
[void](Invoke-CycleStep -Name 'playtest_report_intake' -SuccessDetail 'External playtest incoming reports and feedback summary were processed.' -Action {
    & (Join-Path $PSScriptRoot 'receive_playtest_reports.ps1') -Version $Version
})
[void](Invoke-CycleStep -Name 'publish_environment_refresh' -SuccessDetail 'Publish environment report was refreshed after this cycle.' -Action {
    & (Join-Path $PSScriptRoot 'verify_publish_environment.ps1') -Version $Version
})
[void](Invoke-CycleStep -Name 'release_readiness' -SuccessDetail 'Release readiness report was refreshed.' -Action {
    & (Join-Path $PSScriptRoot 'verify_release_readiness.ps1') -Version $Version
})
[void](Invoke-CycleStep -Name 'public_release_gate' -SuccessDetail 'Final public release gate report was refreshed.' -Action {
    & (Join-Path $PSScriptRoot 'verify_public_release_go.ps1') -Version $Version -AllowNoGo
})

$releaseReadiness = Read-JsonFile -Path $releaseReadinessPath
$publicGate = Read-JsonFile -Path $publicGatePath
$gateDecision = if ($null -eq $publicGate) { 'missing' } else { [string]$publicGate.decision }
$gateFailures = if ($null -eq $publicGate) { @('missing_public_release_gate') } else { @($publicGate.checks | Where-Object { $_.status -eq 'fail' } | ForEach-Object { $_.name }) }
$decision = if ($cycleFailed) {
    'cycle_failed'
}
elseif ($gateDecision -eq 'go_public_release') {
    'go_public_release'
}
else {
    'waiting_for_external_evidence'
}

$report = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    decision = $decision
    package_sha256 = $expectedPackageHash
    config_path = $ConfigPath
    real_target_configured = $targetConfigured
    hidden_channel = $hidden
    push_requested = [bool]$Push
    push_performed = [bool]$pushPerformed
    public_urls_configured = ($hasPackageUrl -and $hasShaUrl)
    release_readiness_decision = if ($null -eq $releaseReadiness) { 'missing' } else { [string]$releaseReadiness.decision }
    public_release_gate_decision = $gateDecision
    public_release_gate_failures = $gateFailures
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    steps = $steps
}

$jsonPath = Join-Path $ReportDir "external-release-cycle-$Version.json"
$mdPath = Join-Path $ReportDir "external-release-cycle-$Version.md"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdLines = @(
    "# PC Building Life External Release Cycle $Version",
    '',
    "- Decision: ``$decision``",
    "- Package SHA-256: ``$expectedPackageHash``",
    "- Real itch target configured: $targetConfigured",
    "- Push requested / performed: $([bool]$Push) / $pushPerformed",
    "- Public URLs configured: $($hasPackageUrl -and $hasShaUrl)",
    "- Release readiness: $($report.release_readiness_decision)",
    "- Public release gate: $gateDecision",
    '',
    '## Steps',
    ''
)
foreach ($step in $steps) {
    $mdLines += "- $($step.status): $($step.name) - $($step.detail)"
}
$mdLines += @('', '## Remaining Public Gate Failures', '')
foreach ($failure in $gateFailures) {
    $mdLines += "- $failure"
}
if ($gateFailures.Count -eq 0) {
    $mdLines += '- none'
}
$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[external-release-cycle] ok'
Write-Host "[external-release-cycle] decision=$decision push_requested=$([bool]$Push) push_performed=$pushPerformed"
Write-Host "[external-release-cycle] gate=$gateDecision failures=$($gateFailures.Count)"
Write-Host "[external-release-cycle] json=$jsonPath"
Write-Host "[external-release-cycle] markdown=$mdPath"

if ($cycleFailed -or ($Push -and -not $pushPerformed) -or ($RequireGo -and $decision -ne 'go_public_release')) {
    exit 1
}
