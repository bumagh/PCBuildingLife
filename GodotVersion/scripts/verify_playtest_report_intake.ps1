[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$TempBase
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$playtestRoot = Join-Path $projectDir 'build\playtest'
$buildDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($TempBase)) {
    $TempBase = Join-Path $playtestRoot 'report-intake-test'
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

function Read-Sha256File {
    param([string]$Path)
    Assert-Condition (Test-Path -LiteralPath $Path) "Required file not found: $Path"
    return ((Get-Content -Raw -Encoding ASCII -LiteralPath $Path) -split '\s+')[0].Trim().ToLowerInvariant()
}

function Write-Report {
    param(
        [string]$Path,
        [string]$Tester,
        [string]$PackageHash,
        [int]$Score = 99
    )

    $lines = @(
        "# PC Building Life $Version Playtest Report",
        "",
        "- Tester: $Tester",
        "- Test date: 2026-07-20",
        "- Game version: $Version",
        "- Package SHA-256: $PackageHash",
        "- Windows version: Windows 11",
        "- CPU / GPU: Test CPU / Test GPU",
        "- Memory: 16 GB",
        "- Resolution: 1920x1080",
        "- Fullscreen or windowed: Windowed",
        "",
        "## Result",
        "",
        "- [x] Passed: finished first order, saved, restarted, and continued.",
        "- [ ] Playable with issues: finished first order but found problems.",
        "- [ ] Blocked: could not launch, finish first order, save, or continue.",
        "",
        "## First Order",
        "",
        "- Order name: Community Office PC",
        "- Final grade: S",
        "- Final score: $Score",
        "- Any confusing step: None",
        "",
        "## Issues",
        "",
        "1. What happened?",
        "2. What did you expect?",
        "3. How can it be reproduced?",
        "4. Screenshot or video path:",
        "",
        "## Most Important Fix",
        "",
        "Write the one thing that most needs improvement before public release.",
        "",
        "## Release Readiness Signal",
        "",
        "- [x] I would recommend this build to another tester.",
        "- [ ] I would wait for fixes before more testers play it.",
        "- [ ] This build should not be published yet because it has a blocking issue."
    )
    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$expectedPackageHash = Read-Sha256File -Path (Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip.sha256")
$tempBaseFullPath = [System.IO.Path]::GetFullPath($TempBase)
New-Item -ItemType Directory -Force -Path $tempBaseFullPath | Out-Null
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBaseFullPath "run-$([Guid]::NewGuid().ToString('N'))"))
Assert-Condition ($tempRoot.StartsWith($tempBaseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $tempRoot"

$inputDir = Join-Path $tempRoot 'incoming'
$reportsDir = Join-Path $tempRoot 'returned-reports'
$supportDir = Join-Path $tempRoot 'returned-support-bundles'
$auditDir = Join-Path $tempRoot 'audit'
$summaryDir = Join-Path $tempRoot 'summary'
$safeBundleDir = Join-Path $tempRoot 'safe-support'
$unsafeBundleDir = Join-Path $tempRoot 'unsafe-support'
New-Item -ItemType Directory -Force -Path $inputDir, $safeBundleDir, $unsafeBundleDir | Out-Null

try {
    Write-Report -Path (Join-Path $inputDir 'PLAYTEST_REPORT_OK_1.md') -Tester 'IntakeTester1' -PackageHash $expectedPackageHash -Score 99
    Write-Report -Path (Join-Path $inputDir 'PLAYTEST_REPORT_OK_2.md') -Tester 'IntakeTester2' -PackageHash $expectedPackageHash -Score 98
    Write-Report -Path (Join-Path $inputDir 'PLAYTEST_REPORT_OK_3.md') -Tester 'IntakeTester3' -PackageHash $expectedPackageHash -Score 97
    Write-Report -Path (Join-Path $inputDir 'PLAYTEST_REPORT_DUPLICATE_1.md') -Tester 'IntakeTester1' -PackageHash $expectedPackageHash -Score 96
    Write-Report -Path (Join-Path $inputDir 'PLAYTEST_REPORT_STALE_1.md') -Tester 'OldBuildTester' -PackageHash ('0' * 64) -Score 99

    '{"save_exists":true}' | Set-Content -LiteralPath (Join-Path $safeBundleDir 'save_summary.json') -Encoding UTF8
    '{"copied_log_count":0}' | Set-Content -LiteralPath (Join-Path $safeBundleDir 'log_summary.json') -Encoding UTF8
    Compress-Archive -Path (Join-Path $safeBundleDir '*') -DestinationPath (Join-Path $inputDir 'PCBuildingLife-support-safe.zip') -Force

    '{"raw_save":true}' | Set-Content -LiteralPath (Join-Path $unsafeBundleDir 'save_game.json') -Encoding UTF8
    Compress-Archive -Path (Join-Path $unsafeBundleDir '*') -DestinationPath (Join-Path $inputDir 'PCBuildingLife-support-unsafe.zip') -Force

    & (Join-Path $PSScriptRoot 'receive_playtest_reports.ps1') `
        -Version $Version `
        -InputDir $inputDir `
        -ReportsDir $reportsDir `
        -SupportDir $supportDir `
        -AuditDir $auditDir `
        -SummaryOutputDir $summaryDir `
        -AllowRejected

    $auditPath = Join-Path $auditDir "playtest-report-intake-$Version.json"
    $summaryPath = Join-Path $summaryDir "playtest-feedback-summary-$Version.json"
    Assert-Condition (Test-Path -LiteralPath $auditPath) "Missing intake audit: $auditPath"
    Assert-Condition (Test-Path -LiteralPath $summaryPath) "Missing intake summary: $summaryPath"

    $audit = Get-Content -Raw -Encoding UTF8 -LiteralPath $auditPath | ConvertFrom-Json
    $summary = Get-Content -Raw -Encoding UTF8 -LiteralPath $summaryPath | ConvertFrom-Json

    Assert-Condition (-not [bool]$audit.ok) 'Audit should be not-ok when rejected stale report and unsafe support bundle are present.'
    Assert-Condition ([int]$audit.accepted_reports -eq 3) "Expected 3 accepted reports, got $($audit.accepted_reports)."
    Assert-Condition ([int]$audit.skipped_duplicate_reports -eq 1) "Expected 1 duplicate report, got $($audit.skipped_duplicate_reports)."
    Assert-Condition ([int]$audit.rejected_reports -eq 1) "Expected 1 rejected report, got $($audit.rejected_reports)."
    Assert-Condition ([int]$audit.accepted_support_bundles -eq 1) "Expected 1 accepted support bundle, got $($audit.accepted_support_bundles)."
    Assert-Condition ([int]$audit.rejected_support_bundles -eq 1) "Expected 1 rejected support bundle, got $($audit.rejected_support_bundles)."
    Assert-Condition ([string]$summary.decision -eq 'go') "Expected sample summary decision go, got $($summary.decision)."
    Assert-Condition ([int]$summary.counts.current_package_reports -eq 3) "Expected 3 current-package reports, got $($summary.counts.current_package_reports)."

    Write-Host '[playtest-report-intake-verify] ok'
    Write-Host "[playtest-report-intake-verify] temp=$tempRoot"
    Write-Host "[playtest-report-intake-verify] package_sha256=$expectedPackageHash"
    Write-Host "[playtest-report-intake-verify] summary_decision=$($summary.decision)"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTempRoot.StartsWith($tempBaseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
