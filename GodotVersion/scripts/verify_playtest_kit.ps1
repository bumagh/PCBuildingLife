[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$KitZipPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$playtestRoot = Join-Path $projectDir 'build\playtest'
if ([string]::IsNullOrWhiteSpace($KitZipPath)) {
    $KitZipPath = Join-Path $playtestRoot "PCBuildingLife-$Version-playtest-kit.zip"
}
$shaPath = "$KitZipPath.sha256"
$reportPath = Join-Path $playtestRoot 'playtest-kit-package-audit-report.json'

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Read-ZipTextEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName
    )

    $entry = $Archive.GetEntry($EntryName)
    Assert-Condition ($null -ne $entry) "Kit is missing $EntryName."
    $stream = $entry.Open()
    try {
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

Assert-Condition (Test-Path -LiteralPath $KitZipPath) "Kit ZIP not found: $KitZipPath"
Assert-Condition (Test-Path -LiteralPath $shaPath) "Kit SHA file not found: $shaPath"

$expectedKitHash = ((Get-Content -Raw -Encoding ASCII -LiteralPath $shaPath) -split '\s+')[0].Trim().ToLowerInvariant()
$actualKitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $KitZipPath).Hash.ToLowerInvariant()
Assert-Condition ($actualKitHash -eq $expectedKitHash) "Kit ZIP SHA-256 mismatch. Expected $expectedKitHash, got $actualKitHash."

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead([System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $KitZipPath)))
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @(
        'README_PLAYTEST.txt',
        'START_PLAYTEST_KIT.ps1',
        'START_PLAYTEST_KIT.cmd',
        'COLLECT_SUPPORT_BUNDLE.ps1',
        'COLLECT_SUPPORT_BUNDLE.cmd',
        'TEST_REPORT_TEMPLATE.md',
        'playtest-kit-manifest.json',
        "package/PCBuildingLife-Windows-x64-$Version.zip",
        "package/PCBuildingLife-Windows-x64-$Version.zip.sha256",
        'package/release-manifest.json',
        'package/release-package-audit-report.json',
        'media/cover-1920x1080.png',
        'media/contact-sheet.png'
    )) {
        Assert-Condition ($entryNames -contains $required) "Kit is missing $required."
    }

    $manifestText = Read-ZipTextEntry -Archive $archive -EntryName 'playtest-kit-manifest.json'
    $manifest = $manifestText | ConvertFrom-Json
    Assert-Condition ($manifest.package_sha256 -match '^[0-9a-f]{64}$') 'Manifest package_sha256 is invalid.'
    Assert-Condition ([int]$manifest.player_flow_orders -eq 12) 'Manifest player_flow_orders is not 12.'
    Assert-Condition ([int]$manifest.first_order_audit_score -ge 90) 'Manifest first_order_audit_score is lower than expected.'
    $docEntries = @($archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -like 'docs/*.md' })
    Assert-Condition ($docEntries.Count -gt 0) 'Kit has no markdown docs.'
    $hasFeedbackSummary = $false
    foreach ($docEntry in $docEntries) {
        $docText = Read-ZipTextEntry -Archive $archive -EntryName $docEntry.FullName
        Assert-Condition (-not $docText.Contains('fixed-validation-commands')) 'Kit includes internal roadmap validation docs.'
        if ($docText.Contains('PCBL_PLAYTEST_FEEDBACK_SUMMARY_V1')) {
            $hasFeedbackSummary = $true
        }
    }
    Assert-Condition $hasFeedbackSummary 'Kit is missing external playtest feedback summary template.'

    $launcherText = Read-ZipTextEntry -Archive $archive -EntryName 'START_PLAYTEST_KIT.ps1'
    foreach ($needle in @(
        'PLAYTEST_SESSION_',
        'PLAYTEST_REPORT_',
        'Get-CimInstance Win32_OperatingSystem',
        'Package SHA-256 mismatch',
        'Start-Process -FilePath $exePath -WorkingDirectory $tempRoot -PassThru',
        'notepad.exe'
    )) {
        Assert-Condition ($launcherText.Contains($needle)) "Launcher script is missing expected content: $needle"
    }
    Assert-Condition (-not $launcherText.Contains('-WindowStyle Hidden')) 'Launcher must not hide the interactive game window.'

    $supportText = Read-ZipTextEntry -Archive $archive -EntryName 'COLLECT_SUPPORT_BUNDLE.ps1'
    foreach ($needle in @(
        'save_summary.json',
        'log_summary.json',
        'system_summary.json',
        'The raw save file is not included',
        'MaxLogFiles'
    )) {
        Assert-Condition ($supportText.Contains($needle)) "Support bundle script is missing expected content: $needle"
    }
    Assert-Condition (-not $supportText.Contains('Copy-Item -LiteralPath $savePath')) 'Support bundle must not copy the raw save file.'

    $reportTemplateText = Read-ZipTextEntry -Archive $archive -EntryName 'TEST_REPORT_TEMPLATE.md'
    foreach ($needle in @(
        'Release Readiness Signal',
        'Package SHA-256',
        $manifest.package_sha256,
        'recommend this build',
        'blocking issue'
    )) {
        Assert-Condition ($reportTemplateText.Contains($needle)) "Report template is missing expected content: $needle"
    }
}
finally {
    $archive.Dispose()
}

$tempBase = [System.IO.Path]::GetFullPath((Join-Path $playtestRoot 'temp'))
New-Item -ItemType Directory -Force -Path $tempBase | Out-Null
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBase "PCBuildingLife-playtest-kit-$([Guid]::NewGuid().ToString('N'))"))
Assert-Condition ($tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $tempRoot"

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $KitZipPath -DestinationPath $tempRoot -Force

    $innerPackagePath = Join-Path $tempRoot "package\PCBuildingLife-Windows-x64-$Version.zip"
    $innerShaPath = "$innerPackagePath.sha256"
    Assert-Condition (Test-Path -LiteralPath $innerPackagePath) "Extracted kit is missing inner package: $innerPackagePath"
    Assert-Condition (Test-Path -LiteralPath $innerShaPath) "Extracted kit is missing inner package SHA file: $innerShaPath"

    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') `
        -PackagePath $innerPackagePath `
        -Sha256Path $innerShaPath `
        -ReportPath $reportPath `
        -TempBase (Join-Path $playtestRoot 'temp')
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host '[playtest-kit-verify] ok'
Write-Host "[playtest-kit-verify] $KitZipPath"
Write-Host "[playtest-kit-verify] sha256=$actualKitHash"
Write-Host "[playtest-kit-verify] package_audit=$reportPath"
