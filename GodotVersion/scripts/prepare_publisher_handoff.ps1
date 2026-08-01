[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$OutputDir,
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
$handoffRoot = Join-Path $projectDir 'build\publisher-handoff'
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $handoffRoot "PCBuildingLife-$Version"
}
$handoffDir = [System.IO.Path]::GetFullPath($OutputDir)
$packageDir = Join-Path $handoffDir 'package'
$channelDir = Join-Path $handoffDir 'channel'
$validationDir = Join-Path $handoffDir 'validation-kits'
$evidenceDir = Join-Path $handoffDir 'evidence'
$docsDir = Join-Path $handoffDir 'docs'

$buildDir = Join-Path $projectDir 'build\windows'
$uploadBundleDir = Join-Path $projectDir "build\upload\PCBuildingLife-$Version"
$itchDir = Join-Path $projectDir "build\itch\PCBuildingLife-$Version"
$cleanMachineRoot = Join-Path $projectDir 'build\clean-machine-validation'
$playtestRoot = Join-Path $projectDir 'build\playtest'
$externalRoot = Join-Path $projectDir 'build\external-validation'
$releaseReadinessRoot = Join-Path $projectDir 'build\release-readiness'
$publishRoot = Join-Path $projectDir 'build\publish'
$publicReleaseGoRoot = Join-Path $projectDir 'build\public-release-go'
$docDir = Join-Path $repoRoot 'doc'

$playerZipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$playerShaPath = "$playerZipPath.sha256"
$releaseManifestPath = Join-Path $buildDir 'release-manifest.json'
$packageAuditPath = Join-Path $buildDir 'release-package-audit-report.json'
$uploadManifestPath = Join-Path $uploadBundleDir 'upload-manifest.json'
$itchManifestPath = Join-Path $itchDir 'itch-upload-manifest.json'
$butlerCommandPath = Join-Path $itchDir 'butler-command.txt'
$itchStagingAuditPath = Join-Path $projectDir "build\itch\itch-staging-audit-$Version.json"
$cleanMachineKitPath = Join-Path $cleanMachineRoot "PCBuildingLife-$Version-clean-machine-validation-kit.zip"
$cleanMachineKitShaPath = "$cleanMachineKitPath.sha256"
$cleanMachineKitAuditPath = Join-Path $cleanMachineRoot "clean-machine-validation-kit-audit-$Version.json"
$cleanMachineReportIntakePath = Join-Path $cleanMachineRoot "report-intake\clean-machine-report-intake-$Version.json"
$playtestKitPath = Join-Path $playtestRoot "PCBuildingLife-$Version-playtest-kit.zip"
$playtestKitShaPath = "$playtestKitPath.sha256"
$playtestReportIntakePath = Join-Path $playtestRoot "report-intake\playtest-report-intake-$Version.json"
$playtestFeedbackSummaryPath = Join-Path $playtestRoot "feedback-summary\playtest-feedback-summary-$Version.json"
$externalRoundPath = Join-Path $externalRoot "PCBuildingLife-$Version-external-validation-round.zip"
$externalRoundShaPath = "$externalRoundPath.sha256"
$externalRoundAuditPath = Join-Path $externalRoot "external-validation-round-audit-$Version.json"
$releaseReadinessJsonPath = Join-Path $releaseReadinessRoot "release-readiness-$Version.json"
$releaseReadinessMdPath = Join-Path $releaseReadinessRoot "release-readiness-$Version.md"
$publishEnvJsonPath = Join-Path $publishRoot "publish-environment-audit-$Version.json"
$publishEnvMdPath = Join-Path $publishRoot "publish-environment-audit-$Version.md"
$publicReleaseGoJsonPath = Join-Path $publicReleaseGoRoot "public-release-go-$Version.json"
$publicReleaseGoMdPath = Join-Path $publicReleaseGoRoot "public-release-go-$Version.md"
$externalReleaseCycleJsonPath = Join-Path $publicReleaseGoRoot "external-release-cycle-$Version.json"
$externalReleaseCycleMdPath = Join-Path $publicReleaseGoRoot "external-release-cycle-$Version.md"
$itchPushFailureAuditPath = Join-Path $projectDir "build\itch\itch-push-failure-audit-$Version.json"
$handoffManifestPath = Join-Path $handoffDir 'publisher-handoff-manifest.json'
$handoffZipPath = Join-Path $handoffRoot "PCBuildingLife-$Version-publisher-handoff.zip"
$handoffZipShaPath = "$handoffZipPath.sha256"

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

function Copy-RequiredFile {
    param(
        [string]$Source,
        [string]$Destination
    )
    Assert-File $Source
    $destinationDir = Split-Path -Parent $Destination
    if (-not [string]::IsNullOrWhiteSpace($destinationDir)) {
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-RequiredDirectory {
    param(
        [string]$Source,
        [string]$Destination
    )
    Assert-Condition (Test-Path -LiteralPath $Source -PathType Container) "Required directory not found: $Source"
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
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

if (-not $SkipValidation) {
    & (Join-Path $PSScriptRoot 'verify_release_readiness.ps1') -Version $Version
    & (Join-Path $PSScriptRoot 'verify_public_release_go.ps1') -Version $Version -AllowNoGo
}

foreach ($required in @(
    $playerZipPath,
    $playerShaPath,
    $releaseManifestPath,
    $packageAuditPath,
    $uploadManifestPath,
    $itchManifestPath,
    $butlerCommandPath,
    $itchStagingAuditPath,
    $cleanMachineKitPath,
    $cleanMachineKitShaPath,
    $cleanMachineKitAuditPath,
    $cleanMachineReportIntakePath,
    $playtestKitPath,
    $playtestKitShaPath,
    $playtestReportIntakePath,
    $playtestFeedbackSummaryPath,
    $externalRoundPath,
    $externalRoundShaPath,
    $externalRoundAuditPath,
    $releaseReadinessJsonPath,
    $releaseReadinessMdPath,
    $publishEnvJsonPath,
    $publishEnvMdPath,
    $publicReleaseGoJsonPath,
    $publicReleaseGoMdPath,
    $externalReleaseCycleJsonPath,
    $externalReleaseCycleMdPath,
    $itchPushFailureAuditPath
)) {
    Assert-File $required
}

$packageHash = Read-Sha256File -Path $playerShaPath
$cleanMachineKitHash = Read-Sha256File -Path $cleanMachineKitShaPath
$playtestKitHash = Read-Sha256File -Path $playtestKitShaPath
$externalRoundHash = Read-Sha256File -Path $externalRoundShaPath
$releaseReadiness = Read-JsonFile -Path $releaseReadinessJsonPath
$publicReleaseGo = Read-JsonFile -Path $publicReleaseGoJsonPath
$publishEnv = Read-JsonFile -Path $publishEnvJsonPath
$externalReleaseCycle = Read-JsonFile -Path $externalReleaseCycleJsonPath
$itchPushFailureAudit = Read-JsonFile -Path $itchPushFailureAuditPath

Assert-Condition ([string]$releaseReadiness.current_package_sha256 -eq $packageHash) 'Release readiness report does not match the current package hash.'
Assert-Condition ([string]$publicReleaseGo.current_package_sha256 -eq $packageHash) 'Public release gate report does not match the current package hash.'
Assert-Condition ([string]$publishEnv.current_package_sha256 -eq $packageHash) 'Publish environment report does not match the current package hash.'
Assert-Condition ([string]$externalReleaseCycle.package_sha256 -eq $packageHash) 'External release cycle report does not match the current package hash.'
Assert-Condition ([string]$externalReleaseCycle.decision -ne 'cycle_failed') 'External release cycle failed; fix it before generating the publisher handoff.'
Assert-Condition (-not [bool]$externalReleaseCycle.push_requested -or [bool]$externalReleaseCycle.push_performed) 'External release cycle requested a push but did not complete it.'
Assert-Condition ([bool]$itchPushFailureAudit.ok -and -not [bool]$itchPushFailureAudit.failure_manifest_pushed) 'itch push failure audit is missing or allowed a false pushed state.'

$resolvedHandoffRoot = [System.IO.Path]::GetFullPath($handoffRoot)
Assert-Condition ($handoffDir.StartsWith($resolvedHandoffRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to clean output outside publisher-handoff root: $handoffDir"
if (Test-Path -LiteralPath $handoffDir) {
    Remove-Item -LiteralPath $handoffDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageDir, $channelDir, $validationDir, $evidenceDir, $docsDir | Out-Null

Copy-RequiredFile -Source $playerZipPath -Destination (Join-Path $packageDir (Split-Path -Leaf $playerZipPath))
Copy-RequiredFile -Source $playerShaPath -Destination (Join-Path $packageDir (Split-Path -Leaf $playerShaPath))
Copy-RequiredFile -Source $releaseManifestPath -Destination (Join-Path $packageDir 'release-manifest.json')
Copy-RequiredFile -Source $packageAuditPath -Destination (Join-Path $packageDir 'release-package-audit-report.json')

Copy-RequiredDirectory -Source $uploadBundleDir -Destination (Join-Path $channelDir 'upload-bundle')
Copy-RequiredDirectory -Source $itchDir -Destination (Join-Path $channelDir 'itch-staging')
Copy-RequiredFile -Source $itchStagingAuditPath -Destination (Join-Path $channelDir 'itch-staging-audit.json')

Copy-RequiredFile -Source $cleanMachineKitPath -Destination (Join-Path $validationDir (Split-Path -Leaf $cleanMachineKitPath))
Copy-RequiredFile -Source $cleanMachineKitShaPath -Destination (Join-Path $validationDir (Split-Path -Leaf $cleanMachineKitShaPath))
Copy-RequiredFile -Source $playtestKitPath -Destination (Join-Path $validationDir (Split-Path -Leaf $playtestKitPath))
Copy-RequiredFile -Source $playtestKitShaPath -Destination (Join-Path $validationDir (Split-Path -Leaf $playtestKitShaPath))
Copy-RequiredFile -Source $externalRoundPath -Destination (Join-Path $validationDir (Split-Path -Leaf $externalRoundPath))
Copy-RequiredFile -Source $externalRoundShaPath -Destination (Join-Path $validationDir (Split-Path -Leaf $externalRoundShaPath))

$evidenceFiles = @(
    @{ source = $releaseReadinessJsonPath; dest = 'release-readiness.json' },
    @{ source = $releaseReadinessMdPath; dest = 'release-readiness.md' },
    @{ source = $publishEnvJsonPath; dest = 'publish-environment.json' },
    @{ source = $publishEnvMdPath; dest = 'publish-environment.md' },
    @{ source = $publicReleaseGoJsonPath; dest = 'public-release-go.json' },
    @{ source = $publicReleaseGoMdPath; dest = 'public-release-go.md' },
    @{ source = $externalReleaseCycleJsonPath; dest = 'external-release-cycle.json' },
    @{ source = $externalReleaseCycleMdPath; dest = 'external-release-cycle.md' },
    @{ source = $itchPushFailureAuditPath; dest = 'itch-push-failure-audit.json' },
    @{ source = $cleanMachineKitAuditPath; dest = 'clean-machine-validation-kit-audit.json' },
    @{ source = $cleanMachineReportIntakePath; dest = 'clean-machine-report-intake.json' },
    @{ source = $playtestReportIntakePath; dest = 'playtest-report-intake.json' },
    @{ source = $playtestFeedbackSummaryPath; dest = 'playtest-feedback-summary.json' },
    @{ source = $externalRoundAuditPath; dest = 'external-validation-round-audit.json' }
)
foreach ($file in $evidenceFiles) {
    Copy-RequiredFile -Source $file.source -Destination (Join-Path $evidenceDir $file.dest)
}

$docSourceFiles = @(Get-ChildItem -LiteralPath $docDir -Filter '*.md' -File | Where-Object {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName
    -not $text.Contains('fixed-validation-commands')
} | Sort-Object Name)
Assert-Condition ($docSourceFiles.Count -gt 0) "No markdown docs found in $docDir"
foreach ($docFile in $docSourceFiles) {
    Copy-RequiredFile -Source $docFile.FullName -Destination (Join-Path $docsDir $docFile.Name)
}

$publisherRunbookLines = @(
    "# PC Building Life $Version Publisher Handoff",
    "",
    "## Current Decision",
    "",
    "- Release readiness: $($releaseReadiness.decision), fails=$($releaseReadiness.fail_count), warnings=$($releaseReadiness.warn_count)",
    "- Public release gate: $($publicReleaseGo.decision), fails=$($publicReleaseGo.fail_count)",
    "- Publish environment: $($publishEnv.decision), fails=$($publishEnv.fail_count), warnings=$($publishEnv.warn_count)",
    "- Player ZIP SHA-256: $packageHash",
    "",
    "## Included Artifacts",
    "",
    "- package/: current Windows player ZIP, SHA-256, release manifest, package audit.",
    "- channel/upload-bundle/: local channel page bundle with package, media, docs, and landing page.",
    "- channel/itch-staging/: itch.io staging folder and butler-command.txt.",
    "- validation-kits/: clean-machine kit, playtest kit, and external validation round ZIPs with .sha256 files.",
    "- evidence/: current JSON/Markdown gate reports.",
    "- docs/: publisher-facing release and validation docs.",
    "",
    "## Required External Steps",
    "",
    "1. Create GodotVersion/release/itch-upload-config.local.json with a real itch_target.",
    "2. Install/login butler, then run the hidden upload and external cycle: powershell -NoProfile -ExecutionPolicy Bypass -File GodotVersion/scripts/advance_external_release.ps1 -Push",
    "3. Add the real public ZIP and SHA-256 URLs to the local config, then rerun advance_external_release.ps1.",
    "4. Run the clean-machine validation kit on another Windows machine/profile and place the returned files in the incoming-reports directory.",
    "5. Send the external validation round to at least 3 testers and place returned playtest files in its incoming-reports directory.",
    "6. Run advance_external_release.ps1 -RequireGo; it processes reports and requires go_public_release.",
    "",
    "## Hard Stop",
    "",
    "Do not widen public distribution until evidence/public-release-go.md says go_public_release."
)
$publisherRunbookLines | Set-Content -LiteralPath (Join-Path $handoffDir 'PUBLISHER_HANDOFF.md') -Encoding UTF8

$manifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    handoff_path = $handoffDir
    package_sha256 = $packageHash
    clean_machine_kit_sha256 = $cleanMachineKitHash
    playtest_kit_sha256 = $playtestKitHash
    external_round_sha256 = $externalRoundHash
    release_readiness_decision = [string]$releaseReadiness.decision
    release_readiness_fail_count = [int]$releaseReadiness.fail_count
    release_readiness_warn_count = [int]$releaseReadiness.warn_count
    publish_environment_decision = [string]$publishEnv.decision
    public_release_gate_decision = [string]$publicReleaseGo.decision
    public_release_gate_fail_count = [int]$publicReleaseGo.fail_count
    external_release_cycle_decision = [string]$externalReleaseCycle.decision
    itch_push_failure_guard = [bool]$itchPushFailureAudit.ok
    included_dirs = @('package', 'channel', 'validation-kits', 'evidence', 'docs')
    doc_files = @($docSourceFiles | ForEach-Object { $_.Name })
    created_at_utc = [DateTime]::UtcNow.ToString('o')
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $handoffManifestPath -Encoding UTF8

$resolvedHandoffZipPath = [System.IO.Path]::GetFullPath($handoffZipPath)
Assert-Condition ($resolvedHandoffZipPath.StartsWith($resolvedHandoffRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to write ZIP outside publisher-handoff root: $resolvedHandoffZipPath"
if (Test-Path -LiteralPath $resolvedHandoffZipPath) {
    Remove-Item -LiteralPath $resolvedHandoffZipPath -Force
}
if (Test-Path -LiteralPath $handoffZipShaPath) {
    Remove-Item -LiteralPath $handoffZipShaPath -Force
}
$handoffItems = @(Get-ChildItem -LiteralPath $handoffDir -Force)
Assert-Condition ($handoffItems.Count -gt 0) "Publisher handoff directory is empty: $handoffDir"
Compress-Archive -Path @($handoffItems | ForEach-Object { $_.FullName }) -DestinationPath $resolvedHandoffZipPath -Force
$handoffZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedHandoffZipPath).Hash.ToLowerInvariant()
("{0}  {1}" -f $handoffZipHash, (Split-Path -Leaf $resolvedHandoffZipPath)) | Set-Content -LiteralPath $handoffZipShaPath -Encoding ASCII

Write-Host '[publisher-handoff] ok'
Write-Host "[publisher-handoff] $handoffDir"
Write-Host "[publisher-handoff] $resolvedHandoffZipPath"
Write-Host "[publisher-handoff] package_sha256=$packageHash"
Write-Host "[publisher-handoff] zip_sha256=$handoffZipHash"
