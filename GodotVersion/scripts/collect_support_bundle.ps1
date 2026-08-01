[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$OutputDir,
    [int]$MaxLogFiles = 3
)

$ErrorActionPreference = 'Stop'

function ConvertTo-SafeFileName {
    param([string]$Name)
    return ($Name -replace '[^\w\-.]', '_')
}

function Add-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = [System.IO.Path]::GetFullPath($scriptDir)
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $scriptDir 'support'
}
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$bundleRoot = Join-Path $OutputDir "PCBuildingLife-support-$stamp"
$logsOut = Join-Path $bundleRoot 'logs'
New-Item -ItemType Directory -Force -Path $bundleRoot, $logsOut | Out-Null

$appDataRoot = Join-Path $env:APPDATA 'Godot\app_userdata\PCBuildingLife Godot'
$manifestCandidates = @(
    (Join-Path $scriptDir 'release-manifest.json'),
    (Join-Path $scriptDir 'package\release-manifest.json'),
    (Join-Path $scriptDir '..\package\release-manifest.json')
)
$releaseManifest = $null
foreach ($candidate in $manifestCandidates) {
    $full = [System.IO.Path]::GetFullPath($candidate)
    $releaseManifest = Read-JsonFile -Path $full
    if ($releaseManifest -ne $null) {
        break
    }
}

$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object {
    [ordered]@{
        name = $_.Name
        driver_version = $_.DriverVersion
        video_mode = $_.VideoModeDescription
    }
})

$systemSummary = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    collected_at_utc = [DateTime]::UtcNow.ToString('o')
    os_caption = $os.Caption
    os_version = $os.Version
    os_architecture = $os.OSArchitecture
    total_memory_gb = [math]::Round([double]$os.TotalVisibleMemorySize / 1MB, 2)
    cpu = $cpu.Name
    gpu = $gpu
    app_userdata_exists = Test-Path -LiteralPath $appDataRoot
    app_userdata_path_hint = '%APPDATA%\Godot\app_userdata\PCBuildingLife Godot'
}
Add-JsonFile -Path (Join-Path $bundleRoot 'system_summary.json') -Value $systemSummary

if ($releaseManifest -ne $null) {
    Add-JsonFile -Path (Join-Path $bundleRoot 'release_manifest_summary.json') -Value $releaseManifest
}

$savePath = Join-Path $appDataRoot 'save_game.json'
$save = Read-JsonFile -Path $savePath
$saveSummary = [ordered]@{
    save_exists = Test-Path -LiteralPath $savePath
    save_path_hint = '%APPDATA%\Godot\app_userdata\PCBuildingLife Godot\save_game.json'
}
if ($save -ne $null) {
    $inventoryCount = 0
    if ($save.inventory -ne $null) {
        $inventoryCount = @($save.inventory).Count
    }
    $installedCount = 0
    if ($save.installed -ne $null) {
        $installedCount = @($save.installed.PSObject.Properties | Where-Object { $null -ne $_.Value -and [string]$_.Value -ne '' }).Count
    }
    $completedCount = 0
    if ($save.completed_order_ids -ne $null) {
        $completedCount = @($save.completed_order_ids).Count
    }
    $saveSummary.version = $save.version
    $saveSummary.money = $save.money
    $saveSummary.inventory_count = $inventoryCount
    $saveSummary.installed_slot_count = $installedCount
    $saveSummary.current_order_index = $save.current_order_index
    $saveSummary.completed_order_count = $completedCount
    $saveSummary.powered_on = $save.powered_on
    $saveSummary.system_booted = $save.system_booted
    $saveSummary.benchmark_completed = $save.benchmark_completed
    $saveSummary.stability_test_completed = $save.stability_test_completed
}
Add-JsonFile -Path (Join-Path $bundleRoot 'save_summary.json') -Value $saveSummary

$settingsPath = Join-Path $appDataRoot 'settings.cfg'
if (Test-Path -LiteralPath $settingsPath) {
    $settingsFile = Get-Item -LiteralPath $settingsPath
    Add-JsonFile -Path (Join-Path $bundleRoot 'settings_file_summary.json') -Value ([ordered]@{
        settings_exists = $true
        size_bytes = $settingsFile.Length
        last_write_time_utc = $settingsFile.LastWriteTimeUtc.ToString('o')
    })
}

$logDir = Join-Path $appDataRoot 'logs'
$copiedLogs = @()
if (Test-Path -LiteralPath $logDir) {
    $logFiles = @(Get-ChildItem -LiteralPath $logDir -Filter '*.log' -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $MaxLogFiles)
    foreach ($logFile in $logFiles) {
        $destName = ConvertTo-SafeFileName -Name $logFile.Name
        $destPath = Join-Path $logsOut $destName
        Copy-Item -LiteralPath $logFile.FullName -Destination $destPath -Force
        $copiedLogs += [ordered]@{
            name = $logFile.Name
            size_bytes = $logFile.Length
            last_write_time_utc = $logFile.LastWriteTimeUtc.ToString('o')
        }
    }
}
Add-JsonFile -Path (Join-Path $bundleRoot 'log_summary.json') -Value ([ordered]@{
    log_dir_exists = Test-Path -LiteralPath $logDir
    copied_log_count = $copiedLogs.Count
    copied_logs = $copiedLogs
})

$readme = @(
    '# PC Building Life Support Bundle',
    '',
    "Created UTC: $([DateTime]::UtcNow.ToString('o'))",
    '',
    'Attach the ZIP next to this folder when filing a GitHub Issue:',
    'https://github.com/bumagh/PCBuildingLife/issues',
    '',
    'Included:',
    '- system_summary.json: Windows, CPU, GPU, memory, and app-data presence.',
    '- release_manifest_summary.json: build/version evidence if a manifest is available.',
    '- save_summary.json: save metadata only. The raw save file is not included.',
    '- settings_file_summary.json: settings file metadata only.',
    '- logs/: recent Godot log files, capped by MaxLogFiles.',
    '',
    'Before sharing, you may open the files and remove anything you consider private.'
)
$readme | Set-Content -LiteralPath (Join-Path $bundleRoot 'README_SUPPORT.md') -Encoding UTF8

$zipPath = "$bundleRoot.zip"
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $bundleRoot '*') -DestinationPath $zipPath -Force
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
("{0}  {1}" -f $zipHash, (Split-Path -Leaf $zipPath)) | Set-Content -LiteralPath "$zipPath.sha256" -Encoding ASCII

Write-Host '[support-bundle] ok'
Write-Host "[support-bundle] folder=$bundleRoot"
Write-Host "[support-bundle] zip=$zipPath"
Write-Host "[support-bundle] sha256=$zipHash"
