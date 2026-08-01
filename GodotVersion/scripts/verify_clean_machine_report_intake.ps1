[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$TempRoot,
    [string]$ExpectedPackageSha256
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validationRoot = Join-Path $projectDir 'build\clean-machine-validation'
$buildDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($TempRoot)) {
    $TempRoot = Join-Path $validationRoot 'report-intake-self-test'
}
if ([string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) {
    $shaPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip.sha256"
    if (Test-Path -LiteralPath $shaPath) {
        $ExpectedPackageSha256 = ((Get-Content -Raw -Encoding ASCII -LiteralPath $shaPath) -split '\s+')[0].Trim().ToLowerInvariant()
    }
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

function New-CleanReportText {
    param(
        [string]$Tester,
        [string]$PackageSha256,
        [string]$Result = 'passed',
        [string]$Readiness = 'recommend',
        [bool]$CompletePath = $true,
        [string]$GameVersion = $Version
    )

    $passed = if ($Result -eq 'passed') { 'x' } else { ' ' }
    $playable = if ($Result -eq 'playable') { 'x' } else { ' ' }
    $blocked = if ($Result -eq 'blocked') { 'x' } else { ' ' }
    $recommend = if ($Readiness -eq 'recommend') { 'x' } else { ' ' }
    $wait = if ($Readiness -eq 'wait') { 'x' } else { ' ' }
    $noPublish = if ($Readiness -eq 'no_publish') { 'x' } else { ' ' }
    $pathCheck = if ($CompletePath) { 'x' } else { ' ' }

    return @(
        "# PC Building Life $GameVersion Clean Machine Validation Report",
        "",
        "- Tester: $Tester",
        "- Test date: 2026-07-20",
        "- Machine type: clean Windows user profile",
        "- Game version: $GameVersion",
        "- Package SHA-256: $PackageSha256",
        "- Package source: bundled package",
        "- Public package URL:",
        "- Windows version: Windows 11 23H2",
        "- CPU / GPU: Test CPU / Test GPU",
        "- Memory: 32 GB",
        "- Resolution: 1920x1080",
        "- Fullscreen or windowed: windowed",
        "",
        "## Required Path",
        "",
        "- [$pathCheck] Package SHA-256 verified before launch.",
        "- [$pathCheck] Game launched from extracted ZIP.",
        "- [$pathCheck] Started a new game.",
        "- [$pathCheck] Finished first order.",
        "- [$pathCheck] Saved progress.",
        "- [$pathCheck] Closed and reopened the game.",
        "- [$pathCheck] Continue Game loaded the save.",
        "- [$pathCheck] No previous PC Building Life save was used.",
        "",
        "## Result",
        "",
        "- [$passed] Passed: first order, save, restart, and continue all worked.",
        "- [$playable] Playable with issues: path completed but problems were found.",
        "- [$blocked] Blocked: could not launch, finish first order, save, restart, or continue.",
        "",
        "## First Order",
        "",
        "- Order name: Office Starter Build",
        "- Final grade: S",
        "- Final score: 96",
        "- Any confusing step: none",
        "",
        "## Issues",
        "",
        "1. What happened?",
        "2. What did you expect?",
        "3. How can it be reproduced?",
        "4. Screenshot or video path:",
        "",
        "## Release Readiness Signal",
        "",
        "- [$recommend] I would recommend this build to another tester.",
        "- [$wait] I would wait for fixes before more testers play it.",
        "- [$noPublish] This build should not be published yet because it has a blocking issue."
    ) -join [Environment]::NewLine
}

Assert-Condition (-not [string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) 'ExpectedPackageSha256 is required or must be readable from the current Windows package .sha256 file.'
Assert-Condition ($ExpectedPackageSha256 -match '^[0-9a-f]{64}$') "ExpectedPackageSha256 is invalid: $ExpectedPackageSha256"

$validationRootFullPath = [System.IO.Path]::GetFullPath($validationRoot)
$tempFullPath = [System.IO.Path]::GetFullPath($TempRoot)
Assert-Condition ($tempFullPath.StartsWith($validationRootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside clean-machine-validation root: $tempFullPath"
if (Test-Path -LiteralPath $tempFullPath) {
    Remove-Item -LiteralPath $tempFullPath -Recurse -Force
}

$incomingDir = Join-Path $tempFullPath 'incoming'
$returnedDir = Join-Path $tempFullPath 'returned'
$sessionsDir = Join-Path $tempFullPath 'sessions'
$auditDir = Join-Path $tempFullPath 'audit'
New-Item -ItemType Directory -Force -Path $incomingDir, $returnedDir, $sessionsDir, $auditDir | Out-Null

New-CleanReportText -Tester 'clean-alpha' -PackageSha256 $ExpectedPackageSha256 |
    Set-Content -LiteralPath (Join-Path $incomingDir 'CLEAN_MACHINE_REPORT_valid.md') -Encoding UTF8
New-CleanReportText -Tester 'clean-alpha' -PackageSha256 $ExpectedPackageSha256 |
    Set-Content -LiteralPath (Join-Path $incomingDir 'CLEAN_MACHINE_REPORT_duplicate.md') -Encoding UTF8
New-CleanReportText -Tester 'clean-beta' -PackageSha256 ('0' * 64) |
    Set-Content -LiteralPath (Join-Path $incomingDir 'CLEAN_MACHINE_REPORT_stale.md') -Encoding UTF8
New-CleanReportText -Tester 'clean-gamma' -PackageSha256 $ExpectedPackageSha256 -CompletePath $false |
    Set-Content -LiteralPath (Join-Path $incomingDir 'CLEAN_MACHINE_REPORT_incomplete.md') -Encoding UTF8

[ordered]@{
    product = 'PC Building Life'
    version = $Version
    package_sha256 = $ExpectedPackageSha256
    package_source = 'bundled'
    os_caption = 'Windows 11'
    os_version = '10.0.22631'
    cpu = 'Test CPU'
    gpu = 'Test GPU'
    started_at_utc = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $incomingDir 'clean-machine-session-valid.json') -Encoding UTF8
'not-json' | Set-Content -LiteralPath (Join-Path $incomingDir 'clean-machine-session-invalid.json') -Encoding UTF8

& (Join-Path $PSScriptRoot 'receive_clean_machine_reports.ps1') `
    -Version $Version `
    -InputDir $incomingDir `
    -ReportsDir $returnedDir `
    -SessionsDir $sessionsDir `
    -AuditDir $auditDir `
    -ExpectedPackageSha256 $ExpectedPackageSha256 `
    -RequiredReports 1 `
    -AllowRejected

$auditPath = Join-Path $auditDir "clean-machine-report-intake-$Version.json"
Assert-Condition (Test-Path -LiteralPath $auditPath) "Missing self-test audit: $auditPath"
$audit = Get-Content -Raw -Encoding UTF8 -LiteralPath $auditPath | ConvertFrom-Json

Assert-Condition ([string]$audit.decision -eq 'go') "Expected decision go, got $($audit.decision)."
Assert-Condition ([int]$audit.accepted_reports -eq 1) "Expected 1 accepted report, got $($audit.accepted_reports)."
Assert-Condition ([int]$audit.skipped_duplicate_reports -eq 1) "Expected 1 duplicate report, got $($audit.skipped_duplicate_reports)."
Assert-Condition ([int]$audit.rejected_reports -eq 2) "Expected 2 rejected reports, got $($audit.rejected_reports)."
Assert-Condition ([int]$audit.accepted_sessions -eq 1) "Expected 1 accepted session, got $($audit.accepted_sessions)."
Assert-Condition ([int]$audit.rejected_sessions -eq 1) "Expected 1 rejected session, got $($audit.rejected_sessions)."
Assert-Condition ([int]$audit.current_package_reports -eq 1) "Expected 1 current package report, got $($audit.current_package_reports)."

Write-Host '[clean-machine-report-intake-verify] ok'
Write-Host "[clean-machine-report-intake-verify] audit=$auditPath"
