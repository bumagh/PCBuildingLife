[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$ReportDir
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
if ([string]::IsNullOrWhiteSpace($ReportDir)) {
    $ReportDir = Join-Path $projectDir 'build\release-readiness'
}
$ReportDir = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$buildDir = Join-Path $projectDir 'build\windows'
$uploadDir = Join-Path $projectDir "build\upload\PCBuildingLife-$Version"
$itchDir = Join-Path $projectDir "build\itch\PCBuildingLife-$Version"
$playtestDir = Join-Path $projectDir "build\playtest\PCBuildingLife-$Version"
$playtestRoot = Join-Path $projectDir 'build\playtest'
$externalValidationDir = Join-Path $projectDir "build\external-validation\PCBuildingLife-$Version"
$externalValidationZipPath = Join-Path $projectDir "build\external-validation\PCBuildingLife-$Version-external-validation-round.zip"
$externalValidationZipShaPath = "$externalValidationZipPath.sha256"
$externalValidationAuditPath = Join-Path $projectDir "build\external-validation\external-validation-round-audit-$Version.json"
$cleanMachineValidationDir = Join-Path $projectDir "build\clean-machine-validation\PCBuildingLife-$Version"
$cleanMachineValidationZipPath = Join-Path $projectDir "build\clean-machine-validation\PCBuildingLife-$Version-clean-machine-validation-kit.zip"
$cleanMachineValidationZipShaPath = "$cleanMachineValidationZipPath.sha256"
$cleanMachineValidationAuditPath = Join-Path $projectDir "build\clean-machine-validation\clean-machine-validation-kit-audit-$Version.json"
$cleanMachineReportIntakePath = Join-Path $projectDir "build\clean-machine-validation\report-intake\clean-machine-report-intake-$Version.json"

$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$releaseManifestPath = Join-Path $buildDir 'release-manifest.json'
$packageAuditPath = Join-Path $buildDir 'release-package-audit-report.json'
$publicDownloadReportPath = Join-Path $buildDir 'public-download-audit-report.json'
$uploadManifestPath = Join-Path $uploadDir 'upload-manifest.json'
$landingPagePath = Join-Path $uploadDir 'index.html'
$itchManifestPath = Join-Path $itchDir 'itch-upload-manifest.json'
$itchAuditPath = Join-Path $projectDir "build\itch\itch-staging-audit-$Version.json"
$itchConfigAuditPath = Join-Path $projectDir "build\itch\itch-upload-config-audit-$Version.json"
$playtestManifestPath = Join-Path $playtestDir 'playtest-kit-manifest.json'
$playtestZipPath = Join-Path $playtestRoot "PCBuildingLife-$Version-playtest-kit.zip"
$playtestShaPath = "$playtestZipPath.sha256"
$playtestLauncherPath = Join-Path $playtestDir 'START_PLAYTEST_KIT.ps1'
$playtestSupportPath = Join-Path $playtestDir 'COLLECT_SUPPORT_BUNDLE.ps1'
$playtestReportIntakePath = Join-Path $playtestRoot "report-intake\playtest-report-intake-$Version.json"
$playtestSummaryPath = Join-Path $playtestRoot "feedback-summary\playtest-feedback-summary-$Version.json"
$externalValidationManifestPath = Join-Path $externalValidationDir 'external-validation-manifest.json'
$cleanMachineValidationManifestPath = Join-Path $cleanMachineValidationDir 'clean-machine-validation-manifest.json'
$issueTemplatePath = Join-Path $repoRoot '.github\ISSUE_TEMPLATE\pcbuildinglife-bug-report.yml'

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

$expectedPackageHash = Read-Sha256File -Path $shaPath
if ((Test-Path -LiteralPath $zipPath) -and $expectedPackageHash -and (Test-HashMatch -Path $zipPath -ExpectedHash $expectedPackageHash)) {
    Add-Check 'windows_package_hash' 'pass' "ZIP exists and matches SHA-256 $expectedPackageHash."
}
else {
    Add-Check 'windows_package_hash' 'fail' 'Windows ZIP is missing or does not match its .sha256 file.'
}

$releaseManifest = Read-JsonFile -Path $releaseManifestPath
if ($releaseManifest -ne $null) {
    $requiredGates = @('tests', 'launch_smoke', 'clean_extract_smoke', 'public_release_guard', 'public_first_order_guard', 'player_flow', 'first_order_audit')
    $badGates = @()
    foreach ($gate in $requiredGates) {
        if ([string]$releaseManifest.$gate -ne 'passed') {
            $badGates += $gate
        }
    }
    if ($badGates.Count -eq 0 -and [int]$releaseManifest.player_flow_orders -eq 12 -and [int]$releaseManifest.first_order_audit_score -ge 90) {
        Add-Check 'release_manifest_gates' 'pass' 'Release manifest gates passed, 12-order player flow passed, first-order audit is S-grade capable.'
    }
    else {
        Add-Check 'release_manifest_gates' 'fail' "Release manifest is not ready. Bad gates: $($badGates -join ', '), player_flow_orders=$($releaseManifest.player_flow_orders), first_order_score=$($releaseManifest.first_order_audit_score)."
    }
}
else {
    Add-Check 'release_manifest_gates' 'fail' "Missing release manifest: $releaseManifestPath"
}

$packageAudit = Read-JsonFile -Path $packageAuditPath
if ($packageAudit -ne $null -and [bool]$packageAudit.ok -and [string]$packageAudit.package_sha256 -eq $expectedPackageHash) {
    Add-Check 'package_audit' 'pass' 'Package audit passed for the current ZIP, including clean extract launch smoke.'
}
else {
    Add-Check 'package_audit' 'fail' 'Package audit is missing, failed, or does not match the current ZIP hash.'
}

$uploadManifest = Read-JsonFile -Path $uploadManifestPath
$landingHtml = ''
if (Test-Path -LiteralPath $landingPagePath) {
    $landingHtml = Get-Content -Raw -Encoding UTF8 -LiteralPath $landingPagePath
}
if ($uploadManifest -ne $null -and [string]$uploadManifest.package_sha256 -eq $expectedPackageHash -and (Test-Path -LiteralPath $landingPagePath) -and $landingHtml.Contains($expectedPackageHash) -and $landingHtml.Contains([string]$uploadManifest.exe_sha256)) {
    Add-Check 'upload_bundle' 'pass' "Upload bundle and landing page are present for current ZIP hash $expectedPackageHash."
}
elseif ($uploadManifest -ne $null) {
    Add-Check 'upload_bundle' 'fail' "Upload bundle is stale or incomplete. bundle_hash=$($uploadManifest.package_sha256), current_hash=$expectedPackageHash, landing_page_exists=$(Test-Path -LiteralPath $landingPagePath), html_has_current_hash=$($landingHtml.Contains($expectedPackageHash))."
}
else {
    Add-Check 'upload_bundle' 'fail' "Missing upload bundle manifest: $uploadManifestPath"
}

$itchManifest = Read-JsonFile -Path $itchManifestPath
$itchAudit = Read-JsonFile -Path $itchAuditPath
$itchConfigAudit = Read-JsonFile -Path $itchConfigAuditPath
if ($itchConfigAudit -eq $null) {
    Add-Check 'itch_upload_config' 'warn' "Missing itch.io upload config audit: $itchConfigAuditPath"
}
elseif (-not [bool]$itchConfigAudit.ok) {
    Add-Check 'itch_upload_config' 'fail' 'itch.io upload config audit failed.'
}
elseif ([bool]$itchConfigAudit.itch_target_is_placeholder) {
    Add-Check 'itch_upload_config' 'warn' 'itch.io upload config is valid but still uses the placeholder target; set release/itch-upload-config.local.json before pushing.'
}
else {
    Add-Check 'itch_upload_config' 'pass' "itch.io upload config is ready for $($itchConfigAudit.itch_target):$($itchConfigAudit.channel)."
}

if ($itchManifest -ne $null -and [string]$itchManifest.package_sha256 -eq $expectedPackageHash) {
    if ($itchAudit -eq $null -or -not [bool]$itchAudit.ok -or [string]$itchAudit.package_sha256 -ne $expectedPackageHash -or [string]$itchAudit.channel -ne [string]$itchManifest.channel) {
        Add-Check 'itch_staging' 'fail' 'itch.io staging deep audit is missing, failed, or stale.'
    }
    elseif ([bool]$itchManifest.pushed) {
        Add-Check 'itch_staging' 'pass' 'itch.io staging deep audit passed for the current ZIP and manifest says it was pushed.'
    }
    else {
        Add-Check 'itch_staging' 'warn' 'itch.io staging deep audit passed for the current ZIP, but it has not been uploaded through butler yet.'
    }
}
elseif ($itchManifest -ne $null) {
    Add-Check 'itch_staging' 'fail' "itch.io staging is stale. itch_hash=$($itchManifest.package_sha256), current_hash=$expectedPackageHash."
}
else {
    Add-Check 'itch_staging' 'warn' "Missing itch.io staging manifest: $itchManifestPath"
}

$publicReport = Read-JsonFile -Path $publicDownloadReportPath
if ($publicReport -ne $null -and [bool]$publicReport.ok -and [string]$publicReport.package_sha256 -eq $expectedPackageHash) {
    if ([string]$publicReport.source -eq 'url') {
        Add-Check 'public_download_validation' 'pass' "Public URL download validation passed: $($publicReport.package_url)"
    }
    else {
        Add-Check 'public_download_validation' 'warn' 'Only local simulated public-download validation has passed; real URL or clean external machine validation is still required.'
    }
}
elseif ($publicReport -ne $null) {
    Add-Check 'public_download_validation' 'fail' "Public download report is stale or failed. report_hash=$($publicReport.package_sha256), current_hash=$expectedPackageHash."
}
else {
    Add-Check 'public_download_validation' 'warn' "Missing public download validation report: $publicDownloadReportPath"
}

$playtestManifest = Read-JsonFile -Path $playtestManifestPath
$playtestExpectedHash = Read-Sha256File -Path $playtestShaPath
$launcherText = ''
if (Test-Path -LiteralPath $playtestLauncherPath) {
    $launcherText = Get-Content -Raw -Encoding UTF8 -LiteralPath $playtestLauncherPath
}
$supportText = ''
if (Test-Path -LiteralPath $playtestSupportPath) {
    $supportText = Get-Content -Raw -Encoding UTF8 -LiteralPath $playtestSupportPath
}
if ($playtestManifest -ne $null -and [string]$playtestManifest.package_sha256 -eq $expectedPackageHash -and $playtestExpectedHash -and (Test-HashMatch -Path $playtestZipPath -ExpectedHash $playtestExpectedHash) -and $launcherText.Contains('Start-Process -FilePath $exePath -WorkingDirectory $tempRoot -PassThru') -and -not $launcherText.Contains('-WindowStyle Hidden') -and $supportText.Contains('save_summary.json') -and $supportText.Contains('The raw save file is not included') -and -not $supportText.Contains('Copy-Item -LiteralPath $savePath')) {
    Add-Check 'playtest_kit' 'pass' "Playtest kit matches current ZIP, launcher opens a visible game window, and support-bundle collector is present. kit_sha256=$playtestExpectedHash."
}
else {
    Add-Check 'playtest_kit' 'fail' 'Playtest kit is missing, stale, hash-invalid, may hide the game window, or lacks the privacy-safe support-bundle collector.'
}

$playtestSummary = Read-JsonFile -Path $playtestSummaryPath
$playtestReportIntake = Read-JsonFile -Path $playtestReportIntakePath
if ($playtestReportIntake -eq $null) {
    Add-Check 'external_report_intake' 'warn' "Missing external report intake audit: $playtestReportIntakePath"
}
elseif (-not [bool]$playtestReportIntake.ok -or [string]$playtestReportIntake.expected_package_sha256 -ne $expectedPackageHash) {
    Add-Check 'external_report_intake' 'fail' 'External report intake audit is failed or stale.'
}
else {
    Add-Check 'external_report_intake' 'pass' "External report intake audit is current. accepted_reports=$($playtestReportIntake.accepted_reports), rejected_reports=$($playtestReportIntake.rejected_reports), current_package_reports=$($playtestReportIntake.summary_current_package_reports)."
}

if ($playtestSummary -eq $null) {
    Add-Check 'external_playtest_reports' 'warn' "Missing external playtest feedback summary: $playtestSummaryPath"
}
elseif ([string]$playtestSummary.expected_package_sha256 -ne $expectedPackageHash) {
    Add-Check 'external_playtest_reports' 'fail' "External playtest summary is stale. summary_hash=$($playtestSummary.expected_package_sha256), current_hash=$expectedPackageHash."
}
elseif ([string]$playtestSummary.decision -eq 'go') {
    Add-Check 'external_playtest_reports' 'pass' "External reports passed go criteria: current_package_reports=$($playtestSummary.counts.current_package_reports), passed=$($playtestSummary.counts.passed), recommend=$($playtestSummary.counts.recommend)."
}
elseif ([string]$playtestSummary.decision -eq 'no_go' -or [string]$playtestSummary.decision -eq 'fix_then_retest') {
    Add-Check 'external_playtest_reports' 'fail' "External reports are not release-ready: decision=$($playtestSummary.decision), reason=$($playtestSummary.decision_reason)"
}
else {
    Add-Check 'external_playtest_reports' 'warn' "External report evidence is not enough yet: decision=$($playtestSummary.decision), current_package_reports=$($playtestSummary.counts.current_package_reports)."
}

$externalValidationManifest = Read-JsonFile -Path $externalValidationManifestPath
$externalValidationExpectedHash = Read-Sha256File -Path $externalValidationZipShaPath
$externalValidationAudit = Read-JsonFile -Path $externalValidationAuditPath
if ($externalValidationManifest -eq $null) {
    Add-Check 'external_validation_round' 'warn' "Missing external validation round package: $externalValidationManifestPath"
}
elseif ([string]$externalValidationManifest.package_sha256 -ne $expectedPackageHash) {
    Add-Check 'external_validation_round' 'fail' "External validation round is stale. round_hash=$($externalValidationManifest.package_sha256), current_hash=$expectedPackageHash."
}
elseif ([string]$externalValidationManifest.playtest_kit_sha256 -ne $playtestExpectedHash) {
    Add-Check 'external_validation_round' 'fail' "External validation round points at a stale playtest kit. round_kit=$($externalValidationManifest.playtest_kit_sha256), current_kit=$playtestExpectedHash."
}
elseif ([int]$externalValidationManifest.tester_count -lt 3) {
    Add-Check 'external_validation_round' 'fail' "External validation round tester_count must be at least 3, got $($externalValidationManifest.tester_count)."
}
elseif (-not (Test-Path -LiteralPath (Join-Path $externalValidationDir 'TESTER_MESSAGE.md')) -or -not (Test-Path -LiteralPath (Join-Path $externalValidationDir 'EXTERNAL_VALIDATION_TRACKER.csv'))) {
    Add-Check 'external_validation_round' 'fail' 'External validation round is missing tester message or tracker.'
}
elseif (-not $externalValidationExpectedHash -or -not (Test-HashMatch -Path $externalValidationZipPath -ExpectedHash $externalValidationExpectedHash)) {
    Add-Check 'external_validation_round' 'fail' 'External validation round ZIP is missing or does not match its .sha256 file.'
}
elseif ($externalValidationAudit -eq $null -or -not [bool]$externalValidationAudit.ok -or [string]$externalValidationAudit.round_zip_sha256 -ne $externalValidationExpectedHash -or [string]$externalValidationAudit.package_sha256 -ne $expectedPackageHash -or [string]$externalValidationAudit.playtest_kit_sha256 -ne $playtestExpectedHash) {
    Add-Check 'external_validation_round' 'fail' 'External validation round deep audit is missing, failed, or stale.'
}
else {
    Add-Check 'external_validation_round' 'pass' "External validation round ZIP is ready for $($externalValidationManifest.tester_count) testers and matches the current package. round_zip_sha256=$externalValidationExpectedHash."
}

$cleanMachineValidationManifest = Read-JsonFile -Path $cleanMachineValidationManifestPath
$cleanMachineValidationExpectedHash = Read-Sha256File -Path $cleanMachineValidationZipShaPath
$cleanMachineValidationAudit = Read-JsonFile -Path $cleanMachineValidationAuditPath
if ($cleanMachineValidationManifest -eq $null) {
    Add-Check 'clean_machine_validation_kit' 'warn' "Missing clean-machine validation kit: $cleanMachineValidationManifestPath"
}
elseif ([string]$cleanMachineValidationManifest.package_sha256 -ne $expectedPackageHash) {
    Add-Check 'clean_machine_validation_kit' 'fail' "Clean-machine validation kit is stale. kit_hash=$($cleanMachineValidationManifest.package_sha256), current_hash=$expectedPackageHash."
}
elseif (-not $cleanMachineValidationExpectedHash -or -not (Test-HashMatch -Path $cleanMachineValidationZipPath -ExpectedHash $cleanMachineValidationExpectedHash)) {
    Add-Check 'clean_machine_validation_kit' 'fail' 'Clean-machine validation kit ZIP is missing or does not match its .sha256 file.'
}
elseif ($cleanMachineValidationAudit -eq $null -or -not [bool]$cleanMachineValidationAudit.ok -or [string]$cleanMachineValidationAudit.kit_sha256 -ne $cleanMachineValidationExpectedHash -or [string]$cleanMachineValidationAudit.package_sha256 -ne $expectedPackageHash) {
    Add-Check 'clean_machine_validation_kit' 'fail' 'Clean-machine validation kit deep audit is missing, failed, or stale.'
}
else {
    Add-Check 'clean_machine_validation_kit' 'pass' "Clean-machine validation kit is ready and matches the current package. kit_sha256=$cleanMachineValidationExpectedHash."
}

$cleanMachineReportIntake = Read-JsonFile -Path $cleanMachineReportIntakePath
if ($cleanMachineReportIntake -eq $null) {
    Add-Check 'clean_machine_reports' 'warn' "Missing clean-machine report intake audit: $cleanMachineReportIntakePath"
}
elseif (-not [bool]$cleanMachineReportIntake.ok -or [string]$cleanMachineReportIntake.expected_package_sha256 -ne $expectedPackageHash) {
    Add-Check 'clean_machine_reports' 'fail' 'Clean-machine report intake audit is failed or stale.'
}
elseif ([string]$cleanMachineReportIntake.decision -eq 'go') {
    Add-Check 'clean_machine_reports' 'pass' "Clean-machine reports passed go criteria: current_package_reports=$($cleanMachineReportIntake.current_package_reports), passed=$($cleanMachineReportIntake.passed), recommend=$($cleanMachineReportIntake.recommend)."
}
elseif ([string]$cleanMachineReportIntake.decision -eq 'no_go' -or [string]$cleanMachineReportIntake.decision -eq 'fix_then_retest') {
    Add-Check 'clean_machine_reports' 'fail' "Clean-machine reports are not release-ready: decision=$($cleanMachineReportIntake.decision), reason=$($cleanMachineReportIntake.decision_reason)"
}
else {
    Add-Check 'clean_machine_reports' 'warn' "Clean-machine report evidence is not enough yet: decision=$($cleanMachineReportIntake.decision), current_package_reports=$($cleanMachineReportIntake.current_package_reports)."
}

if (Test-Path -LiteralPath $issueTemplatePath) {
    Add-Check 'feedback_entry' 'pass' 'GitHub Issue feedback template exists.'
}
else {
    Add-Check 'feedback_entry' 'fail' "Missing feedback issue template: $issueTemplatePath"
}

$failCount = @($checks | Where-Object { $_.status -eq 'fail' }).Count
$warnCount = @($checks | Where-Object { $_.status -eq 'warn' }).Count
$publicReady = $publicReport -ne $null -and [bool]$publicReport.ok -and [string]$publicReport.source -eq 'url' -and [string]$publicReport.package_sha256 -eq $expectedPackageHash

$decision = 'ready_for_external_validation'
if ($failCount -gt 0) {
    $decision = 'no_go_fix_required'
}
elseif ($publicReady) {
    $decision = 'ready_for_public_page'
}

$report = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    decision = $decision
    fail_count = $failCount
    warn_count = $warnCount
    current_package_sha256 = $expectedPackageHash
    current_package = $zipPath
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    checks = $checks
}

$jsonPath = Join-Path $ReportDir "release-readiness-$Version.json"
$mdPath = Join-Path $ReportDir "release-readiness-$Version.md"
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdLines = @(
    "# PC Building Life Release Readiness $Version",
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
$mdLines += "## Next Gate"
if ($decision -eq 'no_go_fix_required') {
    $mdLines += 'Fix failed checks, then rerun `GodotVersion/scripts/verify_release_readiness.ps1`.'
}
elseif ($decision -eq 'ready_for_external_validation') {
    $mdLines += "Upload to the chosen channel or test on a clean external Windows machine, then run public URL validation or collect external playtest reports."
}
else {
    $mdLines += "Public URL validation has passed. Recheck the final channel page and publish notes before widening distribution."
}
$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[release-readiness] ok'
Write-Host "[release-readiness] decision=$decision fails=$failCount warnings=$warnCount"
Write-Host "[release-readiness] json=$jsonPath"
Write-Host "[release-readiness] markdown=$mdPath"

if ($failCount -gt 0) {
    exit 1
}
