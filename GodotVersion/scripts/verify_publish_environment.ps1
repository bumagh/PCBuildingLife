[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [switch]$RequireTarget,
    [switch]$RequireButler,
    [switch]$RequirePublicUrls,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildDir = Join-Path $projectDir 'build\windows'
$itchRoot = Join-Path $projectDir 'build\itch'
$itchDir = Join-Path $itchRoot "PCBuildingLife-$Version"
$publishRoot = Join-Path $projectDir 'build\publish'

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $publishRoot "publish-environment-audit-$Version.json"
}

$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$publicDownloadReportPath = Join-Path $buildDir 'public-download-audit-report.json'
$itchManifestPath = Join-Path $itchDir 'itch-upload-manifest.json'
$itchAuditPath = Join-Path $itchRoot "itch-staging-audit-$Version.json"
$itchConfigAuditPath = Join-Path $itchRoot "itch-upload-config-audit-$Version.json"
$butlerCommandPath = Join-Path $itchDir 'butler-command.txt'

$checks = @()

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet('pass', 'warn', 'fail')]
        [string]$Status,
        [string]$Detail
    )

    $script:checks += [ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Read-Sha256File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return ((Get-Content -Raw -Encoding ASCII -LiteralPath $Path) -split '\s+')[0].Trim().ToLowerInvariant()
}

function Test-HashMatch {
    param(
        [string]$Path,
        [string]$ExpectedHash
    )
    if (-not (Test-Path -LiteralPath $Path) -or [string]::IsNullOrWhiteSpace($ExpectedHash)) {
        return $false
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    return $actual -eq $ExpectedHash.ToLowerInvariant()
}

function Get-ButlerPath {
    $command = Get-Command butler -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:APPDATA 'itch\apps\butler\butler.exe'),
        (Join-Path $env:LOCALAPPDATA 'itch\apps\butler\butler.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-ButlerVersion {
    param([string]$ButlerPath)

    foreach ($arg in @('-V', '--version')) {
        $process = $null
        try {
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $ButlerPath
            $startInfo.Arguments = $arg
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $startInfo
            [void]$process.Start()
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            if ($process.ExitCode -eq 0) {
                $version = ($stdout + "`n" + $stderr).Trim()
                if (-not [string]::IsNullOrWhiteSpace($version)) {
                    return $version
                }
            }
        }
        catch {
        }
        finally {
            if ($null -ne $process) {
                $process.Dispose()
            }
        }
    }

    return $null
}

$expectedPackageHash = Read-Sha256File -Path $shaPath
if ($expectedPackageHash -and (Test-HashMatch -Path $zipPath -ExpectedHash $expectedPackageHash)) {
    Add-Check 'windows_package_hash' 'pass' "Current ZIP matches SHA-256 $expectedPackageHash."
}
else {
    Add-Check 'windows_package_hash' 'fail' 'Current Windows ZIP is missing or does not match its .sha256 file.'
}

$configVerificationOk = $false
try {
    $verifyArgs = @{
        Version = $Version
        ReportPath = $itchConfigAuditPath
    }
    if ($RequireTarget) {
        $verifyArgs.RequireTarget = $true
    }
    else {
        $verifyArgs.AllowPlaceholder = $true
    }
    & (Join-Path $PSScriptRoot 'verify_itch_upload_config.ps1') @verifyArgs
    $configVerificationOk = $true
}
catch {
    Add-Check 'itch_upload_config' 'fail' "itch.io upload config verification failed: $($_.Exception.Message)"
}

$itchConfigAudit = Read-JsonFile -Path $itchConfigAuditPath
$targetConfigured = $false
$publicUrlsConfigured = $false
if ($configVerificationOk -and $itchConfigAudit -ne $null -and [bool]$itchConfigAudit.ok) {
    $targetConfigured = -not [bool]$itchConfigAudit.itch_target_is_placeholder
    $publicUrlsConfigured = [bool]$itchConfigAudit.public_urls_configured

    if ($targetConfigured) {
        Add-Check 'itch_upload_config' 'pass' "Real itch.io target configured: $($itchConfigAudit.itch_target):$($itchConfigAudit.channel)."
    }
    elseif ($RequireTarget) {
        Add-Check 'itch_upload_config' 'fail' 'Real itch.io target is required but the config still uses the placeholder.'
    }
    else {
        Add-Check 'itch_upload_config' 'warn' 'Config is valid, but itch_target is still the placeholder.'
    }

    if ($publicUrlsConfigured) {
        Add-Check 'public_url_config' 'pass' 'Public ZIP and SHA-256 URLs are configured as a pair.'
    }
    elseif ($RequirePublicUrls) {
        Add-Check 'public_url_config' 'fail' 'Public ZIP and SHA-256 URLs are required but not configured.'
    }
    else {
        Add-Check 'public_url_config' 'warn' 'Public ZIP and SHA-256 URLs are not configured yet.'
    }
}
elseif ($configVerificationOk) {
    Add-Check 'itch_upload_config' 'fail' 'itch.io upload config audit is missing or not ok after verification.'
}

$butlerPath = Get-ButlerPath
$butlerRunnable = $false
$butlerVersion = $null
if ([string]::IsNullOrWhiteSpace($butlerPath)) {
    if ($RequireButler) {
        Add-Check 'butler_tool' 'fail' 'butler is required but was not found in PATH or the itch app install directories.'
    }
    else {
        Add-Check 'butler_tool' 'warn' 'butler was not found; install itch.io butler or add it to PATH before pushing.'
    }
}
else {
    $butlerVersion = Get-ButlerVersion -ButlerPath $butlerPath
    if ([string]::IsNullOrWhiteSpace($butlerVersion)) {
        if ($RequireButler) {
            Add-Check 'butler_tool' 'fail' "butler was found at $butlerPath, but version probing failed."
        }
        else {
            Add-Check 'butler_tool' 'warn' "butler was found at $butlerPath, but version probing failed."
        }
    }
    else {
        $butlerRunnable = $true
        Add-Check 'butler_tool' 'pass' "butler is runnable: $butlerVersion"
    }
}

$itchManifest = Read-JsonFile -Path $itchManifestPath
$itchAudit = Read-JsonFile -Path $itchAuditPath
$stageReady = $false
$pushed = $false
if ($itchManifest -eq $null) {
    Add-Check 'itch_staging' 'warn' "Missing itch.io staging manifest: $itchManifestPath"
}
elseif ([string]$itchManifest.package_sha256 -ne $expectedPackageHash) {
    Add-Check 'itch_staging' 'fail' "itch.io staging is stale. staging_hash=$($itchManifest.package_sha256), current_hash=$expectedPackageHash."
}
elseif ($itchAudit -eq $null -or -not [bool]$itchAudit.ok -or [string]$itchAudit.package_sha256 -ne $expectedPackageHash) {
    Add-Check 'itch_staging' 'fail' 'itch.io staging audit is missing, failed, or stale.'
}
else {
    $stageReady = $true
    $pushed = [bool]$itchManifest.pushed
    if ($pushed) {
        Add-Check 'itch_staging' 'pass' 'itch.io staging is current and manifest says the package was pushed.'
    }
    else {
        Add-Check 'itch_staging' 'warn' 'itch.io staging is current, but this package has not been pushed yet.'
    }
}

if (Test-Path -LiteralPath $butlerCommandPath) {
    $commandText = Get-Content -Raw -Encoding UTF8 -LiteralPath $butlerCommandPath
    if ($commandText.Contains($expectedPackageHash) -and $commandText.Contains('--userversion') -and $commandText.Contains($Version)) {
        Add-Check 'butler_command' 'pass' 'butler command file references the current version and package SHA-256.'
    }
    else {
        Add-Check 'butler_command' 'fail' 'butler command file is missing the current version or package SHA-256.'
    }
}
else {
    Add-Check 'butler_command' 'warn' "Missing butler command file: $butlerCommandPath"
}

$publicReport = Read-JsonFile -Path $publicDownloadReportPath
$publicUrlValidated = $false
if ($publicReport -eq $null) {
    Add-Check 'public_download_validation' 'warn' "Missing public download audit report: $publicDownloadReportPath"
}
elseif (-not [bool]$publicReport.ok -or [string]$publicReport.package_sha256 -ne $expectedPackageHash) {
    Add-Check 'public_download_validation' 'fail' 'Public download audit report failed or is stale.'
}
elseif ([string]$publicReport.source -eq 'url') {
    $publicUrlValidated = $true
    Add-Check 'public_download_validation' 'pass' "Real public URL download validation passed: $($publicReport.package_url)"
}
else {
    Add-Check 'public_download_validation' 'warn' 'Only local simulated public-download validation has passed.'
}

$failCount = @($checks | Where-Object { $_.status -eq 'fail' }).Count
$warnCount = @($checks | Where-Object { $_.status -eq 'warn' }).Count
$decision = 'waiting_for_channel_setup'
if ($failCount -gt 0) {
    $decision = 'no_go_fix_required'
}
elseif ($publicUrlValidated) {
    $decision = 'public_download_validated'
}
elseif ($targetConfigured -and $butlerRunnable -and $stageReady -and -not $pushed) {
    $decision = 'ready_for_hidden_upload'
}
elseif ($targetConfigured -and $butlerRunnable -and $stageReady -and $pushed) {
    $decision = 'waiting_for_public_url_validation'
}

$report = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    decision = $decision
    fail_count = $failCount
    warn_count = $warnCount
    current_package_sha256 = $expectedPackageHash
    current_package = $zipPath
    itch_config_audit = $itchConfigAuditPath
    itch_staging_manifest = $itchManifestPath
    itch_staging_audit = $itchAuditPath
    butler_path = if ([string]::IsNullOrWhiteSpace($butlerPath)) { $null } else { $butlerPath }
    butler_version = $butlerVersion
    target_configured = $targetConfigured
    public_urls_configured = $publicUrlsConfigured
    public_url_validated = $publicUrlValidated
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    checks = $checks
}

$reportFullPath = [System.IO.Path]::GetFullPath($ReportPath)
$reportDir = Split-Path -Parent $reportFullPath
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportFullPath -Encoding UTF8

$mdPath = [System.IO.Path]::ChangeExtension($reportFullPath, '.md')
$mdLines = @(
    "# PC Building Life Publish Environment $Version",
    "",
    "- Decision: ``$decision``",
    "- Current ZIP SHA-256: ``$expectedPackageHash``",
    "- Fails: $failCount",
    "- Warnings: $warnCount",
    "- Checked at UTC: $($report.checked_at_utc)",
    "",
    "## Checks",
    ""
)
foreach ($check in $checks) {
    $mdLines += "- $($check.status): $($check.name) - $($check.detail)"
}
$mdLines += ""
$mdLines += "## Next Action"
if ($decision -eq 'no_go_fix_required') {
    $mdLines += 'Fix failed checks, then rerun `GodotVersion/scripts/verify_publish_environment.ps1`.'
}
elseif ($decision -eq 'ready_for_hidden_upload') {
    $mdLines += 'Run `GodotVersion/scripts/prepare_itch_upload.ps1 -Push` for the hidden itch.io upload, then validate the real public URLs.'
}
elseif ($decision -eq 'waiting_for_public_url_validation') {
    $mdLines += 'Run `GodotVersion/scripts/verify_public_download.ps1` with the real ZIP and SHA-256 URLs.'
}
elseif ($decision -eq 'public_download_validated') {
    $mdLines += 'Collect clean-machine and external first-order reports before widening distribution.'
}
else {
    $mdLines += 'Create `GodotVersion/release/itch-upload-config.local.json`, set a real `itch_target`, install/login butler, then rerun this preflight.'
}
$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[publish-env] ok'
Write-Host "[publish-env] decision=$decision fails=$failCount warnings=$warnCount"
Write-Host "[publish-env] json=$reportFullPath"
Write-Host "[publish-env] markdown=$mdPath"

if ($failCount -gt 0) {
    exit 1
}
