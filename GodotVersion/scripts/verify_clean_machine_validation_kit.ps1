[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$KitZipPath,
    [string]$TempBase,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validationRoot = Join-Path $projectDir 'build\clean-machine-validation'
if ([string]::IsNullOrWhiteSpace($KitZipPath)) {
    $KitZipPath = Join-Path $validationRoot "PCBuildingLife-$Version-clean-machine-validation-kit.zip"
}
if ([string]::IsNullOrWhiteSpace($TempBase)) {
    $TempBase = Join-Path $validationRoot 'temp'
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $validationRoot "clean-machine-validation-kit-audit-$Version.json"
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

$kitZipFullPath = [System.IO.Path]::GetFullPath($KitZipPath)
$kitShaPath = "$kitZipFullPath.sha256"
Assert-File $kitZipFullPath
$expectedKitHash = Read-Sha256File -Path $kitShaPath
$actualKitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $kitZipFullPath).Hash.ToLowerInvariant()
Assert-Condition ($actualKitHash -eq $expectedKitHash) "Clean-machine kit ZIP SHA-256 mismatch. Expected $expectedKitHash, got $actualKitHash."

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead([System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $kitZipFullPath)))
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @(
        'README_CLEAN_MACHINE_VALIDATION.txt',
        'RUN_CLEAN_MACHINE_VALIDATION.ps1',
        'RUN_CLEAN_MACHINE_VALIDATION.cmd',
        'CLEAN_MACHINE_REPORT_TEMPLATE.md',
        'clean-machine-validation-manifest.json',
        "package/PCBuildingLife-Windows-x64-$Version.zip",
        "package/PCBuildingLife-Windows-x64-$Version.zip.sha256",
        'evidence/release-manifest.json',
        'evidence/release-package-audit-report.json',
        'media/contact-sheet.png'
    )) {
        Assert-Condition ($entryNames -contains $required) "Kit is missing $required."
    }
    $docEntries = @($archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -like 'docs/*.md' })
    Assert-Condition ($docEntries.Count -gt 0) 'Kit has no markdown docs.'

    $manifestText = Read-ZipTextEntry -Archive $archive -EntryName 'clean-machine-validation-manifest.json'
    $manifest = $manifestText | ConvertFrom-Json
    Assert-Condition ([string]$manifest.version -eq $Version) "Manifest version mismatch: $($manifest.version)"
    Assert-Condition ([string]$manifest.package_sha256 -match '^[0-9a-f]{64}$') 'Manifest package_sha256 is invalid.'
    Assert-Condition ([int]$manifest.player_flow_orders -eq 12) 'Manifest player_flow_orders is not 12.'
    Assert-Condition ([int]$manifest.first_order_audit_score -ge 90) 'Manifest first-order score is below S-grade threshold.'

    $runnerText = Read-ZipTextEntry -Archive $archive -EntryName 'RUN_CLEAN_MACHINE_VALIDATION.ps1'
    foreach ($needle in @(
        'Invoke-WebRequest',
        'Package SHA-256 mismatch',
        'Expand-Archive',
        'Start-Process -FilePath $exePath -WorkingDirectory $runDir -PassThru',
        'CLEAN_MACHINE_REPORT_',
        'Get-CimInstance Win32_OperatingSystem',
        'notepad.exe'
    )) {
        Assert-Condition ($runnerText.Contains($needle)) "Runner is missing expected content: $needle"
    }
    Assert-Condition (-not $runnerText.Contains('-WindowStyle Hidden')) 'Runner must not hide the game window.'
    Assert-Condition ($runnerText.Contains([string]$manifest.package_sha256)) 'Runner does not embed the current package hash.'

    $reportTemplateText = Read-ZipTextEntry -Archive $archive -EntryName 'CLEAN_MACHINE_REPORT_TEMPLATE.md'
    foreach ($needle in @(
        'Clean Machine Validation Report',
        'Package SHA-256',
        [string]$manifest.package_sha256,
        'No previous PC Building Life save was used',
        'Continue Game loaded the save',
        'Release Readiness Signal'
    )) {
        Assert-Condition ($reportTemplateText.Contains($needle)) "Report template is missing expected content: $needle"
    }
}
finally {
    $archive.Dispose()
}

$tempBaseFullPath = [System.IO.Path]::GetFullPath($TempBase)
New-Item -ItemType Directory -Force -Path $tempBaseFullPath | Out-Null
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBaseFullPath "clean-machine-kit-$([Guid]::NewGuid().ToString('N'))"))
Assert-Condition ($tempRoot.StartsWith($tempBaseFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $tempRoot"

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $kitZipFullPath -DestinationPath $tempRoot -Force

    $innerPackagePath = Join-Path $tempRoot "package\PCBuildingLife-Windows-x64-$Version.zip"
    $innerShaPath = "$innerPackagePath.sha256"
    Assert-File $innerPackagePath
    Assert-File $innerShaPath
    $innerPackageHash = Read-Sha256File -Path $innerShaPath

    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') `
        -PackagePath $innerPackagePath `
        -Sha256Path $innerShaPath `
        -ReportPath (Join-Path $validationRoot 'clean-machine-validation-inner-package-audit-report.json') `
        -TempBase (Join-Path $validationRoot 'temp')

    $report = [ordered]@{
        ok = $true
        version = $Version
        kit_zip = $kitZipFullPath
        kit_sha256 = $actualKitHash
        package_sha256 = $innerPackageHash
        runner = 'RUN_CLEAN_MACHINE_VALIDATION.ps1'
        report_template = 'CLEAN_MACHINE_REPORT_TEMPLATE.md'
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

Write-Host '[clean-machine-kit-verify] ok'
Write-Host "[clean-machine-kit-verify] $kitZipFullPath"
Write-Host "[clean-machine-kit-verify] kit_sha256=$actualKitHash"
Write-Host "[clean-machine-kit-verify] report=$ReportPath"
