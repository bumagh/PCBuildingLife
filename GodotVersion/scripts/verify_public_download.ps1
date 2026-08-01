[CmdletBinding(DefaultParameterSetName = 'Local')]
param(
    [Parameter(ParameterSetName = 'Remote', Mandatory = $true)]
    [string]$PackageUrl,

    [Parameter(ParameterSetName = 'Remote')]
    [string]$Sha256Url,

    [Parameter(ParameterSetName = 'Local')]
    [string]$PackagePath,

    [Parameter(ParameterSetName = 'Local')]
    [string]$Sha256Path,

    [string]$ExpectedPackageSha256,
    [string]$ExpectedIssuesUrl = 'https://github.com/bumagh/PCBuildingLife/issues',
    [int]$SmokeSeconds = 4,
    [string]$WorkDir,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$defaultOutputDir = Join-Path $projectDir 'build\windows'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $defaultOutputDir 'public-download-audit-report.json'
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

function Get-UrlFileName {
    param(
        [string]$Url,
        [string]$Fallback
    )

    try {
        $uri = [System.Uri]::new($Url)
        $name = [System.IO.Path]::GetFileName($uri.AbsolutePath)
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            return $name
        }
    }
    catch {
    }
    return $Fallback
}

function Save-RemoteFile {
    param(
        [string]$Url,
        [string]$Destination
    )

    Write-Host "[public-download] Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    Assert-Condition (Test-Path -LiteralPath $Destination) "Downloaded file is missing: $Destination"
}

function Write-ShaFile {
    param(
        [string]$Destination,
        [string]$Hash,
        [string]$PackageName
    )

    Assert-Condition ($Hash -match '^[0-9a-fA-F]{64}$') "ExpectedPackageSha256 is not a SHA-256 value: $Hash"
    ("{0}  {1}" -f $Hash.ToLowerInvariant(), $PackageName) | Set-Content -LiteralPath $Destination -Encoding ASCII
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$defaultTempBase = [System.IO.Path]::GetFullPath((Join-Path $projectDir 'build\temp'))
$cleanupWorkDir = $false
if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    New-Item -ItemType Directory -Force -Path $defaultTempBase | Out-Null
    $tempBase = $defaultTempBase
    $WorkDir = Join-Path $tempBase "PCBuildingLife-public-download-$([Guid]::NewGuid().ToString('N'))"
    $cleanupWorkDir = $true
}

$resolvedWorkDir = [System.IO.Path]::GetFullPath($WorkDir)
if ($cleanupWorkDir) {
    Assert-Condition ($resolvedWorkDir.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) "Refusing temp path outside temp base: $resolvedWorkDir"
}
New-Item -ItemType Directory -Force -Path $resolvedWorkDir | Out-Null

$downloadDir = Join-Path $resolvedWorkDir 'download'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$publicReportPath = [System.IO.Path]::GetFullPath($ReportPath)
$publicReportDir = Split-Path -Parent $publicReportPath
if ([string]::IsNullOrWhiteSpace($publicReportDir)) {
    $publicReportDir = [System.IO.Path]::GetFullPath('.')
}
New-Item -ItemType Directory -Force -Path $publicReportDir | Out-Null
$auditReportPath = Join-Path $publicReportDir 'public-download-package-audit-report.json'

$downloadedPackagePath = $null
$downloadedShaPath = $null
$sourceKind = $PSCmdlet.ParameterSetName

try {
    if ($sourceKind -eq 'Remote') {
        $packageFileName = Get-UrlFileName -Url $PackageUrl -Fallback 'PCBuildingLife-Windows-x64-0.1.0-dev.zip'
        $downloadedPackagePath = Join-Path $downloadDir $packageFileName
        Save-RemoteFile -Url $PackageUrl -Destination $downloadedPackagePath

        if (-not [string]::IsNullOrWhiteSpace($Sha256Url)) {
            $shaFileName = Get-UrlFileName -Url $Sha256Url -Fallback "$packageFileName.sha256"
            $downloadedShaPath = Join-Path $downloadDir $shaFileName
            Save-RemoteFile -Url $Sha256Url -Destination $downloadedShaPath
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) {
            $downloadedShaPath = Join-Path $downloadDir "$packageFileName.sha256"
            Write-ShaFile -Destination $downloadedShaPath -Hash $ExpectedPackageSha256 -PackageName $packageFileName
        }
        else {
            throw 'Remote verification needs -Sha256Url or -ExpectedPackageSha256.'
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($PackagePath)) {
            $PackagePath = Join-Path $defaultOutputDir 'PCBuildingLife-Windows-x64-0.1.0-dev.zip'
        }
        if ([string]::IsNullOrWhiteSpace($Sha256Path)) {
            $Sha256Path = "$PackagePath.sha256"
        }

        $sourcePackagePath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PackagePath))
        $sourceShaPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Sha256Path))
        $downloadedPackagePath = Join-Path $downloadDir (Split-Path -Leaf $sourcePackagePath)
        $downloadedShaPath = Join-Path $downloadDir (Split-Path -Leaf $sourceShaPath)
        Copy-Item -LiteralPath $sourcePackagePath -Destination $downloadedPackagePath -Force
        Copy-Item -LiteralPath $sourceShaPath -Destination $downloadedShaPath -Force
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $downloadedPackagePath).Hash.ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($ExpectedPackageSha256)) {
        Assert-Condition ($actualHash -eq $ExpectedPackageSha256.ToLowerInvariant()) "Public package SHA-256 mismatch. Expected $ExpectedPackageSha256, got $actualHash."
    }

    & (Join-Path $PSScriptRoot 'verify_release_package.ps1') `
        -PackagePath $downloadedPackagePath `
        -Sha256Path $downloadedShaPath `
        -ExpectedIssuesUrl $ExpectedIssuesUrl `
        -SmokeSeconds $SmokeSeconds `
        -ReportPath $auditReportPath

    $audit = Get-Content -Raw -Encoding UTF8 -LiteralPath $auditReportPath | ConvertFrom-Json
    $report = [ordered]@{
        ok = $true
        source = $sourceKind.ToLowerInvariant()
        package_url = if ($sourceKind -eq 'Remote') { $PackageUrl } else { $null }
        sha256_url = if ($sourceKind -eq 'Remote') { $Sha256Url } else { $null }
        download_artifacts_retained = (-not $cleanupWorkDir)
        work_dir = if ($cleanupWorkDir) { $null } else { $resolvedWorkDir }
        downloaded_package = if ($cleanupWorkDir) { $null } else { $downloadedPackagePath }
        downloaded_sha256_file = if ($cleanupWorkDir) { $null } else { $downloadedShaPath }
        package_sha256 = $actualHash
        package_size_bytes = (Get-Item -LiteralPath $downloadedPackagePath).Length
        exe_sha256 = [string]$audit.exe_sha256
        exe_size_bytes = [int64]$audit.exe_size_bytes
        player_flow_orders = [int]$audit.player_flow_orders
        first_order_audit_order_name = [string]$audit.first_order_audit_order_name
        first_order_audit_score = [int]$audit.first_order_audit_score
        first_order_audit_grade = [string]$audit.first_order_audit_grade
        feedback_url = $ExpectedIssuesUrl
        smoke_seconds = $SmokeSeconds
        package_audit_report = $auditReportPath
        checked_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $report | ConvertTo-Json | Set-Content -LiteralPath $publicReportPath -Encoding UTF8

    Write-Host '[public-download] ok'
    Write-Host "[public-download] report: $publicReportPath"
}
finally {
    if ($cleanupWorkDir -and (Test-Path -LiteralPath $resolvedWorkDir)) {
        $checkPath = [System.IO.Path]::GetFullPath($resolvedWorkDir)
        if ($checkPath.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $checkPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
