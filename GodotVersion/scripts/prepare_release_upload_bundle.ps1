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
$channelPagePath = Join-Path $projectDir 'release\channel_page\index.html'
$docDir = Join-Path $repoRoot 'doc'
$uploadRoot = Join-Path $projectDir 'build\upload'
$bundleDir = Join-Path $uploadRoot "PCBuildingLife-$Version"
$packageDir = Join-Path $bundleDir 'package'
$mediaOutDir = Join-Path $bundleDir 'media'
$docsOutDir = Join-Path $bundleDir 'docs'

$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$manifestPath = Join-Path $buildDir 'release-manifest.json'
$auditReportPath = Join-Path $buildDir 'release-package-audit-report.json'
$readmePath = Join-Path $buildDir 'README.txt'
$releaseNotesPath = Join-Path $buildDir 'RELEASE_NOTES.md'
$uploadManifestPath = Join-Path $bundleDir 'upload-manifest.json'
$uploadReadmePath = Join-Path $bundleDir 'README_UPLOAD.md'

function Assert-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }
}

function Copy-RequiredFile {
    param(
        [string]$Source,
        [string]$Destination
    )
    Assert-File $Source
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Replace-RequiredRegex {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Name
    )

    if (-not [regex]::IsMatch($Text, $Pattern)) {
        throw "Could not update landing page field: $Name"
    }
    return [regex]::Replace($Text, $Pattern, { param($match) $Replacement })
}

if (-not $SkipPackageAudit) {
    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') -PackagePath $zipPath -Sha256Path $shaPath -ReportPath $auditReportPath
}

foreach ($required in @($zipPath, $shaPath, $manifestPath, $auditReportPath, $readmePath, $releaseNotesPath)) {
    Assert-File $required
}
Assert-File $channelPagePath

$resolvedUploadRoot = [System.IO.Path]::GetFullPath($uploadRoot)
$resolvedBundleDir = [System.IO.Path]::GetFullPath($bundleDir)
if (-not $resolvedBundleDir.StartsWith($resolvedUploadRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean bundle path outside upload root: $resolvedBundleDir"
}
if (Test-Path -LiteralPath $resolvedBundleDir) {
    Remove-Item -LiteralPath $resolvedBundleDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageDir, $mediaOutDir, $docsOutDir | Out-Null

Copy-RequiredFile -Source $zipPath -Destination (Join-Path $packageDir (Split-Path -Leaf $zipPath))
Copy-RequiredFile -Source $shaPath -Destination (Join-Path $packageDir (Split-Path -Leaf $shaPath))
Copy-RequiredFile -Source $manifestPath -Destination (Join-Path $packageDir 'release-manifest.json')
Copy-RequiredFile -Source $auditReportPath -Destination (Join-Path $packageDir 'release-package-audit-report.json')
Copy-RequiredFile -Source $readmePath -Destination (Join-Path $packageDir 'README.txt')
Copy-RequiredFile -Source $releaseNotesPath -Destination (Join-Path $packageDir 'RELEASE_NOTES.md')

$mediaFiles = @(
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
    'branding-sheet.png',
    'README.md'
)
foreach ($fileName in $mediaFiles) {
    Copy-RequiredFile -Source (Join-Path $mediaDir $fileName) -Destination (Join-Path $mediaOutDir $fileName)
}

$docSourceFiles = @(Get-ChildItem -LiteralPath $docDir -Filter '*.md' -File | Sort-Object Name)
if ($docSourceFiles.Count -eq 0) {
    throw "No markdown docs found in $docDir"
}
foreach ($docFile in $docSourceFiles) {
    Copy-RequiredFile -Source $docFile.FullName -Destination (Join-Path $docsOutDir $docFile.Name)
}

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$audit = Get-Content -Raw -Encoding UTF8 -LiteralPath $auditReportPath | ConvertFrom-Json
$zipFile = Get-Item -LiteralPath $zipPath

$channelHtml = Get-Content -Raw -Encoding UTF8 -LiteralPath $channelPagePath
$zipLeaf = Split-Path -Leaf $zipPath
$shaLeaf = Split-Path -Leaf $shaPath
$zipSizeText = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:N0} bytes', $zipFile.Length)
$channelHtml = Replace-RequiredRegex -Text $channelHtml -Pattern 'package/PCBuildingLife-Windows-x64-[^"]+\.zip\.sha256' -Replacement "package/$shaLeaf" -Name 'ZIP SHA link'
$channelHtml = Replace-RequiredRegex -Text $channelHtml -Pattern 'package/PCBuildingLife-Windows-x64-[^"]+\.zip' -Replacement "package/$zipLeaf" -Name 'ZIP link'
$zipSizePattern = '(<div><span>[^<]+</span><strong>Windows x86_64</strong></div>\s*<div><span>[^<]+</span><strong>)[^<]+(</strong></div>)'
if (-not [regex]::IsMatch($channelHtml, $zipSizePattern)) {
    throw 'Could not update landing page field: ZIP size'
}
$channelHtml = [regex]::Replace(
    $channelHtml,
    $zipSizePattern,
    { param($match) "$($match.Groups[1].Value)$zipSizeText$($match.Groups[2].Value)" }
)
$hashBlockReplacement = @"
<span>ZIP SHA-256</span>
          <code>$($audit.package_sha256)</code>
          <span>EXE SHA-256</span>
          <code>$($audit.exe_sha256)</code>
"@
$channelHtml = Replace-RequiredRegex -Text $channelHtml -Pattern '<span>ZIP SHA-256</span>\s*<code>[0-9a-f]{64}</code>\s*<span>EXE SHA-256</span>\s*<code>[0-9a-f]{64}</code>' -Replacement $hashBlockReplacement.TrimEnd() -Name 'SHA block'
$channelHtml | Set-Content -LiteralPath (Join-Path $bundleDir 'index.html') -Encoding UTF8

$uploadReadmeLines = [System.Collections.Generic.List[string]]::new()
$uploadReadmeLines.Add(("PC Building Life {0} Upload Bundle" -f $Version))
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("Package files")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add(("- package/PCBuildingLife-Windows-x64-{0}.zip" -f $Version))
$uploadReadmeLines.Add(("- package/PCBuildingLife-Windows-x64-{0}.zip.sha256" -f $Version))
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("Media")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("- Cover: media/cover-1920x1080.png")
$uploadReadmeLines.Add("- Channel header: media/channel-header-1920x620.png")
$uploadReadmeLines.Add("- Small cover: media/small-cover-630x500.png")
$uploadReadmeLines.Add("- Screenshots: media/01-main-menu.png through media/09-delivery-feedback.png")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("Page copy and docs")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("- Use docs/channel page draft, privacy note, license note, and release checklist.")
$uploadReadmeLines.Add("- All markdown files from doc/ are copied into docs/ for upload preparation.")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("Verification")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add(("- ZIP SHA-256: {0}" -f $audit.package_sha256))
$uploadReadmeLines.Add(("- EXE SHA-256: {0}" -f $audit.exe_sha256))
$uploadReadmeLines.Add(("- ZIP size: {0}" -f $zipSizeText))
$uploadReadmeLines.Add(("- Player flow orders passed: {0}" -f $audit.player_flow_orders))
$uploadReadmeLines.Add(("- First-order audit: {0} {1} / {2}" -f $audit.first_order_audit_order_name, $audit.first_order_audit_score, $audit.first_order_audit_grade))
$uploadReadmeLines.Add(("- Feedback URL: {0}" -f $audit.feedback_url))
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("External acceptance")
$uploadReadmeLines.Add("")
$uploadReadmeLines.Add("After upload, download the ZIP from the real public page or use another clean Windows machine, then extract, launch, finish the first order, save, and write the result back to doc/release checklist.")
$uploadReadme = $uploadReadmeLines -join [Environment]::NewLine
$uploadReadme | Set-Content -LiteralPath $uploadReadmePath -Encoding UTF8

$bundleManifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    bundle_path = $resolvedBundleDir
    package_zip = "package/$(Split-Path -Leaf $zipPath)"
    package_sha256_file = "package/$(Split-Path -Leaf $shaPath)"
    landing_page = 'index.html'
    package_sha256 = [string]$audit.package_sha256
    package_size_bytes = [int64]$zipFile.Length
    exe_sha256 = [string]$audit.exe_sha256
    exe_size_bytes = [int64]$audit.exe_size_bytes
    release_manifest_tests = [string]$manifest.tests
    launch_smoke = [string]$manifest.launch_smoke
    clean_extract_smoke = [string]$manifest.clean_extract_smoke
    player_flow_orders = [int]$audit.player_flow_orders
    first_order_audit_order_name = [string]$audit.first_order_audit_order_name
    first_order_audit_score = [int]$audit.first_order_audit_score
    first_order_audit_grade = [string]$audit.first_order_audit_grade
    feedback_url = [string]$audit.feedback_url
    media_files = $mediaFiles
    doc_files = @($docSourceFiles | ForEach-Object { $_.Name })
    created_at_utc = [DateTime]::UtcNow.ToString('o')
}
$bundleManifest | ConvertTo-Json | Set-Content -LiteralPath $uploadManifestPath -Encoding UTF8

Write-Host '[upload-bundle] ok'
Write-Host "[upload-bundle] $resolvedBundleDir"
