[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [switch]$SkipPackageAudit
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
$buildDir = Join-Path $projectDir 'build\windows'
$mediaDir = Join-Path $projectDir 'release\media'
$docDir = Join-Path $repoRoot 'doc'
$playtestRoot = Join-Path $projectDir 'build\playtest'
$kitDir = Join-Path $playtestRoot "PCBuildingLife-$Version"
$packageDir = Join-Path $kitDir 'package'
$docsDir = Join-Path $kitDir 'docs'
$mediaOutDir = Join-Path $kitDir 'media'

$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$releaseManifestPath = Join-Path $buildDir 'release-manifest.json'
$packageAuditPath = Join-Path $buildDir 'release-package-audit-report.json'
$publicDownloadReportPath = Join-Path $buildDir 'public-download-audit-report.json'
$kitManifestPath = Join-Path $kitDir 'playtest-kit-manifest.json'
$readmePath = Join-Path $kitDir 'README_PLAYTEST.txt'
$reportTemplatePath = Join-Path $kitDir 'TEST_REPORT_TEMPLATE.md'
$launcherPs1Path = Join-Path $kitDir 'START_PLAYTEST_KIT.ps1'
$launcherCmdPath = Join-Path $kitDir 'START_PLAYTEST_KIT.cmd'
$supportPs1Path = Join-Path $kitDir 'COLLECT_SUPPORT_BUNDLE.ps1'
$supportCmdPath = Join-Path $kitDir 'COLLECT_SUPPORT_BUNDLE.cmd'
$kitZipPath = Join-Path $playtestRoot "PCBuildingLife-$Version-playtest-kit.zip"

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
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

if (-not $SkipPackageAudit) {
    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') -PackagePath $zipPath -Sha256Path $shaPath -ReportPath $packageAuditPath
}

foreach ($required in @($zipPath, $shaPath, $releaseManifestPath, $packageAuditPath, $docDir)) {
    Assert-File $required
}

$resolvedPlaytestRoot = [System.IO.Path]::GetFullPath($playtestRoot)
$resolvedKitDir = [System.IO.Path]::GetFullPath($kitDir)
Assert-Condition ($resolvedKitDir.StartsWith($resolvedPlaytestRoot, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to clean kit path outside playtest root: $resolvedKitDir"

if (Test-Path -LiteralPath $resolvedKitDir) {
    Remove-Item -LiteralPath $resolvedKitDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageDir, $docsDir, $mediaOutDir | Out-Null

Copy-RequiredFile -Source $zipPath -Destination (Join-Path $packageDir (Split-Path -Leaf $zipPath))
Copy-RequiredFile -Source $shaPath -Destination (Join-Path $packageDir (Split-Path -Leaf $shaPath))
Copy-RequiredFile -Source $releaseManifestPath -Destination (Join-Path $packageDir 'release-manifest.json')
Copy-RequiredFile -Source $packageAuditPath -Destination (Join-Path $packageDir 'release-package-audit-report.json')
if (Test-Path -LiteralPath $publicDownloadReportPath) {
    Copy-RequiredFile -Source $publicDownloadReportPath -Destination (Join-Path $packageDir 'public-download-audit-report.json')
}
Copy-RequiredFile -Source (Join-Path $PSScriptRoot 'collect_support_bundle.ps1') -Destination $supportPs1Path

$docSourceFiles = @(Get-ChildItem -LiteralPath $docDir -Filter '*.md' -File | Where-Object {
    $docText = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName
    -not $docText.Contains('fixed-validation-commands')
} | Sort-Object Name)
Assert-Condition ($docSourceFiles.Count -gt 0) "No markdown docs found in $docDir"
foreach ($docFile in $docSourceFiles) {
    Copy-RequiredFile -Source $docFile.FullName -Destination (Join-Path $docsDir $docFile.Name)
}

foreach ($fileName in @(
    'cover-1920x1080.png',
    'channel-header-1920x620.png',
    'small-cover-630x500.png',
    '01-main-menu.png',
    '02-workbench.png',
    '03-order-desk.png',
    '04-catalog-shop.png',
    '05-catalog-inventory.png',
    '06-task-center.png',
    '07-system-center.png',
    '08-max-monitor.png',
    '09-delivery-feedback.png',
    'contact-sheet.png',
    'branding-sheet.png'
)) {
    Copy-RequiredFile -Source (Join-Path $mediaDir $fileName) -Destination (Join-Path $mediaOutDir $fileName)
}

$audit = Get-Content -Raw -Encoding UTF8 -LiteralPath $packageAuditPath | ConvertFrom-Json
$zipFile = Get-Item -LiteralPath $zipPath

$readmeLines = @(
    "PC Building Life $Version Playtest Kit",
    "",
    "Start here:",
    "1. Extract package/PCBuildingLife-Windows-x64-$Version.zip.",
    "2. Run PCBuildingLife.exe.",
    "3. Start a new game and finish the first order.",
    "4. Save, restart the game, and confirm Continue Game works.",
    "5. Send feedback through https://github.com/bumagh/PCBuildingLife/issues.",
    "6. For double-click launch, run START_PLAYTEST_KIT.cmd. It checks the package SHA before launch and opens the game window visibly.",
    "",
    "Important files:",
    "- package/PCBuildingLife-Windows-x64-$Version.zip",
    "- package/PCBuildingLife-Windows-x64-$Version.zip.sha256",
    "- docs/outer playtest checklist is included with the selected Chinese markdown docs.",
    "- docs/playtest feedback summary template is included for go/no-go triage.",
    "- After the game closes, START_PLAYTEST_KIT.ps1 creates PLAYTEST_SESSION_<timestamp>.md and a writable PLAYTEST_REPORT_<timestamp>.md.",
    "- If the game crashes or blocks progress, run COLLECT_SUPPORT_BUNDLE.cmd and attach the generated support ZIP to the issue.",
    "- TEST_REPORT_TEMPLATE.md",
    "",
    "Verification:",
    "- ZIP SHA-256: $($audit.package_sha256)",
    "- EXE SHA-256: $($audit.exe_sha256)",
    "- Player flow orders passed: $($audit.player_flow_orders)",
    "- First-order audit: $($audit.first_order_audit_order_name) $($audit.first_order_audit_score) / $($audit.first_order_audit_grade)",
    "",
    "Do not share passwords, phone numbers, ID numbers, payment data, or private account data in feedback."
)
$readmeLines | Set-Content -LiteralPath $readmePath -Encoding UTF8

$reportLines = @(
    "# PC Building Life 0.1.0-dev Playtest Report",
    "",
    "- Tester:",
    "- Test date:",
    "- Game version: $Version",
    "- Package SHA-256: $($audit.package_sha256)",
    "- Windows version:",
    "- CPU / GPU:",
    "- Memory:",
    "- Resolution:",
    "- Fullscreen or windowed:",
    "",
    "## Result",
    "",
    "- [ ] Passed: finished first order, saved, restarted, and continued.",
    "- [ ] Playable with issues: finished first order but found problems.",
    "- [ ] Blocked: could not launch, finish first order, save, or continue.",
    "",
    "## First Order",
    "",
    "- Order name:",
    "- Final grade:",
    "- Final score:",
    "- Any confusing step:",
    "",
    "## Issues",
    "",
    "1. What happened?",
    "2. What did you expect?",
    "3. How can it be reproduced?",
    "4. Screenshot or video path:",
    "",
    "## Most Important Fix",
    "",
    "Write the one thing that most needs improvement before public release.",
    "",
    "## Release Readiness Signal",
    "",
    "- [ ] I would recommend this build to another tester.",
    "- [ ] I would wait for fixes before more testers play it.",
    "- [ ] This build should not be published yet because it has a blocking issue."
)
$reportLines | Set-Content -LiteralPath $reportTemplatePath -Encoding UTF8

$launcherPs1Lines = @(
    "param([string]`$Version = '$Version')",
    '',
    '$ErrorActionPreference = ''Stop''',
    '',
    '$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path',
    '$kitRoot = [System.IO.Path]::GetFullPath($scriptDir)',
    '$packageZip = Join-Path $kitRoot (''package\PCBuildingLife-Windows-x64-{0}.zip'' -f $Version)',
    '$packageSha = "$packageZip.sha256"',
    '$reportTemplate = Join-Path $kitRoot ''TEST_REPORT_TEMPLATE.md''',
    '$readme = Join-Path $kitRoot ''README_PLAYTEST.txt''',
    '$sessionLog = Join-Path $kitRoot (''PLAYTEST_SESSION_{0}.md'' -f ([DateTime]::UtcNow.ToString(''yyyyMMdd-HHmmss'')))',
    '$sessionReport = Join-Path $kitRoot (''PLAYTEST_REPORT_{0}.md'' -f ([DateTime]::UtcNow.ToString(''yyyyMMdd-HHmmss'')))',
    '',
    'function Assert-Condition {',
    '    param([bool]$Condition, [string]$Message)',
    '    if (-not $Condition) { throw $Message }',
    '}',
    '',
    'Assert-Condition (Test-Path -LiteralPath $packageZip) "Missing package ZIP: $packageZip"',
    'Assert-Condition (Test-Path -LiteralPath $packageSha) "Missing package SHA file: $packageSha"',
    '$expectedHash = ((Get-Content -Raw -Encoding ASCII -LiteralPath $packageSha) -split ''\s+'')[0].Trim().ToLowerInvariant()',
    '$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $packageZip).Hash.ToLowerInvariant()',
    'Assert-Condition ($actualHash -eq $expectedHash) "Package SHA-256 mismatch. Expected $expectedHash, got $actualHash."',
    '',
    '$tempBase = Join-Path $kitRoot ''temp''',
    'New-Item -ItemType Directory -Force -Path $tempBase | Out-Null',
    '$tempRoot = Join-Path $tempBase (''playtest-run-{0}'' -f ([Guid]::NewGuid().ToString(''N'')))',
    'New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null',
    '',
    'try {',
    '    Expand-Archive -LiteralPath $packageZip -DestinationPath $tempRoot -Force',
    '    $exePath = Join-Path $tempRoot ''PCBuildingLife.exe''',
    '    Assert-Condition (Test-Path -LiteralPath $exePath) "Missing game EXE after extract: $exePath"',
    '    Write-Host "[playtest-launch] launching $exePath"',
    '    $process = Start-Process -FilePath $exePath -WorkingDirectory $tempRoot -PassThru',
    '    Wait-Process -Id $process.Id',
    '    $os = Get-CimInstance Win32_OperatingSystem',
    '    @(',
    '        "# PC Building Life Playtest Session",',
    '        "",',
    '        "- Launch time (UTC): $([DateTime]::UtcNow.ToString(''o''))",',
    '        "- Kit root: $kitRoot",',
    '        "- Package ZIP: $packageZip",',
    '        "- Package SHA-256: $actualHash",',
    '        "- OS: $($os.Caption) $($os.Version)",',
    '        "- Computer: $env:COMPUTERNAME",',
    '        "- User: $env:USERNAME",',
    '        "",',
    '        "This file is created automatically after the game closes. Use it together with the report template below.",',
    '        "",',
    '        "# Report Template Copy",',
    '        "",',
    '        "A writable copy of TEST_REPORT_TEMPLATE.md is saved next to this log."',
    '    ) | Set-Content -LiteralPath $sessionLog -Encoding UTF8',
    '    if (Test-Path -LiteralPath $reportTemplate) { Copy-Item -LiteralPath $reportTemplate -Destination $sessionReport -Force }',
    '    if (Test-Path -LiteralPath $sessionLog) { Start-Process notepad.exe -ArgumentList $sessionLog | Out-Null }',
    '    if (Test-Path -LiteralPath $sessionReport) { Start-Process notepad.exe -ArgumentList $sessionReport | Out-Null }',
    '    if (Test-Path -LiteralPath $readme) { Start-Process notepad.exe -ArgumentList $readme | Out-Null }',
    '}',
    'finally {',
    '    if (Test-Path -LiteralPath $tempRoot) {',
    '        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue',
    '    }',
    '}'
)
$launcherPs1Lines | Set-Content -LiteralPath $launcherPs1Path -Encoding UTF8

$launcherCmdLines = @(
    '@echo off',
    'setlocal',
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0START_PLAYTEST_KIT.ps1"',
    'endlocal'
)
$launcherCmdLines | Set-Content -LiteralPath $launcherCmdPath -Encoding ASCII

$supportCmdLines = @(
    '@echo off',
    'setlocal',
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0COLLECT_SUPPORT_BUNDLE.ps1"',
    'pause',
    'endlocal'
)
$supportCmdLines | Set-Content -LiteralPath $supportCmdPath -Encoding ASCII

$kitManifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    kit_path = $resolvedKitDir
    kit_zip = $kitZipPath
    package_zip = "package/$(Split-Path -Leaf $zipPath)"
    package_sha256_file = "package/$(Split-Path -Leaf $shaPath)"
    package_sha256 = [string]$audit.package_sha256
    package_size_bytes = [int64]$zipFile.Length
    exe_sha256 = [string]$audit.exe_sha256
    exe_size_bytes = [int64]$audit.exe_size_bytes
    player_flow_orders = [int]$audit.player_flow_orders
    first_order_audit_order_name = [string]$audit.first_order_audit_order_name
    first_order_audit_score = [int]$audit.first_order_audit_score
    first_order_audit_grade = [string]$audit.first_order_audit_grade
    feedback_url = [string]$audit.feedback_url
    doc_files = @($docSourceFiles | ForEach-Object { $_.Name })
    media_files = @(Get-ChildItem -LiteralPath $mediaOutDir -File | Sort-Object Name | ForEach-Object { $_.Name })
    launcher_ps1 = 'START_PLAYTEST_KIT.ps1'
    launcher_cmd = 'START_PLAYTEST_KIT.cmd'
    support_bundle_ps1 = 'COLLECT_SUPPORT_BUNDLE.ps1'
    support_bundle_cmd = 'COLLECT_SUPPORT_BUNDLE.cmd'
    created_at_utc = [DateTime]::UtcNow.ToString('o')
}
$kitManifest | ConvertTo-Json | Set-Content -LiteralPath $kitManifestPath -Encoding UTF8

if (Test-Path -LiteralPath $kitZipPath) {
    Remove-Item -LiteralPath $kitZipPath -Force
}
$kitItems = @(Get-ChildItem -LiteralPath $kitDir -Force)
Assert-Condition ($kitItems.Count -gt 0) "Playtest kit directory is empty: $kitDir"
Compress-Archive -Path @($kitItems | ForEach-Object { $_.FullName }) -DestinationPath $kitZipPath -Force

$kitZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $kitZipPath).Hash.ToLowerInvariant()
$kitZipHashPath = "$kitZipPath.sha256"
("{0}  {1}" -f $kitZipHash, (Split-Path -Leaf $kitZipPath)) | Set-Content -LiteralPath $kitZipHashPath -Encoding ASCII

Write-Host '[playtest-kit] ok'
Write-Host "[playtest-kit] $resolvedKitDir"
Write-Host "[playtest-kit] $kitZipPath"
Write-Host "[playtest-kit] sha256=$kitZipHash"
