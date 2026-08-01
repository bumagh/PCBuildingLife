[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev'
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$reportPath = Join-Path $projectDir "build\public-release-go\external-release-cycle-$Version.json"
$manifestPath = Join-Path $projectDir "build\itch\PCBuildingLife-$Version\itch-upload-manifest.json"
$shaPath = Join-Path $projectDir "build\windows\PCBuildingLife-Windows-x64-$Version.zip.sha256"
$exampleConfigPath = Join-Path $projectDir 'release\itch-upload-config.example.json'
$tmpRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir 'tmp\verify-external-release-cycle'))
$allowedTmpRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir 'tmp'))

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$manifestBefore = if (Test-Path -LiteralPath $manifestPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json } else { $null }
& (Join-Path $PSScriptRoot 'advance_external_release.ps1') -Version $Version

Assert-Condition (Test-Path -LiteralPath $reportPath) "External release cycle report not found: $reportPath"
$report = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json
$expectedHash = ((Get-Content -Raw -Encoding ASCII -LiteralPath $shaPath) -split '\s+')[0].Trim().ToLowerInvariant()
$manifestAfter = if (Test-Path -LiteralPath $manifestPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json } else { $null }

Assert-Condition ([string]$report.package_sha256 -eq $expectedHash) 'External release cycle report is stale.'
Assert-Condition (-not [bool]$report.push_requested) 'Default external release cycle unexpectedly requested a push.'
Assert-Condition (-not [bool]$report.push_performed) 'Default external release cycle unexpectedly performed a push.'
Assert-Condition ([string]$report.public_release_gate_decision -in @('no_go_external_gates_required', 'go_public_release')) 'External release cycle report has an invalid public gate decision.'
Assert-Condition (@($report.steps | Where-Object { $_.name -eq 'channel_push' -and $_.status -eq 'skipped' }).Count -eq 1) 'Default cycle did not explicitly record channel push as skipped.'
if ($null -ne $manifestBefore -and $null -ne $manifestAfter) {
    Assert-Condition ([bool]$manifestBefore.pushed -eq [bool]$manifestAfter.pushed) 'Default cycle changed the itch staging pushed state.'
}

Assert-Condition ($tmpRoot.StartsWith($allowedTmpRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside project tmp: $tmpRoot"
if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
$stdoutPath = Join-Path $tmpRoot 'stdout.log'
$stderrPath = Join-Path $tmpRoot 'stderr.log'
$powershellExe = (Get-Process -Id $PID).Path
$cycleScript = Join-Path $PSScriptRoot 'advance_external_release.ps1'
$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"{0}"' -f $cycleScript),
    '-Version', $Version,
    '-ConfigPath', ('"{0}"' -f $exampleConfigPath),
    '-Push'
)
$process = Start-Process -FilePath $powershellExe -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$blockedReport = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportPath | ConvertFrom-Json
Assert-Condition ($process.ExitCode -ne 0) 'Missing-target -Push unexpectedly succeeded.'
Assert-Condition ([bool]$blockedReport.push_requested) 'Missing-target guard did not record push_requested=true.'
Assert-Condition (-not [bool]$blockedReport.push_performed) 'Missing-target guard incorrectly recorded push_performed=true.'
Assert-Condition (@($blockedReport.steps | Where-Object { $_.name -eq 'channel_push' -and $_.status -eq 'fail' }).Count -eq 1) 'Missing-target guard did not record channel_push as failed.'

& (Join-Path $PSScriptRoot 'advance_external_release.ps1') -Version $Version | Out-Null
Assert-Condition ($LASTEXITCODE -eq 0) 'Failed to restore the default external release cycle report after the push guard test.'
if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

Write-Host '[external-release-cycle-verify] ok'
Write-Host "[external-release-cycle-verify] decision=$($report.decision) gate=$($report.public_release_gate_decision)"
Write-Host "[external-release-cycle-verify] missing_target_push_exit=$($process.ExitCode) push_performed=$($blockedReport.push_performed)"
Write-Host "[external-release-cycle-verify] report=$reportPath"
