[CmdletBinding()]
param(
    [string]$GodotProjectDir,
    [string]$ReferenceRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($GodotProjectDir)) {
    $GodotProjectDir = Join-Path $PSScriptRoot '..'
}
$GodotProjectDir = [System.IO.Path]::GetFullPath($GodotProjectDir)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $GodotProjectDir '..'))
if ([string]::IsNullOrWhiteSpace($ReferenceRoot)) {
    $ReferenceRoot = Join-Path $repoRoot 'ReferenceAssets\PC_Creator2'
}
$ReferenceRoot = [System.IO.Path]::GetFullPath($ReferenceRoot)

$godotReferenceRoot = Join-Path $GodotProjectDir 'assets\pc_creator2'
$legacyArchiveRoot = Join-Path $ReferenceRoot 'legacy_godot_project_copy'

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

Assert-Condition (Test-Path -LiteralPath $GodotProjectDir -PathType Container) "Godot project not found: $GodotProjectDir"
Assert-Condition (Test-Path -LiteralPath $ReferenceRoot -PathType Container) "Reference archive not found: $ReferenceRoot"
Assert-Condition (Test-Path -LiteralPath $godotReferenceRoot -PathType Container) "Godot reference pointer not found: $godotReferenceRoot"
Assert-Condition (Test-Path -LiteralPath (Join-Path $godotReferenceRoot '.gdignore') -PathType Leaf) 'Godot reference pointer must contain .gdignore.'
Assert-Condition (Test-Path -LiteralPath (Join-Path $godotReferenceRoot 'README.md') -PathType Leaf) 'Godot reference pointer must contain README.md.'

$allowedPointerFiles = @('.gdignore', 'README.md')
$unexpectedPointerFiles = @(Get-ChildItem -LiteralPath $godotReferenceRoot -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring($godotReferenceRoot.Length).TrimStart('\')
    $allowedPointerFiles -notcontains $relativePath
})
Assert-Condition ($unexpectedPointerFiles.Count -eq 0) "Competitor files remain inside the Godot project: $($unexpectedPointerFiles.FullName -join ', ')"

$canonicalPngFiles = @(Get-ChildItem -LiteralPath $ReferenceRoot -Recurse -File -Filter '*.png' | Where-Object {
    -not $_.FullName.StartsWith($legacyArchiveRoot, [System.StringComparison]::OrdinalIgnoreCase)
})
$legacyPngFiles = @(Get-ChildItem -LiteralPath $legacyArchiveRoot -Recurse -File -Filter '*.png')
Assert-Condition ($canonicalPngFiles.Count -gt 0) 'Canonical competitor reference archive contains no PNG files.'
Assert-Condition ($legacyPngFiles.Count -eq $canonicalPngFiles.Count) "Legacy archive count mismatch: canonical=$($canonicalPngFiles.Count), legacy=$($legacyPngFiles.Count)."

foreach ($legacyFile in $legacyPngFiles) {
    $relativePath = $legacyFile.FullName.Substring($legacyArchiveRoot.Length).TrimStart('\')
    $canonicalPath = Join-Path $ReferenceRoot $relativePath
    Assert-Condition (Test-Path -LiteralPath $canonicalPath -PathType Leaf) "Canonical reference missing for legacy file: $relativePath"
    $legacyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $legacyFile.FullName).Hash
    $canonicalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $canonicalPath).Hash
    Assert-Condition ($legacyHash -eq $canonicalHash) "Reference hash mismatch: $relativePath"
}

$runtimeExtensions = @('.cfg', '.gd', '.ini', '.json', '.tscn', '.tres')
$runtimeRoots = @('assets', 'autoload', 'data', 'scenes', 'scripts')
$runtimeFiles = @()
foreach ($relativeRoot in $runtimeRoots) {
    $root = Join-Path $GodotProjectDir $relativeRoot
    if (Test-Path -LiteralPath $root -PathType Container) {
        $runtimeFiles += Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
            $runtimeExtensions -contains $_.Extension.ToLowerInvariant() -and
            -not $_.FullName.StartsWith($godotReferenceRoot, [System.StringComparison]::OrdinalIgnoreCase)
        }
    }
}
$projectSettingsPath = Join-Path $GodotProjectDir 'project.godot'
if (Test-Path -LiteralPath $projectSettingsPath -PathType Leaf) {
    $runtimeFiles += Get-Item -LiteralPath $projectSettingsPath
}
$runtimeReferences = @($runtimeFiles | Select-String -SimpleMatch 'res://assets/pc_creator2')
Assert-Condition ($runtimeReferences.Count -eq 0) "Runtime references competitor assets: $($runtimeReferences.Path -join ', ')"

Write-Host '[reference-assets] ok'
Write-Host "[reference-assets] canonical_pngs=$($canonicalPngFiles.Count) legacy_pngs=$($legacyPngFiles.Count)"
Write-Host '[reference-assets] godot_pointer_files=2 runtime_references=0'
