[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$RoundZipPath,
    [string]$TempBase,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$externalRoot = Join-Path $projectDir 'build\external-validation'
if ([string]::IsNullOrWhiteSpace($RoundZipPath)) {
    $RoundZipPath = Join-Path $externalRoot "PCBuildingLife-$Version-external-validation-round.zip"
}
if ([string]::IsNullOrWhiteSpace($TempBase)) {
    $TempBase = Join-Path $externalRoot 'temp'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $externalRoot "external-validation-round-audit-$Version.json"
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

function Assert-File {
    param([string]$Path)
    Assert-Condition (Test-Path -LiteralPath $Path) "Required file not found: $Path"
}

function Read-Sha256File {
    param([string]$Path)
    Assert-File $Path
    return ((Get-Content -Raw -Encoding ASCII -LiteralPath $Path) -split '\s+')[0].Trim().ToLowerInvariant()
}

function Read-JsonFile {
    param([string]$Path)
    Assert-File $Path
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Test-HashMatch {
    param(
        [string]$Path,
        [string]$ExpectedHash
    )
    Assert-File $Path
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    return $actual -eq $ExpectedHash.ToLowerInvariant()
}

$roundZipFullPath = [System.IO.Path]::GetFullPath($RoundZipPath)
$roundShaPath = "$roundZipFullPath.sha256"
Assert-File $roundZipFullPath
$expectedRoundHash = Read-Sha256File -Path $roundShaPath
Assert-Condition (Test-HashMatch -Path $roundZipFullPath -ExpectedHash $expectedRoundHash) "Round ZIP SHA-256 mismatch: $roundZipFullPath"

$tempBaseFullPath = [System.IO.Path]::GetFullPath($TempBase)
New-Item -ItemType Directory -Force -Path $tempBaseFullPath | Out-Null
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBaseFullPath "external-round-$([Guid]::NewGuid().ToString('N'))"))
Assert-Condition ($tempRoot.StartsWith($tempBaseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $tempRoot"

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $roundZipFullPath -DestinationPath $tempRoot -Force

    $manifestPath = Join-Path $tempRoot 'external-validation-manifest.json'
    $testerMessagePath = Join-Path $tempRoot 'TESTER_MESSAGE.md'
    $trackerPath = Join-Path $tempRoot 'EXTERNAL_VALIDATION_TRACKER.csv'
    $readmePath = Join-Path $tempRoot 'README_EXTERNAL_VALIDATION.txt'
    $returnedReportsReadmePath = Join-Path $tempRoot 'returned-reports\README_RETURNED_REPORTS.txt'
    $feedbackSummaryPath = Join-Path $tempRoot 'evidence\playtest-feedback-summary.json'
    $playtestKitPath = Join-Path $tempRoot "package\PCBuildingLife-$Version-playtest-kit.zip"
    $playtestKitShaPath = "$playtestKitPath.sha256"

    foreach ($required in @(
        $manifestPath,
        $testerMessagePath,
        $trackerPath,
        $readmePath,
        $returnedReportsReadmePath,
        $feedbackSummaryPath,
        (Join-Path $tempRoot 'evidence\playtest-feedback-summary.md'),
        $playtestKitPath,
        $playtestKitShaPath
    )) {
        Assert-File $required
    }

    $manifest = Read-JsonFile -Path $manifestPath
    $feedbackSummary = Read-JsonFile -Path $feedbackSummaryPath
    Assert-Condition ([string]$manifest.version -eq $Version) "Manifest version mismatch: $($manifest.version)"
    Assert-Condition ([int]$manifest.tester_count -ge 3) "Expected at least 3 testers, got $($manifest.tester_count)."
    Assert-Condition ([string]$manifest.package_sha256 -match '^[0-9a-f]{64}$') 'Manifest package_sha256 is invalid.'
    Assert-Condition ([string]$manifest.playtest_kit_sha256 -match '^[0-9a-f]{64}$') 'Manifest playtest_kit_sha256 is invalid.'
    Assert-Condition ([string]$feedbackSummary.expected_package_sha256 -eq [string]$manifest.package_sha256) 'Feedback summary does not match manifest package SHA-256.'

    $expectedKitHash = Read-Sha256File -Path $playtestKitShaPath
    Assert-Condition ([string]$manifest.playtest_kit_sha256 -eq $expectedKitHash) 'Manifest playtest kit hash does not match kit .sha256.'
    Assert-Condition (Test-HashMatch -Path $playtestKitPath -ExpectedHash $expectedKitHash) 'Playtest kit ZIP does not match its .sha256.'

    $testerMessage = Get-Content -Raw -Encoding UTF8 -LiteralPath $testerMessagePath
    foreach ($needle in @(
        'START_PLAYTEST_KIT.cmd',
        'PLAYTEST_REPORT_*.md',
        'COLLECT_SUPPORT_BUNDLE.cmd',
        [string]$manifest.package_sha256,
        [string]$manifest.playtest_kit_sha256
    )) {
        Assert-Condition ($testerMessage.Contains($needle)) "Tester message is missing expected content: $needle"
    }

    $trackerText = Get-Content -Raw -Encoding UTF8 -LiteralPath $trackerPath
    Assert-Condition ($trackerText.Contains('tester_id,tester_name,status,package_sha256')) 'Tracker header is invalid.'
    $trackerRows = @($trackerText -split "`r?`n" | Where-Object { $_.Trim() -match '^T\d\d,' })
    Assert-Condition ($trackerRows.Count -ge [int]$manifest.tester_count) "Tracker has fewer tester rows than expected: $($trackerRows.Count)."
    foreach ($row in $trackerRows) {
        Assert-Condition ($row.Contains([string]$manifest.package_sha256)) "Tracker row does not contain package SHA-256: $row"
    }

    $report = [ordered]@{
        ok = $true
        version = $Version
        round_zip = $roundZipFullPath
        round_zip_sha256 = $expectedRoundHash
        package_sha256 = [string]$manifest.package_sha256
        playtest_kit_sha256 = [string]$manifest.playtest_kit_sha256
        tester_count = [int]$manifest.tester_count
        tracker_rows = $trackerRows.Count
        feedback_summary_decision = [string]$feedbackSummary.decision
        checked_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $reportDir = Split-Path -Parent $ReportPath
    if (-not [string]::IsNullOrWhiteSpace($reportDir)) {
        New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTempRoot.StartsWith($tempBaseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host '[external-round-verify] ok'
Write-Host "[external-round-verify] $roundZipFullPath"
Write-Host "[external-round-verify] sha256=$expectedRoundHash"
Write-Host "[external-round-verify] report=$ReportPath"
