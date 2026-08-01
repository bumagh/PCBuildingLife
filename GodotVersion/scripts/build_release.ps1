[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\1exe\3Dev\1GameEngine\Godot_v4.7-rc3_win64\Godot_v4.7-rc3_win64_console.exe',
    [string]$Version = '0.1.0-dev',
    [switch]$SkipTests,
    [switch]$SkipLaunchSmoke,
    [switch]$SkipCleanExtractSmoke,
    [switch]$SkipFirstOrderAudit,
    [switch]$SkipPlayerFlow
)

$ErrorActionPreference = 'Stop'
$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildDir = Join-Path $projectDir 'build'
$tmpDir = Join-Path $projectDir 'tmp'
$outputDir = Join-Path $projectDir 'build\windows'
$exePath = Join-Path $outputDir 'PCBuildingLife.exe'
$playerFlowExePath = Join-Path $outputDir 'PCBuildingLife-player-flow.exe'
$firstOrderAuditExePath = Join-Path $outputDir 'PCBuildingLife-first-order-audit.exe'
$zipPath = Join-Path $outputDir "PCBuildingLife-Windows-x64-$Version.zip"
$zipSha256Path = "$zipPath.sha256"
$manifestPath = Join-Path $outputDir 'release-manifest.json'
$releaseReadmeSourcePath = Join-Path $projectDir 'release\README.txt'
$releaseNotesSourcePath = Join-Path $projectDir 'release\RELEASE_NOTES.md'
$supportBundleSourcePath = Join-Path $projectDir 'scripts\collect_support_bundle.ps1'
$referenceAssetBoundaryVerifierPath = Join-Path $projectDir 'scripts\verify_reference_asset_boundary.ps1'
$releaseReadmePath = Join-Path $outputDir 'README.txt'
$releaseNotesPath = Join-Path $outputDir 'RELEASE_NOTES.md'
$supportBundlePs1Path = Join-Path $outputDir 'COLLECT_SUPPORT_BUNDLE.ps1'
$supportBundleCmdPath = Join-Path $outputDir 'COLLECT_SUPPORT_BUNDLE.cmd'
$playerFlowReportPath = Join-Path $outputDir 'release-player-flow-report.json'
$playerFlowStdoutPath = Join-Path $outputDir 'release-player-flow.stdout.log'
$playerFlowStderrPath = Join-Path $outputDir 'release-player-flow.stderr.log'
$firstOrderAuditReportPath = Join-Path $outputDir 'first-order-audit-report.json'
$firstOrderAuditStdoutPath = Join-Path $outputDir 'first-order-audit.stdout.log'
$firstOrderAuditStderrPath = Join-Path $outputDir 'first-order-audit.stderr.log'
$publicGuardReportPath = Join-Path $outputDir 'public-release-guard-report.json'
$publicGuardStdoutPath = Join-Path $outputDir 'public-release-guard.stdout.log'
$publicGuardStderrPath = Join-Path $outputDir 'public-release-guard.stderr.log'
$publicFirstOrderGuardReportPath = Join-Path $outputDir 'public-first-order-guard-report.json'
$publicFirstOrderGuardStdoutPath = Join-Path $outputDir 'public-first-order-guard.stdout.log'
$publicFirstOrderGuardStderrPath = Join-Path $outputDir 'public-first-order-guard.stderr.log'
$projectSettingsPath = Join-Path $projectDir 'project.godot'
$projectSettingsBackupPath = Join-Path $outputDir 'project.godot.release-backup'

function Ensure-GodotScanGuards {
    foreach ($directory in @($buildDir, $tmpDir)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $guardPath = Join-Path $directory '.gdignore'
        if (Test-Path -LiteralPath $guardPath -PathType Container) {
            throw "Godot scan guard must be a file, not a directory: $guardPath"
        }
        if (-not (Test-Path -LiteralPath $guardPath -PathType Leaf)) {
            New-Item -ItemType File -Path $guardPath -Force | Out-Null
            Write-Host "[release] Created Godot scan guard: $guardPath"
        }
    }
}

function Invoke-Godot {
    param([string[]]$Arguments)

    & $GodotPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Godot command failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')"
    }
}

function Disable-ReleaseMcp {
    if (-not (Test-Path -LiteralPath $projectSettingsPath)) {
        throw "Project settings not found: $projectSettingsPath"
    }
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    Copy-Item -LiteralPath $projectSettingsPath -Destination $projectSettingsBackupPath -Force
    $lines = Get-Content -LiteralPath $projectSettingsPath
    $filtered = $lines | Where-Object {
        $_ -notmatch '^MCP(Runtime|Input|Screenshot)Bridge=' -and
        $_ -notmatch '^enabled=PackedStringArray\("res://addons/godot_mcp/plugin.cfg"\)$'
    }
    Set-Content -LiteralPath $projectSettingsPath -Value $filtered -Encoding UTF8
}

function Restore-ReleaseMcp {
    if (Test-Path -LiteralPath $projectSettingsBackupPath) {
        Copy-Item -LiteralPath $projectSettingsBackupPath -Destination $projectSettingsPath -Force
        Remove-Item -LiteralPath $projectSettingsBackupPath -Force
    }
}

function Copy-ReleaseDocs {
    foreach ($source in @($releaseReadmeSourcePath, $releaseNotesSourcePath)) {
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Release document not found: $source"
        }
    }
    Copy-Item -LiteralPath $releaseReadmeSourcePath -Destination $releaseReadmePath -Force
    Copy-Item -LiteralPath $releaseNotesSourcePath -Destination $releaseNotesPath -Force
}

function Copy-SupportBundleTools {
    if (-not (Test-Path -LiteralPath $supportBundleSourcePath)) {
        throw "Support bundle script not found: $supportBundleSourcePath"
    }
    Copy-Item -LiteralPath $supportBundleSourcePath -Destination $supportBundlePs1Path -Force
    @(
        '@echo off',
        'setlocal',
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0COLLECT_SUPPORT_BUNDLE.ps1"',
        'pause',
        'endlocal'
    ) | Set-Content -LiteralPath $supportBundleCmdPath -Encoding ASCII
}

function Invoke-ExportedPlayerFlow {
    param(
        [string]$ExecutablePath,
        [string]$ReportPath,
        [string]$StdoutPath,
        [string]$StderrPath
    )

    Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrPath -Force -ErrorAction SilentlyContinue

    $arguments = @(
        '--headless',
        '--',
        '--pcbl-release-flow',
        '--pcbl-flow-report',
        $ReportPath
    )
    $process = Start-Process `
        -FilePath $ExecutablePath `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath

    if (-not $process.WaitForExit(90000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "Exported player flow timed out after 90 seconds."
    }
    $process.Refresh()
    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        $stdout = if (Test-Path -LiteralPath $StdoutPath) { Get-Content -Raw -LiteralPath $StdoutPath } else { '' }
        $stderr = if (Test-Path -LiteralPath $StderrPath) { Get-Content -Raw -LiteralPath $StderrPath } else { '' }
        throw "Exported player flow failed with exit code $($process.ExitCode).`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
    }
    if (-not (Test-Path -LiteralPath $ReportPath)) {
        throw "Exported player flow did not create report: $ReportPath"
    }
    $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $ReportPath | ConvertFrom-Json
    if (-not [bool]$report.ok) {
        throw "Exported player flow report failed: $($report.message)"
    }
    return $report
}

function Invoke-FirstOrderAudit {
    param(
        [string]$ExecutablePath,
        [string]$ReportPath,
        [string]$StdoutPath,
        [string]$StderrPath
    )

    Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrPath -Force -ErrorAction SilentlyContinue

    $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBase "PCBuildingLife-first-order-audit-$([Guid]::NewGuid().ToString('N'))"))
    if (-not $tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to create first-order audit temp folder outside temp base: $tempRoot"
    }

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $auditExePath = Join-Path $tempRoot (Split-Path -Leaf $ExecutablePath)
        Copy-Item -LiteralPath $ExecutablePath -Destination $auditExePath -Force
        $arguments = @(
            '--headless',
            '--',
            '--pcbl-first-order-audit',
            '--pcbl-first-order-report',
            $ReportPath
        )
        $process = Start-Process `
            -FilePath $auditExePath `
            -WorkingDirectory $tempRoot `
            -ArgumentList $arguments `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $StdoutPath `
            -RedirectStandardError $StderrPath

        if (-not $process.WaitForExit(60000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            throw "First-order audit timed out after 60 seconds."
        }
        $process.Refresh()
        if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
            $stdout = if (Test-Path -LiteralPath $StdoutPath) { Get-Content -Raw -LiteralPath $StdoutPath } else { '' }
            $stderr = if (Test-Path -LiteralPath $StderrPath) { Get-Content -Raw -LiteralPath $StderrPath } else { '' }
            throw "First-order audit failed with exit code $($process.ExitCode).`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
        }
        if (-not (Test-Path -LiteralPath $ReportPath)) {
            throw "First-order audit did not create report: $ReportPath"
        }
        $report = Get-Content -Raw -Encoding UTF8 -LiteralPath $ReportPath | ConvertFrom-Json
        if (-not [bool]$report.ok) {
            throw "First-order audit report failed: $($report.message)"
        }
        return $report
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
            if ($resolvedTempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Invoke-PublicReleaseGuard {
    param(
        [string]$ExecutablePath,
        [string]$ReportPath,
        [string]$StdoutPath,
        [string]$StderrPath
    )

    Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrPath -Force -ErrorAction SilentlyContinue

    $arguments = @(
        '--headless',
        '--',
        '--pcbl-release-flow',
        '--pcbl-flow-report',
        $ReportPath
    )
    $process = Start-Process `
        -FilePath $ExecutablePath `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath

    if (-not $process.WaitForExit(12000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
    else {
        $process.Refresh()
        if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
            $stdout = if (Test-Path -LiteralPath $StdoutPath) { Get-Content -Raw -LiteralPath $StdoutPath } else { '' }
            $stderr = if (Test-Path -LiteralPath $StderrPath) { Get-Content -Raw -LiteralPath $StderrPath } else { '' }
            throw "Public release guard run exited with code $($process.ExitCode).`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
        }
    }
    if (Test-Path -LiteralPath $ReportPath) {
        throw "Public release unexpectedly exposed the player-flow automation entrypoint: $ReportPath"
    }
}

function Invoke-PublicFirstOrderGuard {
    param(
        [string]$ExecutablePath,
        [string]$ReportPath,
        [string]$StdoutPath,
        [string]$StderrPath
    )

    Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrPath -Force -ErrorAction SilentlyContinue

    $arguments = @(
        '--headless',
        '--',
        '--pcbl-first-order-audit',
        '--pcbl-first-order-report',
        $ReportPath
    )
    $process = Start-Process `
        -FilePath $ExecutablePath `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath

    if (-not $process.WaitForExit(12000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
    else {
        $process.Refresh()
        if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
            $stdout = if (Test-Path -LiteralPath $StdoutPath) { Get-Content -Raw -LiteralPath $StdoutPath } else { '' }
            $stderr = if (Test-Path -LiteralPath $StderrPath) { Get-Content -Raw -LiteralPath $StderrPath } else { '' }
            throw "Public first-order guard run exited with code $($process.ExitCode).`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
        }
    }
    if (Test-Path -LiteralPath $ReportPath) {
        throw "Public release unexpectedly exposed the first-order audit entrypoint: $ReportPath"
    }
}

function Invoke-CleanExtractSmoke {
    param(
        [string]$PackagePath,
        [string]$ExecutableName
    )

    if (-not (Test-Path -LiteralPath $PackagePath)) {
        throw "Release package not found: $PackagePath"
    }

    $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempBase "PCBuildingLife-clean-extract-$([Guid]::NewGuid().ToString('N'))"))
    if (-not $tempRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to create clean-extract temp folder outside temp base: $tempRoot"
    }

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $process = $null
    try {
        Expand-Archive -LiteralPath $PackagePath -DestinationPath $tempRoot -Force
        $extractedExePath = Join-Path $tempRoot $ExecutableName
        if (-not (Test-Path -LiteralPath $extractedExePath)) {
            throw "Extracted package is missing executable: $extractedExePath"
        }

        $process = Start-Process `
            -FilePath $extractedExePath `
            -WorkingDirectory $tempRoot `
            -PassThru `
            -WindowStyle Hidden
        Start-Sleep -Seconds 4
        if ($process.HasExited) {
            throw "Extracted game exited during clean-extract smoke with code $($process.ExitCode)."
        }
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
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot console executable not found: $GodotPath"
}

Ensure-GodotScanGuards

if (-not (Test-Path -LiteralPath $referenceAssetBoundaryVerifierPath -PathType Leaf)) {
    throw "Reference asset boundary verifier not found: $referenceAssetBoundaryVerifierPath"
}
Write-Host '[release] Verifying competitor reference asset boundary'
& $referenceAssetBoundaryVerifierPath -GodotProjectDir $projectDir

Write-Host "[release] Importing project"
Invoke-Godot @('--path', $projectDir, '--import', '--quit-after', '2')

if (-not $SkipTests) {
    $tests = @(
        'verify_data.gd',
        'verify_gameplay.gd',
        'verify_save_load.gd',
        'verify_save_migration.gd',
        'verify_release_stability.gd',
        'verify_orders.gd',
        'verify_order_desk.gd',
        'verify_compatibility.gd',
        'verify_shop_filters.gd',
        'verify_catalog_layout.gd',
        'verify_catalog_overlay.gd',
        'verify_task_center_overlay.gd',
        'verify_system_center_overlay.gd',
        'verify_onboarding_flow.gd',
        'verify_guided_onboarding.gd',
        'verify_content_progression.gd',
        'verify_order_software_tasks.gd',
        'verify_extended_flow.gd',
        'verify_cheat_tools.gd',
        'verify_workbench_overlay.gd',
        'verify_monitor_os.gd',
        'verify_software_delivery.gd',
        'verify_feedback.gd',
        'verify_action_feedback.gd',
        'verify_key_animations.gd',
        'verify_main_menu.gd',
        'verify_pause_menu.gd',
        'verify_save_recovery.gd'
    )

    foreach ($test in $tests) {
        Write-Host "[release] Test $test"
        Invoke-Godot @('--headless', '--path', $projectDir, '-s', "res://scripts/$test")
    }
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Remove-Item -LiteralPath $exePath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $playerFlowExePath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $firstOrderAuditExePath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zipSha256Path -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $releaseReadmePath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $releaseNotesPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $supportBundlePs1Path -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $supportBundleCmdPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $playerFlowReportPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $playerFlowStdoutPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $playerFlowStderrPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $firstOrderAuditReportPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $firstOrderAuditStdoutPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $firstOrderAuditStderrPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $publicGuardReportPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $publicGuardStdoutPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $publicGuardStderrPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $publicFirstOrderGuardReportPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $publicFirstOrderGuardStdoutPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $publicFirstOrderGuardStderrPath -Force -ErrorAction SilentlyContinue

$playerFlowReport = $null
if (-not $SkipPlayerFlow) {
    Write-Host '[release] Exporting internal player-flow validation build'
    Disable-ReleaseMcp
    try {
        Invoke-Godot @('--headless', '--path', $projectDir, '--export-release', 'Windows Desktop Player Flow', $playerFlowExePath)
    }
    finally {
        Restore-ReleaseMcp
    }
    if (-not (Test-Path -LiteralPath $playerFlowExePath)) {
        throw "Expected player-flow executable was not created: $playerFlowExePath"
    }
    Write-Host '[release] Running exported player flow'
    $playerFlowReport = Invoke-ExportedPlayerFlow `
        -ExecutablePath $playerFlowExePath `
        -ReportPath $playerFlowReportPath `
        -StdoutPath $playerFlowStdoutPath `
        -StderrPath $playerFlowStderrPath
    Remove-Item -LiteralPath $playerFlowExePath -Force -ErrorAction SilentlyContinue
}

$firstOrderAuditReport = $null
if (-not $SkipFirstOrderAudit) {
    Write-Host '[release] Exporting internal first-order audit build'
    Disable-ReleaseMcp
    try {
        Invoke-Godot @('--headless', '--path', $projectDir, '--export-release', 'Windows Desktop First Order Audit', $firstOrderAuditExePath)
    }
    finally {
        Restore-ReleaseMcp
    }
    if (-not (Test-Path -LiteralPath $firstOrderAuditExePath)) {
        throw "Expected first-order audit executable was not created: $firstOrderAuditExePath"
    }
    Write-Host '[release] Running clean-directory first-order audit'
    $firstOrderAuditReport = Invoke-FirstOrderAudit `
        -ExecutablePath $firstOrderAuditExePath `
        -ReportPath $firstOrderAuditReportPath `
        -StdoutPath $firstOrderAuditStdoutPath `
        -StderrPath $firstOrderAuditStderrPath
    Remove-Item -LiteralPath $firstOrderAuditExePath -Force -ErrorAction SilentlyContinue
}

Write-Host '[release] Exporting public Windows Desktop release'
Disable-ReleaseMcp
try {
    Invoke-Godot @('--headless', '--path', $projectDir, '--export-release', 'Windows Desktop', $exePath)
}
finally {
    Restore-ReleaseMcp
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Expected exported executable was not created: $exePath"
}

Write-Host '[release] Verifying public release guardrails'
Invoke-PublicReleaseGuard `
    -ExecutablePath $exePath `
    -ReportPath $publicGuardReportPath `
    -StdoutPath $publicGuardStdoutPath `
    -StderrPath $publicGuardStderrPath
Invoke-PublicFirstOrderGuard `
    -ExecutablePath $exePath `
    -ReportPath $publicFirstOrderGuardReportPath `
    -StdoutPath $publicFirstOrderGuardStdoutPath `
    -StderrPath $publicFirstOrderGuardStderrPath

if (-not $SkipLaunchSmoke) {
    Write-Host '[release] Launching exported game smoke test'
    $process = Start-Process -FilePath $exePath -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 4
    if ($process.HasExited) {
        throw "Exported game exited during launch smoke with code $($process.ExitCode)."
    }
    Stop-Process -Id $process.Id -Force
    Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
}

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $exePath
$file = Get-Item -LiteralPath $exePath
$packageFiles = @(
    $file.Name,
    'release-manifest.json',
    'README.txt',
    'RELEASE_NOTES.md',
    'COLLECT_SUPPORT_BUNDLE.ps1',
    'COLLECT_SUPPORT_BUNDLE.cmd'
)
$manifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    platform = 'windows-x86_64'
    executable = $file.Name
    package_files = $packageFiles
    size_bytes = $file.Length
    sha256 = $hash.Hash.ToLowerInvariant()
    built_at_utc = [DateTime]::UtcNow.ToString('o')
    godot = (Get-Item -LiteralPath $GodotPath).VersionInfo.FileVersion
    tests = if ($SkipTests) { 'skipped' } else { 'passed' }
    launch_smoke = if ($SkipLaunchSmoke) { 'skipped' } else { 'passed' }
    clean_extract_smoke = if ($SkipCleanExtractSmoke) { 'skipped' } else { 'passed' }
    public_release_guard = 'passed'
    public_first_order_guard = 'passed'
    player_flow = if ($SkipPlayerFlow) { 'skipped' } else { 'passed' }
    player_flow_orders = if ($SkipPlayerFlow) { 0 } else { [int]$playerFlowReport.orders_completed }
    player_flow_saves = if ($SkipPlayerFlow) { 0 } else { [int]$playerFlowReport.save_count }
    player_flow_loads = if ($SkipPlayerFlow) { 0 } else { [int]$playerFlowReport.load_count }
    player_flow_final_money = if ($SkipPlayerFlow) { 0 } else { [int]$playerFlowReport.final_money }
    first_order_audit = if ($SkipFirstOrderAudit) { 'skipped' } else { 'passed' }
    first_order_audit_orders = if ($SkipFirstOrderAudit) { 0 } else { [int]$firstOrderAuditReport.orders_completed }
    first_order_audit_saves = if ($SkipFirstOrderAudit) { 0 } else { [int]$firstOrderAuditReport.save_count }
    first_order_audit_loads = if ($SkipFirstOrderAudit) { 0 } else { [int]$firstOrderAuditReport.load_count }
    first_order_audit_order_name = if ($SkipFirstOrderAudit) { '' } else { [string]$firstOrderAuditReport.order_name }
    first_order_audit_score = if ($SkipFirstOrderAudit) { 0 } else { [int]$firstOrderAuditReport.score }
    first_order_audit_grade = if ($SkipFirstOrderAudit) { '' } else { [string]$firstOrderAuditReport.grade }
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Copy-ReleaseDocs
Copy-SupportBundleTools

$packagePaths = @($exePath, $manifestPath, $releaseReadmePath, $releaseNotesPath, $supportBundlePs1Path, $supportBundleCmdPath)
Compress-Archive -LiteralPath $packagePaths -DestinationPath $zipPath -CompressionLevel Optimal
if (-not $SkipCleanExtractSmoke) {
    Write-Host '[release] Running clean-extract package smoke test'
    Invoke-CleanExtractSmoke -PackagePath $zipPath -ExecutableName $file.Name
}
$zipHash = Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath
("$($zipHash.Hash.ToLowerInvariant())  $(Split-Path -Leaf $zipPath)") | Set-Content -LiteralPath $zipSha256Path -Encoding ASCII

Write-Host '[release] Build complete'
Write-Host "[release] EXE: $exePath"
Write-Host "[release] ZIP: $zipPath"
Write-Host "[release] EXE SHA256: $($manifest.sha256)"
Write-Host "[release] ZIP SHA256: $($zipHash.Hash.ToLowerInvariant())"
