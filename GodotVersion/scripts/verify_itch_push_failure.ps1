[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev'
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tmpRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir 'tmp\verify-itch-push-failure'))
$allowedTmpRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir 'tmp'))
$stageManifestPath = Join-Path $projectDir "build\itch\PCBuildingLife-$Version\itch-upload-manifest.json"
$reportPath = Join-Path $projectDir "build\itch\itch-push-failure-audit-$Version.json"

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

Assert-Condition ($tmpRoot.StartsWith($allowedTmpRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to use temp path outside project tmp: $tmpRoot"
if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

$fakeButlerPath = Join-Path $tmpRoot 'butler.cmd'
$configPath = Join-Path $tmpRoot 'itch-upload-config.failure-test.json'
$stdoutPath = Join-Path $tmpRoot 'stdout.log'
$stderrPath = Join-Path $tmpRoot 'stderr.log'
$prepareScript = Join-Path $PSScriptRoot 'prepare_itch_upload.ps1'

@(
    '@echo off',
    'echo simulated butler upload failure 1>&2',
    'exit /b 23'
) | Set-Content -LiteralPath $fakeButlerPath -Encoding ASCII

[ordered]@{
    itch_target = 'failure-test/project'
    channel = 'windows-demo'
    hidden = $true
    if_changed = $true
    public_package_url = ''
    public_sha256_url = ''
} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8

$oldPath = $env:PATH
$failureManifest = $null
$exitCode = 0
$combinedOutput = ''
try {
    $env:PATH = "$tmpRoot;$oldPath"
    $powershellExe = (Get-Process -Id $PID).Path
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $prepareScript),
        '-Version', $Version,
        '-ConfigPath', ('"{0}"' -f $configPath),
        '-Push',
        '-SkipPackageAudit'
    )
    $process = Start-Process -FilePath $powershellExe -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $exitCode = [int]$process.ExitCode
    $combinedOutput = ((Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutPath -ErrorAction SilentlyContinue) + "`n" + (Get-Content -Raw -Encoding UTF8 -LiteralPath $stderrPath -ErrorAction SilentlyContinue))
    if (Test-Path -LiteralPath $stageManifestPath) {
        $failureManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $stageManifestPath | ConvertFrom-Json
    }

    Assert-Condition ($exitCode -ne 0) 'Fake butler failure unexpectedly returned exit code 0.'
    Assert-Condition ($combinedOutput.Contains('butler push failed with exit code 23')) 'prepare_itch_upload.ps1 did not surface the fake butler exit code.'
    Assert-Condition ($null -ne $failureManifest) 'Failure run did not leave an auditable itch-upload-manifest.json.'
    Assert-Condition ([bool]$failureManifest.push_requested) 'Failure manifest did not record push_requested=true.'
    Assert-Condition (-not [bool]$failureManifest.pushed) 'Failure manifest incorrectly recorded pushed=true.'
    Assert-Condition ([int]$failureManifest.butler_exit_code -eq 23) 'Failure manifest did not record butler_exit_code=23.'
}
finally {
    $env:PATH = $oldPath
    & $prepareScript -Version $Version -Hidden -SkipPackageAudit
    & (Join-Path $PSScriptRoot 'verify_itch_staging.ps1') -Version $Version
}

$restoredManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $stageManifestPath | ConvertFrom-Json
Assert-Condition (-not [bool]$restoredManifest.pushed) 'Restored placeholder staging manifest must remain pushed=false.'

$report = [ordered]@{
    ok = $true
    version = $Version
    simulated_butler_exit_code = 23
    script_exit_code = $exitCode
    failure_manifest_push_requested = [bool]$failureManifest.push_requested
    failure_manifest_pushed = [bool]$failureManifest.pushed
    failure_manifest_butler_exit_code = [int]$failureManifest.butler_exit_code
    restored_manifest_pushed = [bool]$restoredManifest.pushed
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8

if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

Write-Host '[itch-push-failure-verify] ok'
Write-Host '[itch-push-failure-verify] fake_butler_exit=23 manifest_pushed=false'
Write-Host "[itch-push-failure-verify] report=$reportPath"
