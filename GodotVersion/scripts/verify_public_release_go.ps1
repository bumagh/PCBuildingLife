[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$ReportDir,
    [switch]$AllowNoGo
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
if ([string]::IsNullOrWhiteSpace($ReportDir)) {
    $ReportDir = Join-Path $projectDir 'build\public-release-go'
}
$ReportDir = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$buildDir = Join-Path $projectDir 'build\windows'
$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$releaseReadinessPath = Join-Path $projectDir "build\release-readiness\release-readiness-$Version.json"
$publishEnvironmentPath = Join-Path $projectDir "build\publish\publish-environment-audit-$Version.json"
$itchConfigAuditPath = Join-Path $projectDir "build\itch\itch-upload-config-audit-$Version.json"
$itchManifestPath = Join-Path $projectDir "build\itch\PCBuildingLife-$Version\itch-upload-manifest.json"
$publicDownloadReportPath = Join-Path $buildDir 'public-download-audit-report.json'
$cleanMachineReportIntakePath = Join-Path $projectDir "build\clean-machine-validation\report-intake\clean-machine-report-intake-$Version.json"
$playtestReportIntakePath = Join-Path $projectDir "build\playtest\report-intake\playtest-report-intake-$Version.json"
$playtestSummaryPath = Join-Path $projectDir "build\playtest\feedback-summary\playtest-feedback-summary-$Version.json"
$externalValidationAuditPath = Join-Path $projectDir "build\external-validation\external-validation-round-audit-$Version.json"
$issueTemplatePath = Join-Path $repoRoot '.github\ISSUE_TEMPLATE\pcbuildinglife-bug-report.yml'

$checks = @()

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet('pass', 'fail')]
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

$expectedPackageHash = Read-Sha256File -Path $shaPath
if ($expectedPackageHash -and (Test-HashMatch -Path $zipPath -ExpectedHash $expectedPackageHash)) {
    Add-Check 'windows_package_hash' 'pass' "Current ZIP matches SHA-256 $expectedPackageHash."
}
else {
    Add-Check 'windows_package_hash' 'fail' 'Current Windows ZIP is missing or does not match its .sha256 file.'
}

$releaseReadiness = Read-JsonFile -Path $releaseReadinessPath
if ($releaseReadiness -ne $null -and [int]$releaseReadiness.fail_count -eq 0 -and [string]$releaseReadiness.current_package_sha256 -eq $expectedPackageHash) {
    Add-Check 'release_readiness_evidence' 'pass' "Release readiness evidence is current. decision=$($releaseReadiness.decision), warnings=$($releaseReadiness.warn_count)."
}
else {
    Add-Check 'release_readiness_evidence' 'fail' 'Release readiness evidence is missing, failed, or stale.'
}

$itchConfigAudit = Read-JsonFile -Path $itchConfigAuditPath
if ($itchConfigAudit -ne $null -and [bool]$itchConfigAudit.ok -and -not [bool]$itchConfigAudit.itch_target_is_placeholder -and -not [string]::IsNullOrWhiteSpace([string]$itchConfigAudit.itch_target)) {
    Add-Check 'real_itch_target' 'pass' "Real itch.io target configured: $($itchConfigAudit.itch_target):$($itchConfigAudit.channel)."
}
else {
    Add-Check 'real_itch_target' 'fail' 'Real itch.io target is not configured. Create release/itch-upload-config.local.json and rerun verify_itch_upload_config.ps1 -RequireTarget.'
}

$itchManifest = Read-JsonFile -Path $itchManifestPath
if ($itchManifest -ne $null -and [string]$itchManifest.package_sha256 -eq $expectedPackageHash -and [bool]$itchManifest.pushed) {
    Add-Check 'channel_upload_pushed' 'pass' "Channel upload manifest says current package was pushed to $($itchManifest.itch_target):$($itchManifest.channel)."
}
else {
    Add-Check 'channel_upload_pushed' 'fail' 'Current package has not been pushed to the channel through prepare_itch_upload.ps1 -Push.'
}

$publishEnvironment = Read-JsonFile -Path $publishEnvironmentPath
if ($publishEnvironment -ne $null -and [int]$publishEnvironment.fail_count -eq 0 -and [string]$publishEnvironment.current_package_sha256 -eq $expectedPackageHash -and [string]$publishEnvironment.decision -eq 'public_download_validated') {
    Add-Check 'publish_environment' 'pass' 'Publish environment preflight reached public_download_validated.'
}
else {
    $decision = if ($publishEnvironment -eq $null) { 'missing' } else { [string]$publishEnvironment.decision }
    Add-Check 'publish_environment' 'fail' "Publish environment is not final-public-ready. decision=$decision."
}

$publicDownloadReport = Read-JsonFile -Path $publicDownloadReportPath
if ($publicDownloadReport -ne $null -and [bool]$publicDownloadReport.ok -and [string]$publicDownloadReport.source -eq 'url' -and [string]$publicDownloadReport.package_sha256 -eq $expectedPackageHash) {
    Add-Check 'real_public_download' 'pass' "Real public URL download validation passed: $($publicDownloadReport.package_url)"
}
else {
    Add-Check 'real_public_download' 'fail' 'Real public URL download validation has not passed for the current package.'
}

$cleanMachineReportIntake = Read-JsonFile -Path $cleanMachineReportIntakePath
if ($cleanMachineReportIntake -ne $null -and [bool]$cleanMachineReportIntake.ok -and [string]$cleanMachineReportIntake.expected_package_sha256 -eq $expectedPackageHash -and [string]$cleanMachineReportIntake.decision -eq 'go' -and [int]$cleanMachineReportIntake.current_package_reports -ge 1) {
    Add-Check 'clean_machine_reports' 'pass' "Clean-machine report gate passed. current_package_reports=$($cleanMachineReportIntake.current_package_reports)."
}
else {
    $decision = if ($cleanMachineReportIntake -eq $null) { 'missing' } else { [string]$cleanMachineReportIntake.decision }
    $count = if ($cleanMachineReportIntake -eq $null) { 0 } else { [int]$cleanMachineReportIntake.current_package_reports }
    Add-Check 'clean_machine_reports' 'fail' "Need at least 1 valid clean-machine first-order report for the current package. decision=$decision, current_package_reports=$count."
}

$playtestReportIntake = Read-JsonFile -Path $playtestReportIntakePath
$playtestSummary = Read-JsonFile -Path $playtestSummaryPath
if ($playtestReportIntake -ne $null -and [bool]$playtestReportIntake.ok -and [string]$playtestReportIntake.expected_package_sha256 -eq $expectedPackageHash -and $playtestSummary -ne $null -and [string]$playtestSummary.expected_package_sha256 -eq $expectedPackageHash -and [string]$playtestSummary.decision -eq 'go' -and [int]$playtestSummary.counts.current_package_reports -ge 3) {
    Add-Check 'external_playtest_reports' 'pass' "External playtest gate passed. current_package_reports=$($playtestSummary.counts.current_package_reports)."
}
else {
    $decision = if ($playtestSummary -eq $null) { 'missing' } else { [string]$playtestSummary.decision }
    $count = if ($playtestSummary -eq $null) { 0 } else { [int]$playtestSummary.counts.current_package_reports }
    Add-Check 'external_playtest_reports' 'fail' "Need at least 3 valid external first-order reports for the current package. decision=$decision, current_package_reports=$count."
}

$externalValidationAudit = Read-JsonFile -Path $externalValidationAuditPath
if ($externalValidationAudit -ne $null -and [bool]$externalValidationAudit.ok -and [string]$externalValidationAudit.package_sha256 -eq $expectedPackageHash) {
    Add-Check 'external_validation_round' 'pass' "External validation round audit is current. round_zip_sha256=$($externalValidationAudit.round_zip_sha256)."
}
else {
    Add-Check 'external_validation_round' 'fail' 'External validation round audit is missing, failed, or stale.'
}

if (Test-Path -LiteralPath $issueTemplatePath) {
    Add-Check 'feedback_entry' 'pass' 'GitHub Issue feedback template exists.'
}
else {
    Add-Check 'feedback_entry' 'fail' "Missing feedback issue template: $issueTemplatePath"
}

$failCount = @($checks | Where-Object { $_.status -eq 'fail' }).Count
$decision = if ($failCount -eq 0) { 'go_public_release' } else { 'no_go_external_gates_required' }
$report = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    decision = $decision
    fail_count = $failCount
    current_package_sha256 = $expectedPackageHash
    current_package = $zipPath
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    checks = $checks
}

$jsonPath = Join-Path $ReportDir "public-release-go-$Version.json"
$mdPath = Join-Path $ReportDir "public-release-go-$Version.md"
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdLines = @(
    "# PC Building Life Public Release Gate $Version",
    "",
    "- Decision: ``$decision``",
    "- Current ZIP SHA-256: ``$expectedPackageHash``",
    "- Fails: $failCount",
    "- Checked at UTC: $($report.checked_at_utc)",
    "",
    "## Checks",
    ""
)
foreach ($check in $checks) {
    $mdLines += "- $($check.status): $($check.name) - $($check.detail)"
}
$mdLines += ""
$mdLines += "## Next Gate"
if ($decision -eq 'go_public_release') {
    $mdLines += 'All public release gates passed. The current package can be widened to the public page.'
}
else {
    $mdLines += 'Complete the failed external gates, then rerun `GodotVersion/scripts/verify_public_release_go.ps1`.'
}
$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[public-release-go] ok'
Write-Host "[public-release-go] decision=$decision fails=$failCount"
Write-Host "[public-release-go] json=$jsonPath"
Write-Host "[public-release-go] markdown=$mdPath"

if ($failCount -gt 0 -and -not $AllowNoGo) {
    exit 1
}
