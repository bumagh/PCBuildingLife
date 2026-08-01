[CmdletBinding()]
param(
    [string]$MediaDir = (Join-Path $PSScriptRoot '..\release\media')
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$mediaRoot = [System.IO.Path]::GetFullPath($MediaDir)
$items = @(
    @{ File = '01-main-menu.png'; Label = 'MAIN MENU' },
    @{ File = '02-workbench.png'; Label = 'WORKBENCH' },
    @{ File = '03-order-desk.png'; Label = 'ORDER DESK' },
    @{ File = '04-catalog-shop.png'; Label = 'COMPONENT MARKET' },
    @{ File = '05-catalog-inventory.png'; Label = 'INVENTORY' },
    @{ File = '06-task-center.png'; Label = 'TASK CENTER' },
    @{ File = '07-system-center.png'; Label = 'SYSTEM CENTER' },
    @{ File = '08-max-monitor.png'; Label = 'MAX MONITOR' },
    @{ File = '09-delivery-feedback.png'; Label = 'DELIVERY RESULT' }
)

foreach ($item in $items) {
    $sourcePath = Join-Path $mediaRoot $item.File
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Contact sheet source is missing: $sourcePath"
    }
}

$columns = 3
$cellWidth = 640
$imageHeight = 360
$labelHeight = 34
$width = $columns * $cellWidth
$height = 3 * ($imageHeight + $labelHeight)
$outputPath = Join-Path $mediaRoot 'contact-sheet.png'
$tempPath = Join-Path $mediaRoot 'contact-sheet.tmp.png'

$bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$font = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$labelBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 235, 244, 255))
$bandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 31, 50, 78))
$backgroundBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 5, 8, 20))

try {
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.FillRectangle($backgroundBrush, 0, 0, $width, $height)

    for ($index = 0; $index -lt $items.Count; $index++) {
        $column = $index % $columns
        $row = [Math]::Floor($index / $columns)
        $x = $column * $cellWidth
        $y = $row * ($imageHeight + $labelHeight)
        $sourcePath = Join-Path $mediaRoot $items[$index].File
        $source = [System.Drawing.Image]::FromFile($sourcePath)
        try {
            $graphics.DrawImage($source, $x, $y, $cellWidth, $imageHeight)
        }
        finally {
            $source.Dispose()
        }
        $graphics.FillRectangle($bandBrush, $x, $y + $imageHeight, $cellWidth, $labelHeight)
        $graphics.DrawString($items[$index].Label, $font, $labelBrush, $x + 14, $y + $imageHeight + 4)
    }

    $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $font.Dispose()
    $labelBrush.Dispose()
    $bandBrush.Dispose()
    $backgroundBrush.Dispose()
    $bitmap.Dispose()
}

Move-Item -LiteralPath $tempPath -Destination $outputPath -Force

$image = [System.Drawing.Image]::FromFile($outputPath)
try {
    if ($image.Width -ne $width -or $image.Height -ne $height) {
        throw "Unexpected contact sheet dimensions: $($image.Width)x$($image.Height)"
    }
}
finally {
    $image.Dispose()
}

Write-Host "[media] Contact sheet generated: $outputPath"
Write-Host "[media] Size: ${width}x${height}"
