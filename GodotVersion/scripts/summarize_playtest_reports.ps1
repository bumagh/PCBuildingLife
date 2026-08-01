[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$ReportsDir,
    [string]$OutputDir,
    [string]$ExpectedPackageSha256
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$playtestRoot = Join-Path $projectDir 'build\playtest'
$buildDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($ReportsDir)) {
    $ReportsDir = Join-Path $playtestRoot 'returned-reports'
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $playtestRoot 'feedback-summary'
}
if ([string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) {
    $shaPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip.sha256"
    if (Test-Path -LiteralPath $shaPath) {
        $ExpectedPackageSha256 = ((Get-Content -Raw -Encoding ASCII -LiteralPath $shaPath) -split '\s+')[0].Trim().ToLowerInvariant()
    }
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

function Test-CheckedLine {
    param(
        [string]$Text,
        [string]$Needle
    )

    $pattern = '(?im)^\s*-\s*\[[x]\]\s*' + [regex]::Escape($Needle)
    return [regex]::IsMatch($Text, $pattern)
}

function Get-MarkdownSection {
    param(
        [string]$Text,
        [string]$Heading
    )

    $pattern = '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*$\s*(.*?)(?=^##\s+|\z)'
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ''
}

function Get-MeaningfulLines {
    param([string]$Text)

    $lines = @($Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -ne '' -and
        $_ -notmatch '^\d+\.\s*What happened\??$' -and
        $_ -notmatch '^\d+\.\s*What did you expect\??$' -and
        $_ -notmatch '^\d+\.\s*How can it be reproduced\??$' -and
        $_ -notmatch '^\d+\.\s*Screenshot or video path\:?$' -and
        $_ -notmatch '^Write the one thing that most needs improvement before public release\.?$'
    })
    return $lines
}

function Get-Severity {
    param(
        [string]$Text,
        [string]$Status,
        [bool]$WaitForFixes,
        [bool]$NoPublish,
        [bool]$HasMeaningfulIssue
    )

    if ($Status -eq 'blocked' -or $NoPublish) {
        return 'P0'
    }
    if ($Text -match '(?i)\bP0\b|blocking issue|could not launch|cannot launch|could not finish|could not save|could not continue|crash|hang|black screen') {
        return 'P0'
    }
    if ($Status -eq 'playable_with_issues' -or $WaitForFixes) {
        return 'P1'
    }
    if ($Text -match '(?i)\bP1\b|unreadable|overlap|blocked ui|cannot click|performance|not responding') {
        return 'P1'
    }
    if ($Text -match '(?i)\bP2\b' -or $HasMeaningfulIssue) {
        return 'P2'
    }
    return 'None'
}

New-Item -ItemType Directory -Force -Path $ReportsDir, $OutputDir | Out-Null

$reportFiles = @(Get-ChildItem -LiteralPath $ReportsDir -Filter 'PLAYTEST_REPORT_*.md' -File -ErrorAction SilentlyContinue | Sort-Object Name)
$reports = @()

foreach ($file in $reportFiles) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $issuesSection = Get-MarkdownSection -Text $text -Heading 'Issues'
    $fixSection = Get-MarkdownSection -Text $text -Heading 'Most Important Fix'
    $issueLines = @(Get-MeaningfulLines -Text $issuesSection)
    $fixLines = @(Get-MeaningfulLines -Text $fixSection)
    $hasMeaningfulIssue = (($issueLines.Count + $fixLines.Count) -gt 0)

    $passed = Test-CheckedLine -Text $text -Needle 'Passed:'
    $playable = Test-CheckedLine -Text $text -Needle 'Playable with issues:'
    $blocked = Test-CheckedLine -Text $text -Needle 'Blocked:'
    $recommend = Test-CheckedLine -Text $text -Needle 'I would recommend this build'
    $waitForFixes = Test-CheckedLine -Text $text -Needle 'I would wait for fixes'
    $noPublish = Test-CheckedLine -Text $text -Needle 'This build should not be published yet'

    $status = 'unknown'
    if ($blocked) {
        $status = 'blocked'
    }
    elseif ($playable) {
        $status = 'playable_with_issues'
    }
    elseif ($passed) {
        $status = 'passed'
    }

    $noteText = (($issueLines + $fixLines) -join "`n")
    $severity = Get-Severity -Text $noteText -Status $status -WaitForFixes $waitForFixes -NoPublish $noPublish -HasMeaningfulIssue $hasMeaningfulIssue
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()

    $reports += [pscustomobject]@{
        file = $file.Name
        sha256 = $hash
        tester = Get-ReportField -Text $text -Name 'Tester'
        test_date = Get-ReportField -Text $text -Name 'Test date'
        game_version = Get-ReportField -Text $text -Name 'Game version'
        package_sha256 = (Get-ReportField -Text $text -Name 'Package SHA-256').ToLowerInvariant()
        windows_version = Get-ReportField -Text $text -Name 'Windows version'
        cpu_gpu = Get-ReportField -Text $text -Name 'CPU / GPU'
        memory = Get-ReportField -Text $text -Name 'Memory'
        resolution = Get-ReportField -Text $text -Name 'Resolution'
        display_mode = Get-ReportField -Text $text -Name 'Fullscreen or windowed'
        order_name = Get-ReportField -Text $text -Name 'Order name'
        final_grade = Get-ReportField -Text $text -Name 'Final grade'
        final_score = Get-ReportField -Text $text -Name 'Final score'
        confusing_step = Get-ReportField -Text $text -Name 'Any confusing step'
        status = $status
        severity = $severity
        readiness = [pscustomobject]@{
            recommend = $recommend
            wait_for_fixes = $waitForFixes
            no_publish = $noPublish
        }
        issue_lines = $issueLines
        most_important_fix = $fixLines
    }
}

$total = $reports.Count
$currentReports = @($reports | Where-Object {
    -not [string]::IsNullOrWhiteSpace($ExpectedPackageSha256) -and
    [string]$_.package_sha256 -eq $ExpectedPackageSha256
})
$staleOrUnknownPackageCount = $total - $currentReports.Count
$passedCount = @($currentReports | Where-Object { $_.status -eq 'passed' }).Count
$playableCount = @($currentReports | Where-Object { $_.status -eq 'playable_with_issues' }).Count
$blockedCount = @($currentReports | Where-Object { $_.status -eq 'blocked' }).Count
$unknownCount = @($currentReports | Where-Object { $_.status -eq 'unknown' }).Count
$recommendCount = @($currentReports | Where-Object { $_.readiness.recommend }).Count
$waitCount = @($currentReports | Where-Object { $_.readiness.wait_for_fixes }).Count
$noPublishCount = @($currentReports | Where-Object { $_.readiness.no_publish }).Count
$p0Count = @($currentReports | Where-Object { $_.severity -eq 'P0' }).Count
$p1Count = @($currentReports | Where-Object { $_.severity -eq 'P1' }).Count
$p2Count = @($currentReports | Where-Object { $_.severity -eq 'P2' }).Count
$completedFirstOrderCount = @($currentReports | Where-Object { $_.status -eq 'passed' -or $_.status -eq 'playable_with_issues' }).Count

$decision = 'need_more_reports'
$decisionReason = 'Need at least 3 valid external reports before public release.'
if ([string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) {
    $decision = 'missing_expected_package_hash'
    $decisionReason = 'Could not determine the current package SHA-256, so returned reports cannot be matched to this build.'
}
elseif ($currentReports.Count -ge 3 -and $p0Count -gt 0) {
    $decision = 'no_go'
    $decisionReason = 'At least one P0 or no-publish report blocks release.'
}
elseif ($currentReports.Count -ge 3 -and ($p1Count -gt 0 -or $waitCount -gt 0)) {
    $decision = 'fix_then_retest'
    $decisionReason = 'External reports show P1 issues or testers want fixes first.'
}
elseif ($currentReports.Count -ge 3 -and $passedCount -ge 3 -and $recommendCount -ge 3) {
    $decision = 'go'
    $decisionReason = 'At least 3 testers passed the first-order/save/continue path and recommend the build.'
}
elseif ($currentReports.Count -ge 3) {
    $decision = 'need_more_evidence'
    $decisionReason = 'Report volume is enough, but pass/recommend evidence is not strong enough yet.'
}

$summary = [pscustomobject]@{
    product = 'PC Building Life'
    version = $Version
    reports_dir = [System.IO.Path]::GetFullPath($ReportsDir)
    output_dir = [System.IO.Path]::GetFullPath($OutputDir)
    expected_package_sha256 = $ExpectedPackageSha256
    created_at_utc = [DateTime]::UtcNow.ToString('o')
    counts = [pscustomobject]@{
        total_reports = $total
        current_package_reports = $currentReports.Count
        stale_or_unknown_package_reports = $staleOrUnknownPackageCount
        passed = $passedCount
        playable_with_issues = $playableCount
        blocked = $blockedCount
        unknown = $unknownCount
        completed_first_order = $completedFirstOrderCount
        recommend = $recommendCount
        wait_for_fixes = $waitCount
        no_publish = $noPublishCount
        p0 = $p0Count
        p1 = $p1Count
        p2 = $p2Count
    }
    decision = $decision
    decision_reason = $decisionReason
    reports = @($reports)
}

$jsonPath = Join-Path $OutputDir "playtest-feedback-summary-$Version.json"
$mdPath = Join-Path $OutputDir "playtest-feedback-summary-$Version.md"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdLines = @(
    "# PC Building Life $Version Playtest Feedback Summary",
    "",
    "- Reports dir: $([System.IO.Path]::GetFullPath($ReportsDir))",
    "- Expected package SHA-256: $ExpectedPackageSha256",
    "- Total reports: $total",
    "- Current-package reports: $($currentReports.Count)",
    "- Stale or unknown-package reports: $staleOrUnknownPackageCount",
    "- Passed: $passedCount",
    "- Playable with issues: $playableCount",
    "- Blocked: $blockedCount",
    "- Unknown: $unknownCount",
    "- Completed first order: $completedFirstOrderCount",
    "- Recommend: $recommendCount",
    "- Wait for fixes: $waitCount",
    "- No publish: $noPublishCount",
    "- P0/P1/P2: $p0Count / $p1Count / $p2Count",
    "- Decision: $decision",
    "- Reason: $decisionReason",
    "",
    "## Reports",
    "",
    "| File | Tester | Package | Status | Severity | Grade | Score | Readiness |",
    "| --- | --- | --- | --- | --- | --- | --- | --- |"
)

foreach ($report in $reports) {
    $readiness = 'none'
    if ($report.readiness.no_publish) {
        $readiness = 'no_publish'
    }
    elseif ($report.readiness.wait_for_fixes) {
        $readiness = 'wait_for_fixes'
    }
    elseif ($report.readiness.recommend) {
        $readiness = 'recommend'
    }

    $packageState = 'current'
    if ([string]::IsNullOrWhiteSpace($report.package_sha256)) {
        $packageState = 'missing'
    }
    elseif ($report.package_sha256 -ne $ExpectedPackageSha256) {
        $packageState = 'stale'
    }

    $mdLines += "| $($report.file) | $($report.tester) | $packageState | $($report.status) | $($report.severity) | $($report.final_grade) | $($report.final_score) | $readiness |"
}

$mdLines += @(
    "",
    "## Most Important Fixes",
    ""
)

$fixIndex = 1
foreach ($report in $reports) {
    foreach ($line in @($report.most_important_fix)) {
        $mdLines += "$fixIndex. [$($report.file)] $line"
        $fixIndex += 1
    }
}
if ($fixIndex -eq 1) {
    $mdLines += "None reported."
}

$mdLines += @(
    "",
    "## Issue Notes",
    ""
)

$issueIndex = 1
foreach ($report in $reports) {
    foreach ($line in @($report.issue_lines)) {
        $mdLines += "$issueIndex. [$($report.file)] $line"
        $issueIndex += 1
    }
}
if ($issueIndex -eq 1) {
    $mdLines += "None reported."
}

$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[playtest-summary] ok'
Write-Host "[playtest-summary] reports=$total decision=$decision"
Write-Host "[playtest-summary] json=$jsonPath"
Write-Host "[playtest-summary] markdown=$mdPath"
