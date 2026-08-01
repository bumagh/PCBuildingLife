[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$OutputDir,
    [switch]$SkipPackageAudit
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
$buildDir = Join-Path $projectDir 'build\windows'
$validationRoot = Join-Path $projectDir 'build\clean-machine-validation'
$docDir = Join-Path $repoRoot 'doc'
$releaseMediaDir = Join-Path $projectDir 'release\media'
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $validationRoot "PCBuildingLife-$Version"
}

$kitDir = [System.IO.Path]::GetFullPath($OutputDir)
$packageDir = Join-Path $kitDir 'package'
$docsDir = Join-Path $kitDir 'docs'
$mediaDir = Join-Path $kitDir 'media'
$evidenceDir = Join-Path $kitDir 'evidence'
$kitZipPath = Join-Path $validationRoot "PCBuildingLife-$Version-clean-machine-validation-kit.zip"
$kitShaPath = "$kitZipPath.sha256"

$playerZipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$playerShaPath = "$playerZipPath.sha256"
$releaseManifestPath = Join-Path $buildDir 'release-manifest.json'
$packageAuditPath = Join-Path $buildDir 'release-package-audit-report.json'
$publicDownloadReportPath = Join-Path $buildDir 'public-download-audit-report.json'
$itchConfigAuditPath = Join-Path $projectDir "build\itch\itch-upload-config-audit-$Version.json"
$manifestPath = Join-Path $kitDir 'clean-machine-validation-manifest.json'

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

function Read-Sha256File {
    param([string]$Path)
    Assert-File $Path
    return ((Get-Content -Raw -Encoding ASCII -LiteralPath $Path) -split '\s+')[0].Trim().ToLowerInvariant()
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

if (-not $SkipPackageAudit) {
    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') -PackagePath $playerZipPath -Sha256Path $playerShaPath -ReportPath $packageAuditPath
}

foreach ($required in @($playerZipPath, $playerShaPath, $releaseManifestPath, $packageAuditPath, $docDir)) {
    Assert-File $required
}

$validationRootFullPath = [System.IO.Path]::GetFullPath($validationRoot)
Assert-Condition ($kitDir.StartsWith($validationRootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to clean kit path outside clean-machine-validation root: $kitDir"
if (Test-Path -LiteralPath $kitDir) {
    Remove-Item -LiteralPath $kitDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageDir, $docsDir, $mediaDir, $evidenceDir | Out-Null

$packageHash = Read-Sha256File -Path $playerShaPath
$packageAudit = Read-JsonFile -Path $packageAuditPath
$publicDownloadReport = Read-JsonFile -Path $publicDownloadReportPath
$itchConfigAudit = Read-JsonFile -Path $itchConfigAuditPath

Copy-RequiredFile -Source $playerZipPath -Destination (Join-Path $packageDir (Split-Path -Leaf $playerZipPath))
Copy-RequiredFile -Source $playerShaPath -Destination (Join-Path $packageDir (Split-Path -Leaf $playerShaPath))
Copy-RequiredFile -Source $releaseManifestPath -Destination (Join-Path $evidenceDir 'release-manifest.json')
Copy-RequiredFile -Source $packageAuditPath -Destination (Join-Path $evidenceDir 'release-package-audit-report.json')
if (Test-Path -LiteralPath $publicDownloadReportPath) {
    Copy-RequiredFile -Source $publicDownloadReportPath -Destination (Join-Path $evidenceDir 'public-download-audit-report.json')
}
if (Test-Path -LiteralPath $itchConfigAuditPath) {
    Copy-RequiredFile -Source $itchConfigAuditPath -Destination (Join-Path $evidenceDir 'itch-upload-config-audit.json')
}

$docSourceFiles = @(Get-ChildItem -LiteralPath $docDir -Filter '*.md' -File | Where-Object {
    $docText = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName
    -not $docText.Contains('fixed-validation-commands')
} | Sort-Object Name)
Assert-Condition ($docSourceFiles.Count -gt 0) "No markdown docs found in $docDir"
foreach ($docFile in $docSourceFiles) {
    Copy-RequiredFile -Source $docFile.FullName -Destination (Join-Path $docsDir $docFile.Name)
}
foreach ($mediaName in @('01-main-menu.png', '02-workbench.png', '03-order-desk.png', '08-max-monitor.png', '09-delivery-feedback.png', 'contact-sheet.png')) {
    Copy-RequiredFile -Source (Join-Path $releaseMediaDir $mediaName) -Destination (Join-Path $mediaDir $mediaName)
}

$publicPackageUrl = ''
$publicShaUrl = ''
if ($itchConfigAudit -ne $null -and [bool]$itchConfigAudit.public_urls_configured) {
    $publicPackageUrl = [string]$itchConfigAudit.public_package_url
    $publicShaUrl = [string]$itchConfigAudit.public_sha256_url
}
elseif ($publicDownloadReport -ne $null -and [string]$publicDownloadReport.source -eq 'url') {
    $publicPackageUrl = [string]$publicDownloadReport.package_url
    $publicShaUrl = [string]$publicDownloadReport.sha256_url
}

$readmeLines = @(
    "PC Building Life $Version Clean Machine Validation Kit",
    "",
    "Goal",
    "",
    "Run this kit on a clean Windows machine or a Windows user profile that has not previously played PC Building Life.",
    "",
    "Start",
    "",
    "1. Extract this kit ZIP.",
    "2. Double-click RUN_CLEAN_MACHINE_VALIDATION.cmd.",
    "3. Let the script verify the package SHA-256 and launch PCBuildingLife.exe.",
    "4. In the game, start a new game, finish the first order, save, close, restart if needed, and confirm Continue Game works.",
    "5. Fill the generated CLEAN_MACHINE_REPORT_*.md file.",
    "",
    "Current package",
    "",
    "- Player ZIP SHA-256: $packageHash",
    "- Player flow orders in release audit: $($packageAudit.player_flow_orders)",
    "- First-order audit: $($packageAudit.first_order_audit_order_name) $($packageAudit.first_order_audit_score) / $($packageAudit.first_order_audit_grade)",
    "",
    "Privacy",
    "",
    "Do not include passwords, phone numbers, payment data, account tokens, ID numbers, or private identity information in reports."
)
$readmeLines | Set-Content -LiteralPath (Join-Path $kitDir 'README_CLEAN_MACHINE_VALIDATION.txt') -Encoding UTF8

$reportTemplateLines = @(
    "# PC Building Life $Version Clean Machine Validation Report",
    "",
    "- Tester:",
    "- Test date:",
    "- Machine type: clean Windows machine / clean Windows user profile",
    "- Game version: $Version",
    "- Package SHA-256: $packageHash",
    "- Package source: bundled package / public URL",
    "- Public package URL:",
    "- Windows version:",
    "- CPU / GPU:",
    "- Memory:",
    "- Resolution:",
    "- Fullscreen or windowed:",
    "",
    "## Required Path",
    "",
    "- [ ] Package SHA-256 verified before launch.",
    "- [ ] Game launched from extracted ZIP.",
    "- [ ] Started a new game.",
    "- [ ] Finished first order.",
    "- [ ] Saved progress.",
    "- [ ] Closed and reopened the game.",
    "- [ ] Continue Game loaded the save.",
    "- [ ] No previous PC Building Life save was used.",
    "",
    "## Result",
    "",
    "- [ ] Passed: first order, save, restart, and continue all worked.",
    "- [ ] Playable with issues: path completed but problems were found.",
    "- [ ] Blocked: could not launch, finish first order, save, restart, or continue.",
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
    "## Release Readiness Signal",
    "",
    "- [ ] I would recommend this build to another tester.",
    "- [ ] I would wait for fixes before more testers play it.",
    "- [ ] This build should not be published yet because it has a blocking issue."
)
$reportTemplateLines | Set-Content -LiteralPath (Join-Path $kitDir 'CLEAN_MACHINE_REPORT_TEMPLATE.md') -Encoding UTF8

$runnerPs1Lines = @(
    "param(",
    "    [string]`$PackageUrl = '$publicPackageUrl',",
    "    [string]`$Sha256Url = '$publicShaUrl',",
    "    [string]`$ExpectedPackageSha256 = '$packageHash'",
    ")",
    "",
    "`$ErrorActionPreference = 'Stop'",
    "",
    "function Assert-Condition {",
    "    param([bool]`$Condition, [string]`$Message)",
    "    if (-not `$Condition) { throw `$Message }",
    "}",
    "",
    "function Save-RemoteFile {",
    "    param([string]`$Url, [string]`$Destination)",
    "    Write-Host `"[clean-machine] Downloading `$Url`"",
    "    Invoke-WebRequest -Uri `$Url -OutFile `$Destination -UseBasicParsing",
    "    Assert-Condition (Test-Path -LiteralPath `$Destination) `"Downloaded file is missing: `$Destination`"",
    "}",
    "",
    "`$scriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path",
    "`$kitRoot = [System.IO.Path]::GetFullPath(`$scriptDir)",
    "`$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')",
    "`$sessionDir = Join-Path `$kitRoot (`"CLEAN_MACHINE_SESSION_`$stamp`")",
    "`$downloadDir = Join-Path `$sessionDir 'download'",
    "`$runDir = Join-Path `$sessionDir 'run'",
    "New-Item -ItemType Directory -Force -Path `$downloadDir, `$runDir | Out-Null",
    "",
    "`$packagePath = Join-Path `$kitRoot 'package\PCBuildingLife-Windows-x64-$Version.zip'",
    "`$shaPath = `"`$packagePath.sha256`"",
    "if (-not [string]::IsNullOrWhiteSpace(`$PackageUrl)) {",
    "    `$packagePath = Join-Path `$downloadDir 'PCBuildingLife-Windows-x64-$Version.zip'",
    "    Save-RemoteFile -Url `$PackageUrl -Destination `$packagePath",
    "    `$shaPath = Join-Path `$downloadDir 'PCBuildingLife-Windows-x64-$Version.zip.sha256'",
    "    if (-not [string]::IsNullOrWhiteSpace(`$Sha256Url)) {",
    "        Save-RemoteFile -Url `$Sha256Url -Destination `$shaPath",
    "    }",
    "    else {",
    "        `"`$ExpectedPackageSha256  PCBuildingLife-Windows-x64-$Version.zip`" | Set-Content -LiteralPath `$shaPath -Encoding ASCII",
    "    }",
    "}",
    "",
    "Assert-Condition (Test-Path -LiteralPath `$packagePath) `"Missing package ZIP: `$packagePath`"",
    "Assert-Condition (Test-Path -LiteralPath `$shaPath) `"Missing package SHA file: `$shaPath`"",
    "`$shaFromFile = ((Get-Content -Raw -Encoding ASCII -LiteralPath `$shaPath) -split '\s+')[0].Trim().ToLowerInvariant()",
    "`$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath `$packagePath).Hash.ToLowerInvariant()",
    "Assert-Condition (`$actualHash -eq `$shaFromFile) `"Package SHA-256 mismatch against .sha256. Expected `$shaFromFile, got `$actualHash.`"",
    "Assert-Condition (`$actualHash -eq `$ExpectedPackageSha256.ToLowerInvariant()) `"Package SHA-256 mismatch against expected build. Expected `$ExpectedPackageSha256, got `$actualHash.`"",
    "",
    "Expand-Archive -LiteralPath `$packagePath -DestinationPath `$runDir -Force",
    "`$exePath = Join-Path `$runDir 'PCBuildingLife.exe'",
    "Assert-Condition (Test-Path -LiteralPath `$exePath) `"Missing game EXE after extract: `$exePath`"",
    "",
    "`$os = Get-CimInstance Win32_OperatingSystem",
    "`$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1",
    "`$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1",
    "`$sessionJsonPath = Join-Path `$sessionDir (`"clean-machine-session-`$stamp.json`")",
    "[ordered]@{",
    "    product = 'PC Building Life'",
    "    version = '$Version'",
    "    package_sha256 = `$actualHash",
    "    package_source = if ([string]::IsNullOrWhiteSpace(`$PackageUrl)) { 'bundled' } else { 'url' }",
    "    package_url = if ([string]::IsNullOrWhiteSpace(`$PackageUrl)) { `$null } else { `$PackageUrl }",
    "    os_caption = `$os.Caption",
    "    os_version = `$os.Version",
    "    cpu = `$cpu.Name",
    "    gpu = `$gpu.Name",
    "    started_at_utc = [DateTime]::UtcNow.ToString('o')",
    "} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `$sessionJsonPath -Encoding UTF8",
    "",
    "Write-Host `"[clean-machine] launching `$exePath`"",
    "`$process = Start-Process -FilePath `$exePath -WorkingDirectory `$runDir -PassThru",
    "Wait-Process -Id `$process.Id",
    "",
    "`$reportPath = Join-Path `$kitRoot (`"CLEAN_MACHINE_REPORT_`$stamp.md`")",
    "Copy-Item -LiteralPath (Join-Path `$kitRoot 'CLEAN_MACHINE_REPORT_TEMPLATE.md') -Destination `$reportPath -Force",
    "Add-Content -LiteralPath `$reportPath -Encoding UTF8 -Value @(",
    "    '',",
    "    '## Automatic Session Evidence',",
    "    '',",
    "    `"- Session JSON: `$sessionJsonPath`",",
    "    `"- Package SHA-256 verified: `$actualHash`",",
    "    `"- Windows: `$(`$os.Caption) `$(`$os.Version)`",",
    "    `"- CPU: `$(`$cpu.Name)`",",
    "    `"- GPU: `$(`$gpu.Name)`"",
    ")",
    "Start-Process notepad.exe -ArgumentList `$reportPath | Out-Null",
    "Start-Process notepad.exe -ArgumentList (Join-Path `$kitRoot 'README_CLEAN_MACHINE_VALIDATION.txt') | Out-Null",
    "Write-Host `"[clean-machine] report=`$reportPath`""
)
$runnerPs1Lines | Set-Content -LiteralPath (Join-Path $kitDir 'RUN_CLEAN_MACHINE_VALIDATION.ps1') -Encoding UTF8

$runnerCmdLines = @(
    '@echo off',
    'setlocal',
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_CLEAN_MACHINE_VALIDATION.ps1"',
    'pause',
    'endlocal'
)
$runnerCmdLines | Set-Content -LiteralPath (Join-Path $kitDir 'RUN_CLEAN_MACHINE_VALIDATION.cmd') -Encoding ASCII

$manifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    kit_path = $kitDir
    kit_zip = $kitZipPath
    package_zip = "package/$(Split-Path -Leaf $playerZipPath)"
    package_sha256_file = "package/$(Split-Path -Leaf $playerShaPath)"
    package_sha256 = $packageHash
    exe_sha256 = [string]$packageAudit.exe_sha256
    player_flow_orders = [int]$packageAudit.player_flow_orders
    first_order_audit_order_name = [string]$packageAudit.first_order_audit_order_name
    first_order_audit_score = [int]$packageAudit.first_order_audit_score
    first_order_audit_grade = [string]$packageAudit.first_order_audit_grade
    public_package_url = if ([string]::IsNullOrWhiteSpace($publicPackageUrl)) { $null } else { $publicPackageUrl }
    public_sha256_url = if ([string]::IsNullOrWhiteSpace($publicShaUrl)) { $null } else { $publicShaUrl }
    runner_ps1 = 'RUN_CLEAN_MACHINE_VALIDATION.ps1'
    runner_cmd = 'RUN_CLEAN_MACHINE_VALIDATION.cmd'
    report_template = 'CLEAN_MACHINE_REPORT_TEMPLATE.md'
    created_at_utc = [DateTime]::UtcNow.ToString('o')
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$kitZipFullPath = [System.IO.Path]::GetFullPath($kitZipPath)
Assert-Condition ($kitZipFullPath.StartsWith($validationRootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing to write kit ZIP outside validation root: $kitZipFullPath"
if (Test-Path -LiteralPath $kitZipFullPath) {
    Remove-Item -LiteralPath $kitZipFullPath -Force
}
if (Test-Path -LiteralPath $kitShaPath) {
    Remove-Item -LiteralPath $kitShaPath -Force
}
$kitItems = @(Get-ChildItem -LiteralPath $kitDir -Force)
Assert-Condition ($kitItems.Count -gt 0) "Clean-machine validation kit directory is empty: $kitDir"
Compress-Archive -Path @($kitItems | ForEach-Object { $_.FullName }) -DestinationPath $kitZipFullPath -Force
$kitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $kitZipFullPath).Hash.ToLowerInvariant()
("{0}  {1}" -f $kitHash, (Split-Path -Leaf $kitZipFullPath)) | Set-Content -LiteralPath $kitShaPath -Encoding ASCII

Write-Host '[clean-machine-kit] ok'
Write-Host "[clean-machine-kit] $kitDir"
Write-Host "[clean-machine-kit] $kitZipFullPath"
Write-Host "[clean-machine-kit] package_sha256=$packageHash"
Write-Host "[clean-machine-kit] kit_sha256=$kitHash"
