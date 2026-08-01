[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$HandoffZipPath,
    [string]$TempBase,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$handoffRoot = Join-Path $projectDir 'build\publisher-handoff'
$buildDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($HandoffZipPath)) {
    $HandoffZipPath = Join-Path $handoffRoot "PCBuildingLife-$Version-publisher-handoff.zip"
}
if ([string]::IsNullOrWhiteSpace($TempBase)) {
    $TempBase = Join-Path $handoffRoot 'temp'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $handoffRoot "publisher-handoff-audit-$Version.json"
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
    if (-not (Test-Path -LiteralPath $Path) -or [string]::IsNullOrWhiteSpace($ExpectedHash)) {
        return $false
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    return $actual -eq $ExpectedHash.ToLowerInvariant()
}

$handoffZipFullPath = [System.IO.Path]::GetFullPath($HandoffZipPath)
$handoffZipShaPath = "$handoffZipFullPath.sha256"
Assert-File $handoffZipFullPath
$expectedHandoffZipHash = Read-Sha256File -Path $handoffZipShaPath
$actualHandoffZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $handoffZipFullPath).Hash.ToLowerInvariant()
Assert-Condition ($actualHandoffZipHash -eq $expectedHandoffZipHash) "Publisher handoff ZIP SHA-256 mismatch. Expected $expectedHandoffZipHash, got $actualHandoffZipHash."

$tempBaseFullPath = [System.IO.Path]::GetFullPath($TempBase)
New-Item -ItemType Directory -Force -Path $tempBaseFullPath | Out-Null
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBaseFullPath "publisher-handoff-$([Guid]::NewGuid().ToString('N'))"))
Assert-Condition ($tempRoot.StartsWith($tempBaseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $tempRoot"

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $handoffZipFullPath -DestinationPath $tempRoot -Force

    $manifestPath = Join-Path $tempRoot 'publisher-handoff-manifest.json'
    $manifest = Read-JsonFile -Path $manifestPath
    Assert-Condition ([string]$manifest.version -eq $Version) "Manifest version mismatch: $($manifest.version)"
    Assert-Condition ([string]$manifest.package_sha256 -match '^[0-9a-f]{64}$') 'Manifest package_sha256 is invalid.'

    $playerZipPath = Join-Path $tempRoot "package\PCBuildingLife-Windows-x64-$Version.zip"
    $playerShaPath = "$playerZipPath.sha256"
    Assert-Condition (Test-HashMatch -Path $playerZipPath -ExpectedHash (Read-Sha256File -Path $playerShaPath)) 'Player ZIP does not match its SHA-256 file.'
    Assert-Condition ((Read-Sha256File -Path $playerShaPath) -eq [string]$manifest.package_sha256) 'Player package SHA does not match handoff manifest.'

    foreach ($required in @(
        'PUBLISHER_HANDOFF.md',
        'package/release-manifest.json',
        'package/release-package-audit-report.json',
        'channel/upload-bundle/upload-manifest.json',
        'channel/upload-bundle/index.html',
        'channel/itch-staging/itch-upload-manifest.json',
        'channel/itch-staging/butler-command.txt',
        'channel/itch-staging-audit.json',
        "validation-kits/PCBuildingLife-$Version-clean-machine-validation-kit.zip",
        "validation-kits/PCBuildingLife-$Version-clean-machine-validation-kit.zip.sha256",
        "validation-kits/PCBuildingLife-$Version-playtest-kit.zip",
        "validation-kits/PCBuildingLife-$Version-playtest-kit.zip.sha256",
        "validation-kits/PCBuildingLife-$Version-external-validation-round.zip",
        "validation-kits/PCBuildingLife-$Version-external-validation-round.zip.sha256",
        'evidence/release-readiness.json',
        'evidence/release-readiness.md',
        'evidence/publish-environment.json',
        'evidence/public-release-go.json',
        'evidence/public-release-go.md',
        'evidence/external-release-cycle.json',
        'evidence/external-release-cycle.md',
        'evidence/itch-push-failure-audit.json',
        'evidence/clean-machine-report-intake.json',
        'evidence/playtest-report-intake.json',
        'evidence/playtest-feedback-summary.json'
    )) {
        Assert-File (Join-Path $tempRoot $required)
    }

    $docFiles = @(Get-ChildItem -LiteralPath (Join-Path $tempRoot 'docs') -Filter '*.md' -File -ErrorAction SilentlyContinue)
    Assert-Condition ($docFiles.Count -gt 0) 'Publisher handoff contains no markdown docs.'

    $releaseReadiness = Read-JsonFile -Path (Join-Path $tempRoot 'evidence\release-readiness.json')
    $publicReleaseGo = Read-JsonFile -Path (Join-Path $tempRoot 'evidence\public-release-go.json')
    $publishEnv = Read-JsonFile -Path (Join-Path $tempRoot 'evidence\publish-environment.json')
    $externalReleaseCycle = Read-JsonFile -Path (Join-Path $tempRoot 'evidence\external-release-cycle.json')
    $itchPushFailureAudit = Read-JsonFile -Path (Join-Path $tempRoot 'evidence\itch-push-failure-audit.json')
    Assert-Condition ([string]$releaseReadiness.current_package_sha256 -eq [string]$manifest.package_sha256) 'Release readiness package SHA does not match handoff manifest.'
    Assert-Condition ([string]$publicReleaseGo.current_package_sha256 -eq [string]$manifest.package_sha256) 'Public release gate package SHA does not match handoff manifest.'
    Assert-Condition ([string]$publishEnv.current_package_sha256 -eq [string]$manifest.package_sha256) 'Publish environment package SHA does not match handoff manifest.'
    Assert-Condition ([string]$externalReleaseCycle.package_sha256 -eq [string]$manifest.package_sha256) 'External release cycle package SHA does not match handoff manifest.'
    Assert-Condition ([string]$externalReleaseCycle.decision -ne 'cycle_failed') 'Publisher handoff contains a failed external release cycle.'
    Assert-Condition (-not [bool]$externalReleaseCycle.push_requested -or [bool]$externalReleaseCycle.push_performed) 'Publisher handoff contains an incomplete requested channel push.'
    Assert-Condition ([bool]$itchPushFailureAudit.ok -and -not [bool]$itchPushFailureAudit.failure_manifest_pushed) 'itch push failure evidence is invalid.'

    foreach ($artifact in @(
        @{ path = "validation-kits\PCBuildingLife-$Version-clean-machine-validation-kit.zip"; sha = "validation-kits\PCBuildingLife-$Version-clean-machine-validation-kit.zip.sha256"; manifest_sha = [string]$manifest.clean_machine_kit_sha256; name = 'clean-machine kit' },
        @{ path = "validation-kits\PCBuildingLife-$Version-playtest-kit.zip"; sha = "validation-kits\PCBuildingLife-$Version-playtest-kit.zip.sha256"; manifest_sha = [string]$manifest.playtest_kit_sha256; name = 'playtest kit' },
        @{ path = "validation-kits\PCBuildingLife-$Version-external-validation-round.zip"; sha = "validation-kits\PCBuildingLife-$Version-external-validation-round.zip.sha256"; manifest_sha = [string]$manifest.external_round_sha256; name = 'external validation round' }
    )) {
        $artifactPath = Join-Path $tempRoot $artifact.path
        $artifactSha = Read-Sha256File -Path (Join-Path $tempRoot $artifact.sha)
        Assert-Condition ($artifactSha -eq $artifact.manifest_sha) "$($artifact.name) SHA file does not match handoff manifest."
        Assert-Condition (Test-HashMatch -Path $artifactPath -ExpectedHash $artifactSha) "$($artifact.name) ZIP does not match its SHA-256 file."
    }

    $runbook = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $tempRoot 'PUBLISHER_HANDOFF.md')
    foreach ($needle in @(
        'Required External Steps',
        'advance_external_release.ps1',
        '-RequireGo',
        'Do not widen public distribution',
        [string]$manifest.package_sha256
    )) {
        Assert-Condition ($runbook.Contains($needle)) "Publisher runbook is missing expected content: $needle"
    }

    $report = [ordered]@{
        ok = $true
        product = 'PC Building Life'
        version = $Version
        handoff_zip = $handoffZipFullPath
        handoff_zip_sha256 = $actualHandoffZipHash
        package_sha256 = [string]$manifest.package_sha256
        clean_machine_kit_sha256 = [string]$manifest.clean_machine_kit_sha256
        playtest_kit_sha256 = [string]$manifest.playtest_kit_sha256
        external_round_sha256 = [string]$manifest.external_round_sha256
        public_release_gate_decision = [string]$publicReleaseGo.decision
        public_release_gate_fail_count = [int]$publicReleaseGo.fail_count
        external_release_cycle_decision = [string]$externalReleaseCycle.decision
        itch_push_failure_guard = [bool]$itchPushFailureAudit.ok
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

Write-Host '[publisher-handoff-verify] ok'
Write-Host "[publisher-handoff-verify] $handoffZipFullPath"
Write-Host "[publisher-handoff-verify] sha256=$actualHandoffZipHash"
Write-Host "[publisher-handoff-verify] report=$ReportPath"
