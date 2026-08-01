[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [int]$TesterCount = 3,
    [string]$OutputDir,
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
$buildDir = Join-Path $projectDir 'build\windows'
$playtestRoot = Join-Path $projectDir 'build\playtest'
$readinessRoot = Join-Path $projectDir 'build\release-readiness'
$externalRoot = Join-Path $projectDir 'build\external-validation'
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $externalRoot "PCBuildingLife-$Version"
}
$roundDir = [System.IO.Path]::GetFullPath($OutputDir)
$roundZipPath = Join-Path $externalRoot "PCBuildingLife-$Version-external-validation-round.zip"
$roundZipShaPath = "$roundZipPath.sha256"
$packageDir = Join-Path $roundDir 'package'
$reportsDir = Join-Path $roundDir 'returned-reports'
$evidenceDir = Join-Path $roundDir 'evidence'

$playerZipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$playerShaPath = "$playerZipPath.sha256"
$playtestKitPath = Join-Path $playtestRoot "PCBuildingLife-$Version-playtest-kit.zip"
$playtestKitShaPath = "$playtestKitPath.sha256"
$feedbackSummaryJsonPath = Join-Path $playtestRoot "feedback-summary\playtest-feedback-summary-$Version.json"
$feedbackSummaryMdPath = Join-Path $playtestRoot "feedback-summary\playtest-feedback-summary-$Version.md"
$readinessJsonPath = Join-Path $readinessRoot "release-readiness-$Version.json"
$readinessMdPath = Join-Path $readinessRoot "release-readiness-$Version.md"
$externalManifestPath = Join-Path $roundDir 'external-validation-manifest.json'

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

function Copy-RequiredFile {
    param(
        [string]$Source,
        [string]$Destination
    )
    Assert-File $Source
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

$resolvedExternalRoot = [System.IO.Path]::GetFullPath($externalRoot)
Assert-Condition ($roundDir.StartsWith($resolvedExternalRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to clean output outside external-validation root: $roundDir"
if (Test-Path -LiteralPath $roundDir) {
    Remove-Item -LiteralPath $roundDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageDir, $reportsDir, $evidenceDir | Out-Null

if (-not $SkipValidation) {
    & (Join-Path $PSScriptRoot 'verify_playtest_kit.ps1') -Version $Version
    & (Join-Path $PSScriptRoot 'receive_playtest_reports.ps1') -Version $Version
}

foreach ($required in @(
    $playerZipPath,
    $playerShaPath,
    $playtestKitPath,
    $playtestKitShaPath,
    $feedbackSummaryJsonPath,
    $feedbackSummaryMdPath
)) {
    Assert-File $required
}

$packageHash = Read-Sha256File -Path $playerShaPath
$kitHash = Read-Sha256File -Path $playtestKitShaPath
$feedbackSummary = Get-Content -Raw -Encoding UTF8 -LiteralPath $feedbackSummaryJsonPath | ConvertFrom-Json
Assert-Condition ([string]$feedbackSummary.expected_package_sha256 -eq $packageHash) 'Playtest feedback summary does not match the current package hash.'

Copy-RequiredFile -Source $playtestKitPath -Destination (Join-Path $packageDir (Split-Path -Leaf $playtestKitPath))
Copy-RequiredFile -Source $playtestKitShaPath -Destination (Join-Path $packageDir (Split-Path -Leaf $playtestKitShaPath))
Copy-RequiredFile -Source $playerShaPath -Destination (Join-Path $evidenceDir (Split-Path -Leaf $playerShaPath))
Copy-RequiredFile -Source $feedbackSummaryJsonPath -Destination (Join-Path $evidenceDir 'playtest-feedback-summary.json')
Copy-RequiredFile -Source $feedbackSummaryMdPath -Destination (Join-Path $evidenceDir 'playtest-feedback-summary.md')

$readinessDecision = 'not_checked'
$readinessFailCount = -1
$readinessWarnCount = -1

$readmeLines = @(
    "PC Building Life $Version External Validation Round",
    "",
    "Goal",
    "",
    "Collect at least $TesterCount valid external first-order reports for the current package before public release.",
    "",
    "Send to testers",
    "",
    "- package/PCBuildingLife-$Version-playtest-kit.zip",
    "- package/PCBuildingLife-$Version-playtest-kit.zip.sha256",
    "- TESTER_MESSAGE.md",
    "",
    "Tester path",
    "",
    "1. Extract the playtest kit ZIP.",
    "2. Double-click START_PLAYTEST_KIT.cmd.",
    "3. Finish the first order, save, restart, and confirm Continue Game works.",
    "4. Fill PLAYTEST_REPORT_*.md after the game closes.",
    "5. Return the report file. If blocked or crashed, also run COLLECT_SUPPORT_BUNDLE.cmd and return the support ZIP.",
    "",
    "Returned reports inbox",
    "",
    "Place returned PLAYTEST_REPORT_*.md files and PCBuildingLife-support-*.zip files into:",
    "GodotVersion/build/playtest/incoming-reports/",
    "",
    "Then run:",
    "powershell -NoProfile -ExecutionPolicy Bypass -File GodotVersion/scripts/receive_playtest_reports.ps1",
    "powershell -NoProfile -ExecutionPolicy Bypass -File GodotVersion/scripts/verify_release_readiness.ps1",
    "",
    "Current evidence",
    "",
    "- Player package SHA-256: $packageHash",
    "- Playtest kit SHA-256: $kitHash",
    "- Current returned reports: $($feedbackSummary.counts.current_package_reports)",
    "- Feedback decision: $($feedbackSummary.decision)",
    "- Readiness decision: run verify_release_readiness.ps1 after this round is prepared.",
    "- Readiness fails/warnings: not checked yet"
)
$readmeLines | Set-Content -LiteralPath (Join-Path $roundDir 'README_EXTERNAL_VALIDATION.txt') -Encoding UTF8

$testerMessageLines = @(
    "# PC Building Life $Version Playtest",
    "",
    "Please test this exact build:",
    "",
    "- Playtest kit: PCBuildingLife-$Version-playtest-kit.zip",
    "- Kit SHA-256: $kitHash",
    "- Player ZIP SHA-256: $packageHash",
    "",
    "Steps:",
    "",
    "1. Extract the ZIP.",
    "2. Run START_PLAYTEST_KIT.cmd.",
    "3. Start a new game and finish the first order.",
    "4. Save, close, restart, and confirm Continue Game works.",
    "5. Fill the generated PLAYTEST_REPORT_*.md file.",
    "6. If the game blocks, crashes, or behaves strangely, run COLLECT_SUPPORT_BUNDLE.cmd and return the generated support ZIP too.",
    "",
    "Please do not include passwords, phone numbers, payment data, account tokens, or private identity information in feedback."
)
$testerMessageLines | Set-Content -LiteralPath (Join-Path $roundDir 'TESTER_MESSAGE.md') -Encoding UTF8

$trackerLines = [System.Collections.Generic.List[string]]::new()
$trackerLines.Add('tester_id,tester_name,status,package_sha256,report_file,first_order_done,save_continue_done,recommend,blocking_issue,notes')
for ($i = 1; $i -le $TesterCount; $i++) {
    $trackerLines.Add(("T{0:00},,pending,{1},,,,,," -f $i, $packageHash))
}
$trackerLines | Set-Content -LiteralPath (Join-Path $roundDir 'EXTERNAL_VALIDATION_TRACKER.csv') -Encoding UTF8

$inboxLines = @(
    "Returned Reports Inbox",
    "",
    "Copy returned PLAYTEST_REPORT_*.md files and PCBuildingLife-support-*.zip files to GodotVersion/build/playtest/incoming-reports/, then run GodotVersion/scripts/receive_playtest_reports.ps1.",
    "Only reports whose Package SHA-256 equals the current player ZIP hash count toward the go decision.",
    "",
    "Current player ZIP SHA-256:",
    $packageHash
)
$inboxLines | Set-Content -LiteralPath (Join-Path $reportsDir 'README_RETURNED_REPORTS.txt') -Encoding UTF8

$manifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    tester_count = $TesterCount
    round_path = $roundDir
    round_zip = (Split-Path -Leaf $roundZipPath)
    round_zip_sha256_file = (Split-Path -Leaf $roundZipShaPath)
    playtest_kit = "package/$(Split-Path -Leaf $playtestKitPath)"
    playtest_kit_sha256_file = "package/$(Split-Path -Leaf $playtestKitShaPath)"
    playtest_kit_sha256 = $kitHash
    package_sha256 = $packageHash
    readiness_decision = $readinessDecision
    readiness_fail_count = $readinessFailCount
    readiness_warn_count = $readinessWarnCount
    feedback_summary_decision = [string]$feedbackSummary.decision
    current_package_reports = [int]$feedbackSummary.counts.current_package_reports
    required_current_package_reports = $TesterCount
    tracker = 'EXTERNAL_VALIDATION_TRACKER.csv'
    tester_message = 'TESTER_MESSAGE.md'
    returned_reports_inbox = 'returned-reports'
    created_at_utc = [DateTime]::UtcNow.ToString('o')
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $externalManifestPath -Encoding UTF8

$resolvedRoundZipPath = [System.IO.Path]::GetFullPath($roundZipPath)
Assert-Condition ($resolvedRoundZipPath.StartsWith($resolvedExternalRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to write ZIP outside external-validation root: $resolvedRoundZipPath"
if (Test-Path -LiteralPath $resolvedRoundZipPath) {
    Remove-Item -LiteralPath $resolvedRoundZipPath -Force
}
if (Test-Path -LiteralPath $roundZipShaPath) {
    Remove-Item -LiteralPath $roundZipShaPath -Force
}
$roundItems = @(Get-ChildItem -LiteralPath $roundDir -Force)
Assert-Condition ($roundItems.Count -gt 0) "External validation round directory is empty: $roundDir"
Compress-Archive -Path @($roundItems | ForEach-Object { $_.FullName }) -DestinationPath $resolvedRoundZipPath -Force
$roundZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedRoundZipPath).Hash.ToLowerInvariant()
("{0}  {1}" -f $roundZipHash, (Split-Path -Leaf $resolvedRoundZipPath)) | Set-Content -LiteralPath $roundZipShaPath -Encoding ASCII

if (-not $SkipValidation) {
    & (Join-Path $PSScriptRoot 'verify_external_validation_round.ps1') -Version $Version -RoundZipPath $resolvedRoundZipPath
}

if (-not $SkipValidation) {
    & (Join-Path $PSScriptRoot 'verify_release_readiness.ps1') -Version $Version
}
Assert-File $readinessJsonPath
Assert-File $readinessMdPath
$readiness = Get-Content -Raw -Encoding UTF8 -LiteralPath $readinessJsonPath | ConvertFrom-Json
Assert-Condition ([string]$readiness.current_package_sha256 -eq $packageHash) 'Release readiness report does not match the current package hash.'
Copy-RequiredFile -Source $readinessJsonPath -Destination (Join-Path $evidenceDir 'release-readiness.json')
Copy-RequiredFile -Source $readinessMdPath -Destination (Join-Path $evidenceDir 'release-readiness.md')

$manifest.readiness_decision = [string]$readiness.decision
$manifest.readiness_fail_count = [int]$readiness.fail_count
$manifest.readiness_warn_count = [int]$readiness.warn_count
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $externalManifestPath -Encoding UTF8

$readmeLines = @($readmeLines | ForEach-Object {
    if ($_ -like '- Readiness decision:*') {
        "- Readiness decision: $($readiness.decision)"
    }
    elseif ($_ -like '- Readiness fails/warnings:*') {
        "- Readiness fails/warnings: $($readiness.fail_count) / $($readiness.warn_count)"
    }
    else {
        $_
    }
})
$readmeLines | Set-Content -LiteralPath (Join-Path $roundDir 'README_EXTERNAL_VALIDATION.txt') -Encoding UTF8

Write-Host '[external-validation] ok'
Write-Host "[external-validation] $roundDir"
Write-Host "[external-validation] $resolvedRoundZipPath"
Write-Host "[external-validation] package_sha256=$packageHash"
Write-Host "[external-validation] kit_sha256=$kitHash"
Write-Host "[external-validation] round_zip_sha256=$roundZipHash"
