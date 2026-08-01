[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$InputDir,
    [string]$ReportsDir,
    [string]$SessionsDir,
    [string]$AuditDir,
    [string]$ExpectedPackageSha256,
    [int]$RequiredReports = 1,
    [switch]$AllowRejected
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validationRoot = Join-Path $projectDir 'build\clean-machine-validation'
$buildDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($InputDir)) {
    $InputDir = Join-Path $validationRoot 'incoming-reports'
}
if ([string]::IsNullOrWhiteSpace($ReportsDir)) {
    $ReportsDir = Join-Path $validationRoot 'returned-reports'
}
if ([string]::IsNullOrWhiteSpace($SessionsDir)) {
    $SessionsDir = Join-Path $validationRoot 'returned-sessions'
}
if ([string]::IsNullOrWhiteSpace($AuditDir)) {
    $AuditDir = Join-Path $validationRoot 'report-intake'
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

function ConvertTo-LowerText {
    param([object]$Value)
    if ($null -eq $Value) {
        return ''
    }
    return ([string]$Value).ToLowerInvariant()
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

function Get-ExistingReportKeys {
    param([string]$Path)

    $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ,$keys
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Filter 'CLEAN_MACHINE_REPORT_*.md' -File -ErrorAction SilentlyContinue)
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

function Read-CleanMachineReport {
    param([string]$Path)

    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    $passed = Test-CheckedLine -Text $text -Needle 'Passed:'
    $playable = Test-CheckedLine -Text $text -Needle 'Playable with issues:'
    $blocked = Test-CheckedLine -Text $text -Needle 'Blocked:'
    $recommend = Test-CheckedLine -Text $text -Needle 'I would recommend this build'
    $waitForFixes = Test-CheckedLine -Text $text -Needle 'I would wait for fixes'
    $noPublish = Test-CheckedLine -Text $text -Needle 'This build should not be published yet'

    return [pscustomobject]@{
        tester = Get-ReportField -Text $text -Name 'Tester'
        test_date = Get-ReportField -Text $text -Name 'Test date'
        machine_type = Get-ReportField -Text $text -Name 'Machine type'
        game_version = Get-ReportField -Text $text -Name 'Game version'
        package_sha256 = ConvertTo-LowerText (Get-ReportField -Text $text -Name 'Package SHA-256')
        package_source = Get-ReportField -Text $text -Name 'Package source'
        public_package_url = Get-ReportField -Text $text -Name 'Public package URL'
        windows_version = Get-ReportField -Text $text -Name 'Windows version'
        cpu_gpu = Get-ReportField -Text $text -Name 'CPU / GPU'
        memory = Get-ReportField -Text $text -Name 'Memory'
        resolution = Get-ReportField -Text $text -Name 'Resolution'
        display_mode = Get-ReportField -Text $text -Name 'Fullscreen or windowed'
        order_name = Get-ReportField -Text $text -Name 'Order name'
        final_grade = Get-ReportField -Text $text -Name 'Final grade'
        final_score = Get-ReportField -Text $text -Name 'Final score'
        package_verified = Test-CheckedLine -Text $text -Needle 'Package SHA-256 verified before launch.'
        launched_from_zip = Test-CheckedLine -Text $text -Needle 'Game launched from extracted ZIP.'
        new_game = Test-CheckedLine -Text $text -Needle 'Started a new game.'
        first_order = Test-CheckedLine -Text $text -Needle 'Finished first order.'
        saved = Test-CheckedLine -Text $text -Needle 'Saved progress.'
        reopened = Test-CheckedLine -Text $text -Needle 'Closed and reopened the game.'
        continued = Test-CheckedLine -Text $text -Needle 'Continue Game loaded the save.'
        no_previous_save = Test-CheckedLine -Text $text -Needle 'No previous PC Building Life save was used.'
        passed = $passed
        playable = $playable
        blocked = $blocked
        recommend = $recommend
        wait_for_fixes = $waitForFixes
        no_publish = $noPublish
        result_count = @(($passed, $playable, $blocked) | Where-Object { $_ }).Count
        readiness_count = @(($recommend, $waitForFixes, $noPublish) | Where-Object { $_ }).Count
    }
}

function Test-SessionJson {
    param([string]$Path)

    $result = [ordered]@{
        ok = $true
        reason = ''
        size_bytes = (Get-Item -LiteralPath $Path).Length
    }

    if ([int64]$result.size_bytes -gt 2MB) {
        $result.ok = $false
        $result.reason = 'Session JSON is larger than 2 MB.'
        return [pscustomobject]$result
    }

    try {
        $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
        if ([string]$json.package_sha256 -and [string]$json.package_sha256 -notmatch '^[0-9a-fA-F]{64}$') {
            $result.ok = $false
            $result.reason = 'Session JSON package_sha256 is invalid.'
        }
    }
    catch {
        $result.ok = $false
        $result.reason = "Session JSON could not be parsed: $($_.Exception.Message)"
    }

    return [pscustomobject]$result
}

Assert-Condition (-not [string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) 'ExpectedPackageSha256 is required or must be readable from the current Windows package .sha256 file.'
Assert-Condition ($ExpectedPackageSha256 -match '^[0-9a-f]{64}$') "ExpectedPackageSha256 is invalid: $ExpectedPackageSha256"
Assert-Condition ($RequiredReports -ge 1) "RequiredReports must be at least 1, got $RequiredReports"

$inputFullPath = [System.IO.Path]::GetFullPath($InputDir)
$reportsFullPath = [System.IO.Path]::GetFullPath($ReportsDir)
$sessionsFullPath = [System.IO.Path]::GetFullPath($SessionsDir)
$auditFullPath = [System.IO.Path]::GetFullPath($AuditDir)
New-Item -ItemType Directory -Force -Path $inputFullPath, $reportsFullPath, $sessionsFullPath, $auditFullPath | Out-Null

$existingContentHashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($existing in @(Get-ChildItem -LiteralPath $reportsFullPath -Filter 'CLEAN_MACHINE_REPORT_*.md' -File -ErrorAction SilentlyContinue)) {
    [void]$existingContentHashes.Add((Get-FileHash -Algorithm SHA256 -LiteralPath $existing.FullName).Hash.ToLowerInvariant())
}
$existingReportKeys = Get-ExistingReportKeys -Path $reportsFullPath
$acceptedReportKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$reportFiles = @(Get-ChildItem -LiteralPath $inputFullPath -Filter 'CLEAN_MACHINE_REPORT_*.md' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
$sessionFiles = @(Get-ChildItem -LiteralPath $inputFullPath -Filter 'clean-machine-session-*.json' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
$reports = @()
$acceptedReports = 0
$skippedDuplicateReports = 0
$rejectedReports = 0

foreach ($file in $reportFiles) {
    $parsed = Read-CleanMachineReport -Path $file.FullName
    $fileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $requiredPathOk = (
        [bool]$parsed.package_verified -and
        [bool]$parsed.launched_from_zip -and
        [bool]$parsed.new_game -and
        [bool]$parsed.first_order -and
        [bool]$parsed.saved -and
        [bool]$parsed.reopened -and
        [bool]$parsed.continued -and
        [bool]$parsed.no_previous_save
    )

    $problems = @()
    foreach ($requiredField in @(
        @{ name = 'Tester'; value = $parsed.tester },
        @{ name = 'Test date'; value = $parsed.test_date },
        @{ name = 'Machine type'; value = $parsed.machine_type },
        @{ name = 'Game version'; value = $parsed.game_version },
        @{ name = 'Package SHA-256'; value = $parsed.package_sha256 },
        @{ name = 'Package source'; value = $parsed.package_source },
        @{ name = 'Windows version'; value = $parsed.windows_version },
        @{ name = 'CPU / GPU'; value = $parsed.cpu_gpu },
        @{ name = 'Memory'; value = $parsed.memory },
        @{ name = 'Resolution'; value = $parsed.resolution }
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$requiredField.value)) {
            $problems += "Missing field: $($requiredField.name)"
        }
    }
    if ([string]$parsed.game_version -ne $Version) {
        $problems += "Game version mismatch: $($parsed.game_version)"
    }
    if ([string]$parsed.package_sha256 -ne $ExpectedPackageSha256) {
        $problems += "Package SHA-256 mismatch: $($parsed.package_sha256)"
    }
    if ([int]$parsed.result_count -ne 1) {
        $problems += "Expected exactly one Result checkbox, got $($parsed.result_count)"
    }
    if ([int]$parsed.readiness_count -ne 1) {
        $problems += "Expected exactly one Release Readiness Signal checkbox, got $($parsed.readiness_count)"
    }
    if (([bool]$parsed.passed -or [bool]$parsed.playable) -and -not $requiredPathOk) {
        $problems += 'Passed/playable clean-machine report did not check every required path item.'
    }
    if (([bool]$parsed.passed -or [bool]$parsed.playable) -and ([string]::IsNullOrWhiteSpace($parsed.order_name) -or [string]::IsNullOrWhiteSpace($parsed.final_grade) -or [string]::IsNullOrWhiteSpace($parsed.final_score))) {
        $problems += 'Passed/playable report is missing first-order result fields.'
    }

    $reportKey = "$($parsed.package_sha256)|$(ConvertTo-LowerText $parsed.tester)"
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
        $safeTester = ConvertTo-SafeFileName -Name $parsed.tester
        $safeDate = ConvertTo-SafeFileName -Name $parsed.test_date
        $destName = "CLEAN_MACHINE_REPORT_${safeDate}_${safeTester}_$($fileHash.Substring(0, 8)).md"
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
        tester = $parsed.tester
        test_date = $parsed.test_date
        game_version = $parsed.game_version
        package_sha256 = $parsed.package_sha256
        passed = [bool]$parsed.passed
        playable = [bool]$parsed.playable
        blocked = [bool]$parsed.blocked
        recommend = [bool]$parsed.recommend
        wait_for_fixes = [bool]$parsed.wait_for_fixes
        no_publish = [bool]$parsed.no_publish
    }
}

$existingSessionHashes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($existing in @(Get-ChildItem -LiteralPath $sessionsFullPath -Filter 'clean-machine-session-*.json' -File -ErrorAction SilentlyContinue)) {
    [void]$existingSessionHashes.Add((Get-FileHash -Algorithm SHA256 -LiteralPath $existing.FullName).Hash.ToLowerInvariant())
}
$sessions = @()
$acceptedSessions = 0
$rejectedSessions = 0
$skippedDuplicateSessions = 0
foreach ($file in $sessionFiles) {
    $fileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $sessionCheck = Test-SessionJson -Path $file.FullName
    $status = 'accepted'
    $destination = ''
    $problems = @()
    if (-not [bool]$sessionCheck.ok) {
        $status = 'rejected'
        $problems += [string]$sessionCheck.reason
        $rejectedSessions += 1
    }
    elseif ($existingSessionHashes.Contains($fileHash)) {
        $status = 'duplicate'
        $skippedDuplicateSessions += 1
    }
    else {
        $destName = "clean-machine-session-$($fileHash.Substring(0, 8)).json"
        $destPath = Join-Path $sessionsFullPath $destName
        Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
        $destination = $destPath
        [void]$existingSessionHashes.Add($fileHash)
        $acceptedSessions += 1
    }

    $sessions += [ordered]@{
        source = $file.FullName
        destination = $destination
        file_sha256 = $fileHash
        status = $status
        problems = $problems
        size_bytes = [int64]$sessionCheck.size_bytes
    }
}

$returnedReports = @(Get-ChildItem -LiteralPath $reportsFullPath -Filter 'CLEAN_MACHINE_REPORT_*.md' -File -ErrorAction SilentlyContinue | Sort-Object FullName)
$currentPackageReports = 0
$passedCount = 0
$playableCount = 0
$blockedCount = 0
$recommendCount = 0
$waitForFixesCount = 0
$noPublishCount = 0
foreach ($file in $returnedReports) {
    $parsed = Read-CleanMachineReport -Path $file.FullName
    if ([string]$parsed.package_sha256 -ne $ExpectedPackageSha256 -or [string]$parsed.game_version -ne $Version) {
        continue
    }
    $currentPackageReports += 1
    if ([bool]$parsed.passed) { $passedCount += 1 }
    if ([bool]$parsed.playable) { $playableCount += 1 }
    if ([bool]$parsed.blocked) { $blockedCount += 1 }
    if ([bool]$parsed.recommend) { $recommendCount += 1 }
    if ([bool]$parsed.wait_for_fixes) { $waitForFixesCount += 1 }
    if ([bool]$parsed.no_publish) { $noPublishCount += 1 }
}

$decision = 'need_more_reports'
$decisionReason = "Need at least $RequiredReports valid clean-machine report(s) for the current package."
if ($blockedCount -gt 0 -or $noPublishCount -gt 0) {
    $decision = 'no_go'
    $decisionReason = 'At least one clean-machine report is blocked or says not to publish.'
}
elseif ($currentPackageReports -lt $RequiredReports) {
    $decision = 'need_more_reports'
}
elseif ($playableCount -gt 0 -or $waitForFixesCount -gt 0) {
    $decision = 'fix_then_retest'
    $decisionReason = 'Clean-machine path completed with issues or tester requested fixes before widening.'
}
elseif ($passedCount -ge $RequiredReports -and $recommendCount -ge $RequiredReports) {
    $decision = 'go'
    $decisionReason = 'Required clean-machine first-order report(s) passed and recommend widening.'
}
else {
    $decision = 'fix_then_retest'
    $decisionReason = 'Clean-machine report evidence is mixed or does not include enough recommendations.'
}

$ok = ($rejectedReports -eq 0 -and $rejectedSessions -eq 0)
$audit = [ordered]@{
    ok = $ok
    product = 'PC Building Life'
    version = $Version
    input_dir = $inputFullPath
    reports_dir = $reportsFullPath
    sessions_dir = $sessionsFullPath
    expected_package_sha256 = $ExpectedPackageSha256
    required_reports = $RequiredReports
    report_files_seen = $reportFiles.Count
    accepted_reports = $acceptedReports
    skipped_duplicate_reports = $skippedDuplicateReports
    rejected_reports = $rejectedReports
    session_files_seen = $sessionFiles.Count
    accepted_sessions = $acceptedSessions
    skipped_duplicate_sessions = $skippedDuplicateSessions
    rejected_sessions = $rejectedSessions
    decision = $decision
    decision_reason = $decisionReason
    current_package_reports = $currentPackageReports
    passed = $passedCount
    playable_with_issues = $playableCount
    blocked = $blockedCount
    recommend = $recommendCount
    wait_for_fixes = $waitForFixesCount
    no_publish = $noPublishCount
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    reports = $reports
    sessions = $sessions
}

$jsonPath = Join-Path $auditFullPath "clean-machine-report-intake-$Version.json"
$mdPath = Join-Path $auditFullPath "clean-machine-report-intake-$Version.md"
$audit | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdLines = @(
    "# PC Building Life $Version Clean Machine Report Intake",
    "",
    "- Input dir: $inputFullPath",
    "- Reports dir: $reportsFullPath",
    "- Sessions dir: $sessionsFullPath",
    "- Expected package SHA-256: $ExpectedPackageSha256",
    "- Required reports: $RequiredReports",
    "- Report files seen: $($reportFiles.Count)",
    "- Accepted reports: $acceptedReports",
    "- Skipped duplicate reports: $skippedDuplicateReports",
    "- Rejected reports: $rejectedReports",
    "- Accepted sessions: $acceptedSessions",
    "- Rejected sessions: $rejectedSessions",
    "- Current-package reports: $currentPackageReports",
    "- Decision: $decision",
    "- Decision reason: $decisionReason",
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
    "## Sessions",
    "",
    "| Source | Status | Problems |",
    "| --- | --- | --- |"
)
foreach ($session in $sessions) {
    $mdLines += "| $([System.IO.Path]::GetFileName($session.source)) | $($session.status) | $($session.problems -join '; ') |"
}
if ($sessions.Count -eq 0) {
    $mdLines += "| none | none | none |"
}
$mdLines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host '[clean-machine-report-intake] ok'
Write-Host "[clean-machine-report-intake] input=$inputFullPath"
Write-Host "[clean-machine-report-intake] accepted_reports=$acceptedReports rejected_reports=$rejectedReports duplicates=$skippedDuplicateReports"
Write-Host "[clean-machine-report-intake] decision=$decision current_package_reports=$currentPackageReports"
Write-Host "[clean-machine-report-intake] json=$jsonPath"
Write-Host "[clean-machine-report-intake] markdown=$mdPath"

if (-not $ok -and -not $AllowRejected) {
    exit 1
}
