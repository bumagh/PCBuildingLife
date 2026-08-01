[CmdletBinding()]
param(
    [string]$Version = '0.1.0-dev',
    [string]$ItchTarget,
    [string]$ConfigPath,
    [string]$Channel = 'windows-demo',
    [switch]$Push,
    [switch]$Hidden,
    [switch]$Public,
    [switch]$IfChanged,
    [switch]$SkipPackageAudit
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $projectDir '..'))
$buildDir = Join-Path $projectDir 'build\windows'
$itchRoot = Join-Path $projectDir 'build\itch'
$stageDir = Join-Path $itchRoot "PCBuildingLife-$Version"
$packageDir = Join-Path $stageDir 'package'
$docsDir = Join-Path $stageDir 'docs'
$mediaDir = Join-Path $stageDir 'media'

$zipPath = Join-Path $buildDir "PCBuildingLife-Windows-x64-$Version.zip"
$shaPath = "$zipPath.sha256"
$auditReportPath = Join-Path $buildDir 'release-package-audit-report.json'
$uploadManifestPath = Join-Path $projectDir "build\upload\PCBuildingLife-$Version\upload-manifest.json"
$docDir = Join-Path $repoRoot 'doc'
$stageManifestPath = Join-Path $stageDir 'itch-upload-manifest.json'
$commandPath = Join-Path $stageDir 'butler-command.txt'
$defaultLocalConfigPath = Join-Path $projectDir 'release\itch-upload-config.local.json'
$defaultExampleConfigPath = Join-Path $projectDir 'release\itch-upload-config.example.json'

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

function Get-ButlerPath {
    $command = Get-Command butler -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:APPDATA 'itch\apps\butler\butler.exe'),
        (Join-Path $env:LOCALAPPDATA 'itch\apps\butler\butler.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Format-CommandArg {
    param([string]$Value)
    return ('"{0}"' -f ($Value -replace '"', '\"'))
}

function Read-OptionalString {
    param(
        [object]$Config,
        [string]$Name,
        [string]$DefaultValue = ''
    )
    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains $Name -and $null -ne $Config.$Name) {
        return [string]$Config.$Name
    }
    return $DefaultValue
}

function Read-OptionalBool {
    param(
        [object]$Config,
        [string]$Name,
        [bool]$DefaultValue = $false
    )
    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains $Name -and $null -ne $Config.$Name) {
        return [bool]$Config.$Name
    }
    return $DefaultValue
}

$config = $null
$resolvedConfigPath = ''
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    if (Test-Path -LiteralPath $defaultLocalConfigPath) {
        $ConfigPath = $defaultLocalConfigPath
    }
    elseif (Test-Path -LiteralPath $defaultExampleConfigPath) {
        $ConfigPath = $defaultExampleConfigPath
    }
}
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    Assert-File $ConfigPath
    $resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
    $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedConfigPath | ConvertFrom-Json
    $verifyArgs = @{
        Version = $Version
        ConfigPath = $resolvedConfigPath
    }
    if (-not $Push) {
        $verifyArgs.AllowPlaceholder = $true
    }
    else {
        $verifyArgs.RequireTarget = $true
    }
    & (Join-Path $PSScriptRoot 'verify_itch_upload_config.ps1') @verifyArgs
}

if (-not $PSBoundParameters.ContainsKey('ItchTarget')) {
    $ItchTarget = Read-OptionalString -Config $config -Name 'itch_target'
    if ($ItchTarget -eq '<itch-user>/<itch-game>') {
        $ItchTarget = ''
    }
}
if (-not $PSBoundParameters.ContainsKey('Channel')) {
    $Channel = Read-OptionalString -Config $config -Name 'channel' -DefaultValue $Channel
}
$hiddenFlag = [bool]$Hidden
if ($PSBoundParameters.ContainsKey('Public')) {
    $hiddenFlag = $false
}
elseif (-not $PSBoundParameters.ContainsKey('Hidden')) {
    $hiddenFlag = Read-OptionalBool -Config $config -Name 'hidden' -DefaultValue ([bool]$Hidden)
}
$ifChangedFlag = [bool]$IfChanged
if (-not $PSBoundParameters.ContainsKey('IfChanged')) {
    $ifChangedFlag = Read-OptionalBool -Config $config -Name 'if_changed' -DefaultValue ([bool]$IfChanged)
}
Assert-Condition (-not ($Hidden -and $Public)) 'Use either -Hidden or -Public, not both.'

if (-not $SkipPackageAudit) {
    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') -PackagePath $zipPath -Sha256Path $shaPath -ReportPath $auditReportPath
}

foreach ($required in @($zipPath, $shaPath, $auditReportPath, $uploadManifestPath, $docDir)) {
    Assert-File $required
}

$resolvedItchRoot = [System.IO.Path]::GetFullPath($itchRoot)
$resolvedStageDir = [System.IO.Path]::GetFullPath($stageDir)
if (-not $resolvedStageDir.StartsWith($resolvedItchRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean stage path outside itch root: $resolvedStageDir"
}
if (Test-Path -LiteralPath $resolvedStageDir) {
    Remove-Item -LiteralPath $resolvedStageDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageDir, $docsDir, $mediaDir | Out-Null

Copy-RequiredFile -Source $zipPath -Destination (Join-Path $packageDir (Split-Path -Leaf $zipPath))
Copy-RequiredFile -Source $shaPath -Destination (Join-Path $packageDir (Split-Path -Leaf $shaPath))
Copy-RequiredFile -Source $auditReportPath -Destination (Join-Path $packageDir 'release-package-audit-report.json')
Copy-RequiredFile -Source $uploadManifestPath -Destination (Join-Path $stageDir 'upload-manifest.json')

$docSourceFiles = @(Get-ChildItem -LiteralPath $docDir -Filter '*.md' -File | Sort-Object Name)
Assert-Condition ($docSourceFiles.Count -gt 0) "No markdown docs found in $docDir"
foreach ($docFile in $docSourceFiles) {
    Copy-RequiredFile -Source $docFile.FullName -Destination (Join-Path $docsDir $docFile.Name)
}

$releaseMediaDir = Join-Path $projectDir 'release\media'
foreach ($fileName in @('cover-1920x1080.png', 'channel-header-1920x620.png', 'small-cover-630x500.png', 'contact-sheet.png', 'branding-sheet.png')) {
    Copy-RequiredFile -Source (Join-Path $releaseMediaDir $fileName) -Destination (Join-Path $mediaDir $fileName)
}

$audit = Get-Content -Raw -Encoding UTF8 -LiteralPath $auditReportPath | ConvertFrom-Json
$uploadManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $uploadManifestPath | ConvertFrom-Json
$butlerPath = Get-ButlerPath
$butlerAvailable = (-not [string]::IsNullOrWhiteSpace($butlerPath))
$packageInStage = Join-Path $packageDir (Split-Path -Leaf $zipPath)
$target = if ([string]::IsNullOrWhiteSpace($ItchTarget)) { '<itch-user>/<itch-game>' } else { $ItchTarget }
$publicPackageUrl = Read-OptionalString -Config $config -Name 'public_package_url'
$publicShaUrl = Read-OptionalString -Config $config -Name 'public_sha256_url'

$butlerArgs = [System.Collections.Generic.List[string]]::new()
$butlerArgs.Add('push')
$butlerArgs.Add((Format-CommandArg $packageInStage))
$butlerArgs.Add(("{0}:{1}" -f $target, $Channel))
$butlerArgs.Add('--userversion')
$butlerArgs.Add($Version)
if ($hiddenFlag) {
    $butlerArgs.Add('--hidden')
}
if ($ifChangedFlag) {
    $butlerArgs.Add('--if-changed')
}
$commandLine = "butler {0}" -f ($butlerArgs -join ' ')
$publicDownloadCommand = if (-not [string]::IsNullOrWhiteSpace($publicPackageUrl) -and -not [string]::IsNullOrWhiteSpace($publicShaUrl)) {
    "GodotVersion/scripts/verify_public_download.ps1 -PackageUrl $(Format-CommandArg $publicPackageUrl) -Sha256Url $(Format-CommandArg $publicShaUrl) -ExpectedPackageSha256 '$($audit.package_sha256)'"
}
else {
    "GodotVersion/scripts/verify_public_download.ps1 -PackageUrl '<ZIP URL>' -Sha256Url '<SHA-256 URL>' -ExpectedPackageSha256 '$($audit.package_sha256)'"
}

$commandLines = @(
    'PC Building Life itch.io butler upload command',
    '',
    'Login first:',
    'butler login',
    '',
    'Upload command:',
    $commandLine,
    '',
    'After upload, paste the public ZIP and SHA-256 URLs into:',
    $publicDownloadCommand
)
$commandLines | Set-Content -LiteralPath $commandPath -Encoding UTF8

$stageManifest = [ordered]@{
    product = 'PC Building Life'
    version = $Version
    stage_path = $resolvedStageDir
    config_path = if ([string]::IsNullOrWhiteSpace($resolvedConfigPath)) { $null } else { $resolvedConfigPath }
    itch_target = if ([string]::IsNullOrWhiteSpace($ItchTarget)) { $null } else { $ItchTarget }
    channel = $Channel
    hidden = $hiddenFlag
    if_changed = $ifChangedFlag
    package_zip = "package/$(Split-Path -Leaf $zipPath)"
    package_sha256_file = "package/$(Split-Path -Leaf $shaPath)"
    package_sha256 = [string]$audit.package_sha256
    package_size_bytes = [int64]$audit.package_size_bytes
    exe_sha256 = [string]$audit.exe_sha256
    exe_size_bytes = [int64]$audit.exe_size_bytes
    player_flow_orders = [int]$audit.player_flow_orders
    first_order_audit_order_name = [string]$audit.first_order_audit_order_name
    first_order_audit_score = [int]$audit.first_order_audit_score
    first_order_audit_grade = [string]$audit.first_order_audit_grade
    feedback_url = [string]$audit.feedback_url
    upload_bundle = [string]$uploadManifest.bundle_path
    doc_files = @($docSourceFiles | ForEach-Object { $_.Name })
    butler_available = $butlerAvailable
    butler_path = $butlerPath
    butler_command_file = 'butler-command.txt'
    public_package_url = if ([string]::IsNullOrWhiteSpace($publicPackageUrl)) { $null } else { $publicPackageUrl }
    public_sha256_url = if ([string]::IsNullOrWhiteSpace($publicShaUrl)) { $null } else { $publicShaUrl }
    push_requested = [bool]$Push
    pushed = $false
    butler_exit_code = $null
    pushed_at_utc = $null
    created_at_utc = [DateTime]::UtcNow.ToString('o')
}
$stageManifest | ConvertTo-Json | Set-Content -LiteralPath $stageManifestPath -Encoding UTF8

if ($Push) {
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($ItchTarget)) 'Push requires -ItchTarget or release/itch-upload-config.local.json with itch_target, for example akgstudio/pc-building-life.'
    Assert-Condition $butlerAvailable 'Push requires butler. Install itch.io butler or add it to PATH.'

    $pushArgs = @('push', $packageInStage, ("{0}:{1}" -f $ItchTarget, $Channel), '--userversion', $Version)
    if ($hiddenFlag) {
        $pushArgs += '--hidden'
    }
    if ($ifChangedFlag) {
        $pushArgs += '--if-changed'
    }

    $global:LASTEXITCODE = 0
    & $butlerPath @pushArgs
    $butlerExitCode = [int]$LASTEXITCODE
    $stageManifest['butler_exit_code'] = $butlerExitCode
    $stageManifest | ConvertTo-Json | Set-Content -LiteralPath $stageManifestPath -Encoding UTF8
    Assert-Condition ($butlerExitCode -eq 0) "butler push failed with exit code $butlerExitCode. itch-upload-manifest.json remains pushed=false."

    $stageManifest['pushed'] = $true
    $stageManifest['pushed_at_utc'] = [DateTime]::UtcNow.ToString('o')
    $stageManifest | ConvertTo-Json | Set-Content -LiteralPath $stageManifestPath -Encoding UTF8
}

Write-Host '[itch-upload] ok'
Write-Host "[itch-upload] $resolvedStageDir"
Write-Host "[itch-upload] butler_available=$butlerAvailable"
Write-Host "[itch-upload] command: $commandPath"
