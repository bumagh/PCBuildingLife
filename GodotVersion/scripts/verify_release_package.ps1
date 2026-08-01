[CmdletBinding()]
param(
    [string]$PackagePath,
    [string]$Sha256Path,
    [string]$ExpectedIssuesUrl = 'https://github.com/bumagh/PCBuildingLife/issues',
    [int]$SmokeSeconds = 4,
    [string]$ReportPath,
    [string]$TempBase
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$defaultOutputDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $PackagePath = Join-Path $defaultOutputDir 'PCBuildingLife-Windows-x64-0.1.0-dev.zip'
}
if ([string]::IsNullOrWhiteSpace($Sha256Path)) {
    $Sha256Path = "$PackagePath.sha256"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $defaultOutputDir 'release-package-audit-report.json'
}
if ([string]::IsNullOrWhiteSpace($TempBase)) {
    $TempBase = Join-Path $projectDir 'build\temp'
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

function Read-ZipTextEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$EntryName
    )

    $entry = $Archive.GetEntry($EntryName)
    Assert-Condition ($null -ne $entry) "Package is missing $EntryName."
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

function Compare-StringSet {
    param(
        [string[]]$Actual,
        [string[]]$Expected,
        [string]$Label
    )

    $actualSorted = @($Actual | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    $actualJoined = $actualSorted -join '|'
    $expectedJoined = $expectedSorted -join '|'
    Assert-Condition ($actualJoined -eq $expectedJoined) "$Label mismatch. Expected: $expectedJoined; Actual: $actualJoined"
}

$packageFullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PackagePath))
$shaFullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Sha256Path))
$reportFullPath = [System.IO.Path]::GetFullPath($ReportPath)
$reportDir = Split-Path -Parent $reportFullPath
if (-not [string]::IsNullOrWhiteSpace($reportDir)) {
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
}

Write-Host "[package-audit] Package: $packageFullPath"
Write-Host "[package-audit] SHA256 file: $shaFullPath"

$expectedZipHash = ((Get-Content -Raw -Encoding ASCII -LiteralPath $shaFullPath) -split '\s+')[0].Trim().ToLowerInvariant()
Assert-Condition ($expectedZipHash -match '^[0-9a-f]{64}$') "Invalid sha256 file content: $expectedZipHash"
$actualZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $packageFullPath).Hash.ToLowerInvariant()
Assert-Condition ($actualZipHash -eq $expectedZipHash) "Package SHA-256 mismatch. Expected $expectedZipHash, got $actualZipHash."

$expectedFiles = @(
    'PCBuildingLife.exe',
    'release-manifest.json',
    'README.txt',
    'RELEASE_NOTES.md',
    'COLLECT_SUPPORT_BUNDLE.ps1',
    'COLLECT_SUPPORT_BUNDLE.cmd'
)
$forbiddenPatterns = @(
    'scripts/',
    'scripts\',
    'verify_',
    'release_player_flow',
    'release_first_order_audit',
    'mcp',
    'build_release',
    'pc_creator2',
    'release/media',
    'item-icons-sheet'
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($packageFullPath)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
    Compare-StringSet -Actual $entryNames -Expected $expectedFiles -Label 'ZIP entries'

    foreach ($name in $entryNames) {
        $lowerName = $name.ToLowerInvariant()
        foreach ($pattern in $forbiddenPatterns) {
            Assert-Condition (-not $lowerName.Contains($pattern.ToLowerInvariant())) "Forbidden package entry detected: $name"
        }
    }

    $manifestText = Read-ZipTextEntry -Archive $archive -EntryName 'release-manifest.json'
    $manifest = $manifestText | ConvertFrom-Json
    Compare-StringSet -Actual ([string[]]$manifest.package_files) -Expected $expectedFiles -Label 'manifest package_files'

    Assert-Condition ($manifest.tests -eq 'passed') 'Manifest tests gate is not passed.'
    Assert-Condition ($manifest.launch_smoke -eq 'passed') 'Manifest launch_smoke gate is not passed.'
    Assert-Condition ($manifest.clean_extract_smoke -eq 'passed') 'Manifest clean_extract_smoke gate is not passed.'
    Assert-Condition ($manifest.public_release_guard -eq 'passed') 'Manifest public_release_guard gate is not passed.'
    Assert-Condition ($manifest.public_first_order_guard -eq 'passed') 'Manifest public_first_order_guard gate is not passed.'
    Assert-Condition ($manifest.player_flow -eq 'passed') 'Manifest player_flow gate is not passed.'
    Assert-Condition ([int]$manifest.player_flow_orders -eq 12) 'Manifest player_flow_orders is not 12.'
    Assert-Condition ($manifest.first_order_audit -eq 'passed') 'Manifest first_order_audit gate is not passed.'
    Assert-Condition ([int]$manifest.first_order_audit_orders -eq 1) 'Manifest first_order_audit_orders is not 1.'
    Assert-Condition ([int]$manifest.first_order_audit_saves -eq 1) 'Manifest first_order_audit_saves is not 1.'
    Assert-Condition ([int]$manifest.first_order_audit_loads -eq 1) 'Manifest first_order_audit_loads is not 1.'

    $readme = Read-ZipTextEntry -Archive $archive -EntryName 'README.txt'
    $releaseNotes = Read-ZipTextEntry -Archive $archive -EntryName 'RELEASE_NOTES.md'
    $supportScript = Read-ZipTextEntry -Archive $archive -EntryName 'COLLECT_SUPPORT_BUNDLE.ps1'
    Assert-Condition ($readme.Contains($ExpectedIssuesUrl)) 'README.txt does not include the expected feedback URL.'
    Assert-Condition ($releaseNotes.Contains($ExpectedIssuesUrl)) 'RELEASE_NOTES.md does not include the expected feedback URL.'
    foreach ($needle in @(
        'save_summary.json',
        'log_summary.json',
        'system_summary.json',
        'The raw save file is not included',
        'MaxLogFiles'
    )) {
        Assert-Condition ($supportScript.Contains($needle)) "Support bundle script is missing expected content: $needle"
    }
    Assert-Condition (-not $supportScript.Contains('Copy-Item -LiteralPath $savePath')) 'Support bundle must not copy the raw save file.'
}
finally {
    $archive.Dispose()
}

$tempBase = [System.IO.Path]::GetFullPath($TempBase)
New-Item -ItemType Directory -Force -Path $tempBase | Out-Null
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBase "PCBuildingLife-package-audit-$([Guid]::NewGuid().ToString('N'))"))
Assert-Condition ($tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $tempRoot"

$process = $null
try {
    $downloadDir = Join-Path $tempRoot 'download'
    $extractDir = Join-Path $tempRoot 'extract'
    New-Item -ItemType Directory -Force -Path $downloadDir, $extractDir | Out-Null

    $downloadedPackagePath = Join-Path $downloadDir (Split-Path -Leaf $packageFullPath)
    $downloadedShaPath = Join-Path $downloadDir (Split-Path -Leaf $shaFullPath)
    Copy-Item -LiteralPath $packageFullPath -Destination $downloadedPackagePath -Force
    Copy-Item -LiteralPath $shaFullPath -Destination $downloadedShaPath -Force

    $downloadedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $downloadedPackagePath).Hash.ToLowerInvariant()
    Assert-Condition ($downloadedHash -eq $expectedZipHash) "Downloaded package copy SHA-256 mismatch. Expected $expectedZipHash, got $downloadedHash."

    Expand-Archive -LiteralPath $downloadedPackagePath -DestinationPath $extractDir -Force
    $extractedExePath = Join-Path $extractDir 'PCBuildingLife.exe'
    Assert-Condition (Test-Path -LiteralPath $extractedExePath) "Extracted package is missing PCBuildingLife.exe."

    $extractedExe = Get-Item -LiteralPath $extractedExePath
    $extractedExeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $extractedExePath).Hash.ToLowerInvariant()
    Assert-Condition ($extractedExe.Length -eq [int64]$manifest.size_bytes) "Extracted EXE size mismatch. Expected $($manifest.size_bytes), got $($extractedExe.Length)."
    Assert-Condition ($extractedExeHash -eq [string]$manifest.sha256) "Extracted EXE SHA-256 mismatch. Expected $($manifest.sha256), got $extractedExeHash."

    Write-Host "[package-audit] Launching extracted EXE for $SmokeSeconds seconds"
    $process = Start-Process `
        -FilePath $extractedExePath `
        -WorkingDirectory $extractDir `
        -PassThru `
        -WindowStyle Hidden
    Start-Sleep -Seconds $SmokeSeconds
    Assert-Condition (-not $process.HasExited) "Extracted game exited during package smoke with code $($process.ExitCode)."
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$report = [ordered]@{
    ok = $true
    package = $packageFullPath
    package_sha256 = $actualZipHash
    package_size_bytes = (Get-Item -LiteralPath $packageFullPath).Length
    package_files = $expectedFiles
    exe_sha256 = [string]$manifest.sha256
    exe_size_bytes = [int64]$manifest.size_bytes
    tests = [string]$manifest.tests
    launch_smoke = [string]$manifest.launch_smoke
    clean_extract_smoke = [string]$manifest.clean_extract_smoke
    public_release_guard = [string]$manifest.public_release_guard
    public_first_order_guard = [string]$manifest.public_first_order_guard
    player_flow_orders = [int]$manifest.player_flow_orders
    first_order_audit_order_name = [string]$manifest.first_order_audit_order_name
    first_order_audit_score = [int]$manifest.first_order_audit_score
    first_order_audit_grade = [string]$manifest.first_order_audit_grade
    feedback_url = $ExpectedIssuesUrl
    smoke_seconds = $SmokeSeconds
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
}
$report | ConvertTo-Json | Set-Content -LiteralPath $reportFullPath -Encoding UTF8

Write-Host '[package-audit] ok'
Write-Host "[package-audit] report: $reportFullPath"
