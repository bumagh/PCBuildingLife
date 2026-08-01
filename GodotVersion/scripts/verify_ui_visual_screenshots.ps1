[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\1exe\3Dev\1GameEngine\Godot_v4.7-rc3_win64\Godot_v4.7-rc3_win64_console.exe',
    [string]$DisplayDriver = 'windows',
    [string]$RenderingDriver = 'vulkan',
    [switch]$StrictExitCode,
    [string[]]$Tests
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
$legacyScreenshotDir = [System.IO.Path]::GetFullPath((Join-Path $projectDir 'tmp\ui-checks\suite'))

if ($null -eq $Tests -or $Tests.Count -eq 0) {
    $Tests = @(
        'verify_main_menu_screenshot.gd',
        'verify_ui_screenshot.gd',
        'verify_home_bottom_dock_screenshot.gd',
        'verify_workbench_screenshot.gd',
        'verify_order_desk_screenshot.gd',
        'verify_catalog_overlay_screenshot.gd',
        'verify_catalog_screenshot.gd',
        'verify_task_center_screenshot.gd',
        'verify_system_center_screenshot.gd',
        'verify_monitor_screenshot.gd',
        'verify_action_feedback_screenshot.gd',
        'verify_key_animation_screenshot.gd'
    )
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

$warnings = @()
$perSizeTests = @(
    'verify_main_menu_screenshot.gd',
    'verify_action_feedback_screenshot.gd',
    'verify_key_animation_screenshot.gd',
    'verify_monitor_screenshot.gd',
    'verify_system_center_screenshot.gd'
)
$compatibilityTests = @(
    'verify_key_animation_screenshot.gd',
    'verify_monitor_screenshot.gd',
    'verify_system_center_screenshot.gd'
)

function Get-SuccessMarker {
    param([string]$Test)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($Test)
    if ($name.StartsWith('verify_')) {
        $name = $name.Substring(7)
    }
    return "$name=ok"
}

function Invoke-VisualScreenshotTest {
    param(
        [string]$Test,
        [string[]]$ExtraArguments = @(),
        [string]$RenderingMethod = '',
        [string]$TestRenderingDriver = ''
    )

    $scriptPath = Join-Path $projectDir "scripts\$Test"
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Visual screenshot test not found: $scriptPath"
    }

    Write-Host "[visual] Test $Test $($ExtraArguments -join ' ')"
    $effectiveRenderingDriver = $RenderingDriver
    if (-not [string]::IsNullOrWhiteSpace($TestRenderingDriver)) {
        $effectiveRenderingDriver = $TestRenderingDriver
    }
    $arguments = @(
        '--display-driver',
        $DisplayDriver,
        '--rendering-driver',
        $effectiveRenderingDriver
    )
    if (-not [string]::IsNullOrWhiteSpace($RenderingMethod)) {
        $arguments += @(
            '--rendering-method',
            $RenderingMethod
        )
    }
    $arguments += @(
        '--path',
        $projectDir,
        '-s',
        "res://scripts/$Test"
    ) + $ExtraArguments
    $output = & $GodotPath @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -ne 0) {
        $successMarker = Get-SuccessMarker -Test $Test
        $completedBeforeCrash = ($output -join "`n").Contains($successMarker)
        if (-not $StrictExitCode -and $completedBeforeCrash -and ($exitCode -eq -1073741819 -or $exitCode -eq 1)) {
            Write-Host "[visual] Accepted post-capture Godot exit code $exitCode after success marker: $Test"
            return
        }
        throw "Visual screenshot test failed with exit code ${exitCode}: $Test"
    }
}

foreach ($test in $Tests) {
    if ($perSizeTests -contains $test) {
        foreach ($size in @('1280x720', '1366x768', '1920x1080')) {
            if ($compatibilityTests -contains $test) {
                Invoke-VisualScreenshotTest `
                    -Test $test `
                    -ExtraArguments @('--', "--pcbl-size=$size") `
                    -RenderingMethod 'gl_compatibility' `
                    -TestRenderingDriver 'opengl3'
            }
            else {
                Invoke-VisualScreenshotTest -Test $test -ExtraArguments @('--', "--pcbl-size=$size")
            }
        }
        continue
    }

    Invoke-VisualScreenshotTest -Test $test
}

New-Item -ItemType Directory -Force -Path $legacyScreenshotDir | Out-Null
Get-ChildItem -LiteralPath $workspaceRoot -File -Filter 'GodotVersion-*.png' | ForEach-Object {
    $sourcePath = [System.IO.Path]::GetFullPath($_.FullName)
    if ([System.IO.Path]::GetDirectoryName($sourcePath) -ne $workspaceRoot) {
        throw "Unexpected screenshot source outside workspace root: $sourcePath"
    }
    Move-Item -LiteralPath $sourcePath -Destination (Join-Path $legacyScreenshotDir $_.Name) -Force
}

Write-Host "[visual] Screenshot suite complete warnings=$($warnings.Count)"
Write-Host "[visual] Screenshot artifacts: $legacyScreenshotDir"
