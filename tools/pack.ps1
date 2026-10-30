<#
.SYNOPSIS
  Builds dist\dev-companion-<version>.zip for sharing. Recipients follow INSTALL.md inside the zip.
.EXAMPLE
  powershell -NoProfile -File tools\pack.ps1
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$version = (Get-Content (Join-Path $root '.claude-plugin\marketplace.json') -Raw | ConvertFrom-Json).metadata.version
$dist = Join-Path $root 'dist'
$zip = Join-Path $dist "dev-companion-$version.zip"

# Stage a clean copy so dist/, .git and local files never end up in the zip
$stage = Join-Path ([IO.Path]::GetTempPath()) "dev-companion-$version"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -Confirm:$false }
New-Item -ItemType Directory -Force -Path $stage, $dist | Out-Null

$exclude = @('dist', '.git', '.vs', '.claude')
Get-ChildItem $root -Force | Where-Object { $exclude -notcontains $_.Name } |
    ForEach-Object { Copy-Item $_.FullName (Join-Path $stage $_.Name) -Recurse -Force }

if (Test-Path $zip) { Remove-Item $zip -Force -Confirm:$false }
# Write entries with '/' separators: Compress-Archive on PowerShell 5.1 uses '\', which breaks extraction on macOS/Linux
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($file in Get-ChildItem $stage -Recurse -File -Force) {
        $entry = $file.FullName.Substring($stage.Length).TrimStart('\', '/') -replace '\\', '/'
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entry) | Out-Null
    }
} finally { $archive.Dispose() }
Remove-Item $stage -Recurse -Force -Confirm:$false

Write-Output "Created $zip ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
