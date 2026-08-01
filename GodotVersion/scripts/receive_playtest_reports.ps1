[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$InputDir,
    [string]$ReportsDir,
    [string]$SupportDir,
    [string]$AuditDir,
    [string]$SummaryOutputDir,
    [string]$ExpectedPackageSha256,
    [switch]$AllowRejected,
    [switch]$SkipSummary
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$playtestRoot = Join-Path $projectDir 'build\playtest'
$buildDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($InputDir)) {
    $InputDir = Join-Path $playtestRoot 'incoming-reports'
}
if ([string]::IsNullOrWhiteSpace($ReportsDir)) {
    $ReportsDir = Join-Path $playtestRoot 'returned-reports'
}
if ([string]::IsNullOrWhiteSpace($SupportDir)) {
    $SupportDir = Join-Path $playtestRoot 'returned-support-bundles'
}
if ([string]::IsNullOrWhiteSpace($AuditDir)) {
    $AuditDir = Join-Path $playtestRoot 'report-intake'
}
if ([string]::IsNullOrWhiteSpace($SummaryOutputDir)) {
    $SummaryOutputDir = Join-Path $playtestRoot 'feedback-summary'
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

function ConvertTo-SafeFileName {
    param([string]$Name)
    $safe = $Name -replace '[^\w\-.]', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'unknown'
    }
    return $safe
}

function Get-ReportField {
    param(
        [string]$Text,
        [string]$Name
    )

    $pattern = '(?m)^\s*-\s*' + [regex]::Escape($Name) + '\s*:\s*(.*)\s*$'
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ''
}

function ConvertTo-LowerText {
    param([object]$Value)
    if ($null -eq $Value) {
        return ''
    }
    return ([string]$Value).ToLowerInvariant()
}

function Test-CheckedLine {
    param(
        [string]$Text,
        [string]$Needle
    )

    $pattern = '(?im)^\s*-\s*\[[x]\]\s*' + [regex]::Escape($Needle)
    return [regex]::IsMatch($Text, $pattern)
}

function Get-ExistingReportKeys {
    param([string]$Path)

    $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ,$keys
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Filter 'PLAYTEST_REPORT_*.md' -File -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        $tester = ConvertTo-LowerText (Get-ReportField -Text $text -Name 'Tester')
        $packageHash = ConvertTo-LowerText (Get-ReportField -Text $text -Name 'Package SHA-256')
        if (-not [string]::IsNullOrWhiteSpace($tester) -and -not [string]::IsNullOrWhiteSpace($packageHash)) {
            [void]$keys.Add("$packageHash|$tester")
        }
    }
    return ,$keys
}

function Test-SupportBundle {
    param([string]$Path)

    $result = [ordered]@{
        ok = $true
        reason = ''
        entry_count = 0
        size_bytes = (Get-Item -LiteralPath $Path).Length
    }

    if ([int64]$result.size_bytes -gt 50MB) {
        $result.ok = $false
        $result.reason = 'Support bundle is larger than 50 MB.'
        return [pscustomobject]$result
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead([System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path)))
    try {
        $badEntries = @()
        foreach ($entry in $archive.Entries) {
            $result.entry_count += 1
            $name = $entry.FullName.Replace('\', '/').ToLowerInvariant()
            $leaf = [System.IO.Path]::GetFileName($name)
            if ($leaf -eq 'save_game.json' -or $leaf -eq 'settings.cfg' -or $leaf -eq 'auth.json' -or $leaf -like '*.sqlite' -or $leaf -like '*.db') {
                $badEntries += $entry.FullName
            }
        }
        if ($badEntries.Count -gt 0) {
            $result.ok = $false
            $result.reason = "Support bundle contains raw or sensitive files: $($badEntries -join ', ')"
        }
    }
    finally {
        $archive.Dispose()
    }

    return [pscustomobject]$result
}

Assert-Condition (-not [string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) 'ExpectedPackageSha256 is required or must be readable from the current Windows package .sha256 file.'
Assert-Condition ($ExpectedPackageSha256 -match '^[0-9a-f]{64}$') "ExpectedPackageSha256 is invalid: $ExpectedPackageSha256"

$inputFullPath = [System.IO.Path]::GetFullPath($InputDir)
$reportsFullPath = [System.IO.Path]::GetFullPath($ReportsDir)
$supportFullPath = [System.IO.Path]::GetFullPath($SupportDir)
$auditFullPath = [System.IO.Path]::GetFullPath($AuditDir)
New-Item -ItemType Directory -Force -Path $inputFullPath, $reportsFullPath, $supportFullPath, $auditFullPath | Out-Null

$existingContentHashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($existing in @(Get-ChildItem -LiteralPath $reportsFullPath -Filter 'PLAYTEST_REPORT_*.md' -File -ErrorAction SilentlyContinue)) {
    [void]$existingContentHashes.Add((Get-FileHash -Algorithm SHA256 -LiteralPath $existing.FullName).Hash.ToLowerInvariant())
}
$existingReportKeys = Get-ExistingReportKeys -Path $reportsFullPath
$acceptedReportKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$reportFiles = @(Get-ChildItem -LiteralPath $inputFullPath -Filter 'PLAYTEST_REPORT_*.md' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
$supportFiles = @(Get-ChildItem -LiteralPath $inputFullPath -Filter 'PCBuildingLife-support-*.zip' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
$reports = @()
$acceptedReports = 0
$skippedDuplicateReports = 0
$rejectedReports = 0

foreach ($file in $reportFiles) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $fileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $tester = Get-ReportField -Text $text -Name 'Tester'
    $testDate = Get-ReportField -Text $text -Name 'Test date'
    $gameVersion = Get-ReportField -Text $text -Name 'Game version'
    $packageHash = ConvertTo-LowerText (Get-ReportField -Text $text -Name 'Package SHA-256')
    $windowsVersion = Get-ReportField -Text $text -Name 'Windows version'
    $resolution = Get-ReportField -Text $text -Name 'Resolution'
    $orderName = Get-ReportField -Text $text -Name 'Order name'
    $finalGrade = Get-ReportField -Text $text -Name 'Final grade'
    $finalScore = Get-ReportField -Text $text -Name 'Final score'

    $passed = Test-CheckedLine -Text $text -Needle 'Passed:'
    $playable = Test-CheckedLine -Text $text -Needle 'Playable with issues:'
    $blocked = Test-CheckedLine -Text $text -Needle 'Blocked:'
    $recommend = Test-CheckedLine -Text $text -Needle 'I would recommend this build'
    $waitForFixes = Test-CheckedLine -Text $text -Needle 'I would wait for fixes'
    $noPublish = Test-CheckedLine -Text $text -Needle 'This build should not be published yet'

    $resultCount = @(($passed, $playable, $blocked) | Where-Object { $_ }).Count
    $readinessCount = @(($recommend, $waitForFixes, $noPublish) | Where-Object { $_ }).Count
    $problems = @()
    foreach ($requiredField in @(
        @{ name = 'Tester'; value = $tester },
        @{ name = 'Test date'; value = $testDate },
        @{ name = 'Game version'; value = $gameVersion },
        @{ name = 'Package SHA-256'; value = $packageHash },
        @{ name = 'Windows version'; value = $windowsVersion },
        @{ name = 'Resolution'; value = $resolution }
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$requiredField.value)) {
            $problems += "Missing field: $($requiredField.name)"
        }
    }
    if ($gameVersion -ne $Version) {
        $problems += "Game version mismatch: $gameVersion"
    }
    if ($packageHash -ne $ExpectedPackageSha256) {
        $problems += "Package SHA-256 mismatch: $packageHash"
    }
    if ($resultCount -ne 1) {
        $problems += "Expected exactly one Result checkbox, got $resultCount"
    }
    if ($readinessCount -ne 1) {
        $problems += "Expected exactly one Release Readiness Signal checkbox, got $readinessCount"
    }
    if (($passed -or $playable) -and ([string]::IsNullOrWhiteSpace($orderName) -or [string]::IsNullOrWhiteSpace($finalGrade) -or [string]::IsNullOrWhiteSpace($finalScore))) {
        $problems += 'Passed/playable report is missing first-order result fields.'
    }

    $reportKey = "$packageHash|$(ConvertTo-LowerText $tester)"
    $status = 'accepted'
    $destination = ''
    if ($problems.Count -gt 0) {
        $status = 'rejected'
        $rejectedReports += 1
    }
    elseif ($existingContentHashes.Contains($fileHash) -or $existingReportKeys.Contains($reportKey) -or $acceptedReportKeys.Contains($reportKey)) {
        $status = 'duplicate'
        $skippedDuplicateReports += 1
    }
    else {
        $safeTester = ConvertTo-SafeFileName -Name $tester
        $safeDate = ConvertTo-SafeFileName -Name $testDate
        $destName = "PLAYTEST_REPORT_${safeDate}_${safeTester}_$($fileHash.Substring(0, 8)).md"
        $destPath = Join-Path $reportsFullPath $destName
        Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
        $destination = $destPath
        [void]$existingContentHashes.Add($fileHash)
        [void]$acceptedReportKeys.Add($reportKey)
        $acceptedReports += 1
    }

    $reports += [ordered]@{
        source = $file.FullName
        destination = $destination
        file_sha256 = $fileHash
        status = $status
        problems = $problems
        tester = $tester
        test_date = $testDate
        game_version = $gameVersion
        package_sha256 = $packageHash
    }
}

$supportBundles = @()
$acceptedSupportBundles = 0
$rejectedSupportBundles = 0
$skippedDuplicateSupportBundles = 0
$existingSupportHashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($existing in @(Get-ChildItem -LiteralPath $supportFullPath -Filter 'PCBuildingLife-support-*.zip' -File -ErrorAction SilentlyContinue)) {
    [void]$existingSupportHashes.Add((Get-FileHash -Algorithm SHA256 -LiteralPath $existing.FullName).Hash.ToLowerInvariant())
}

foreach ($file in $supportFiles) {
    $fileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $bundleCheck = Test-SupportBundle -Path $file.FullName
    $status = 'accepted'
    $destination = ''
    $problems = @()
    if (-not [bool]$bundleCheck.ok) {
        $status = 'rejected'
        $problems += [string]$bundleCheck.reason
        $rejectedSupportBundles += 1
    }
    elseif ($existingSupportHashes.Contains($fileHash)) {
        $status = 'duplicate'
        $skippedDuplicateSupportBundles += 1
    }
    else {
        $destName = "PCBuildingLife-support-$($fileHash.Substring(0, 8)).zip"
        $destPath = Join-Path $supportFullPath $destName
        Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
        $destination = $destPath
        [void]$existingSupportHashes.Add($fileHash)
        $acceptedSupportBundles += 1
    }

    $supportBundles += [ordered]@{
        source = $file.FullName
        destination = $destination
        file_sha256 = $fileHash
        status = $status
        problems = $problems
        entry_count = [int]$bundleCheck.entry_count
        size_bytes = [int64]$bundleCheck.size_bytes
    }
}

$summaryDecision = 'not_run'
$summaryCurrentReports = 0
if (-not $SkipSummary) {
    $summaryOutputFullPath = [System.IO.Path]::GetFullPath($SummaryOutputDir)
    & (Join-Path $PSScriptRoot 'summarize_playtest_reports.ps1') -Version $Version -ReportsDir $reportsFullPath -OutputDir $summaryOutputFullPath
    $summaryPath = Join-Path $summaryOutputFullPath "playtest-feedback-summary-$Version.json"
    if (Test-Path -LiteralPath $summaryPath) {
        $summary = Get-Content -Raw -Encoding UTF8 -LiteralPath $summaryPath | ConvertFrom-Json
        $summaryDecision = [string]$summary.decision
        $summaryCurrentReports = [int]$summary.counts.current_package_reports
    }
}

$ok = ($rejectedReports -eq 0 -and $rejectedSupportBundles -eq 0)
$audit = [ordered]@{
    ok = $ok
    product = 'PC Building Life'
    version = $Version
    input_dir = $inputFullPath
    reports_dir = $reportsFullPath
    support_dir = $supportFullPath
    summary_output_dir = if ($SkipSummary) { $null } else { [System.IO.Path]::GetFullPath($SummaryOutputDir) }
    expected_package_sha256 = $ExpectedPackageSha256
    report_files_seen = $reportFiles.Count
    accepted_reports = $acceptedReports
    skipped_duplicate_reports = $skippedDuplicateReports
    rejected_reports = $rejectedReports
    support_bundles_seen = $supportFiles.Count
    accepted_support_bundles = $acceptedSupportBundles
    skipped_duplicate_support_bundles = $skippedDuplicateSupportBundles
    rejected_support_bundles = $rejectedSupportBundles
    summary_decision = $summaryDecision
    summary_current_package_reports = $summaryCurrentReports
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    reports = $reports
    support_bundles = $supportBundles
}

$jsonPath = Join-Path $auditFullPath "playtest-report-intake-$Version.json"
$mdPath = Join-Path $auditFullPath "playtest-report-intake-$Version.md"
$audit | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdLines = @(
    "# PC Building Life $Version Playtest Report Intake",
    "",
    "- Input dir: $inputFullPath",
    "- Reports dir: $reportsFullPath",
    "- Support dir: $supportFullPath",
    "- Expected package SHA-256: $ExpectedPackageSha256",
    "- Report files seen: $($reportFiles.Count)",
    "- Accepted reports: $acceptedReports",
    "- Skipped duplicate reports: $skippedDuplicateReports",
    "- Rejected reports: $rejectedReports",
    "- Support bundles seen: $($supportFiles.Count)",
    "- Accepted support bundles: $acceptedSupportBundles",
    "- Rejected support bundles: $rejectedSupportBundles",
    "- Summary decision: $summaryDecision",
    "- Current-package reports after intake: $summaryCurrentReports",
    "- OK: $ok",
    "",
    "## Reports",
    "",
    "| Source | Status | Tester | Problems |",
    "| --- | --- | --- | --- |"
)
foreach ($report in $reports) {
    $mdLines += "| $([System.IO.Path]::GetFileName($report.source)) | $($report.status) | $($report.tester) | $($report.problems -join '; ') |"
}
if ($reports.Count -eq 0) {
    $mdLines += "| none | none | none | none |"
}
$mdLines += @(
    "",
    "## Support Bundles",
    "",
    "| Source | Status | Problems |",
    "| --- | --- | --- |"
)
foreach ($bundle in $supportBundles) {
    $mdLines += "| $([System.IO.Path]::GetFileName($bundle.source)) | $($bundle.status) | $($bundle.problems -join '; ') |"
}
if ($supportBundles.Count -eq 0) {
    $mdLines += "| none | none | none |"
}
$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[playtest-report-intake] ok'
Write-Host "[playtest-report-intake] input=$inputFullPath"
Write-Host "[playtest-report-intake] accepted_reports=$acceptedReports rejected_reports=$rejectedReports duplicates=$skippedDuplicateReports"
Write-Host "[playtest-report-intake] summary_decision=$summaryDecision current_package_reports=$summaryCurrentReports"
Write-Host "[playtest-report-intake] json=$jsonPath"
Write-Host "[playtest-report-intake] markdown=$mdPath"

if (-not $ok -and -not $AllowRejected) {
    exit 1
}
