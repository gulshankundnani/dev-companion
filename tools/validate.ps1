<#
.SYNOPSIS
  Validates the repo before sharing a change: SKILL.md frontmatter, marketplace/plugin manifests,
  version consistency, and (if available) `claude plugin validate`.
.EXAMPLE
  powershell -NoProfile -File tools\validate.ps1
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$errors = New-Object System.Collections.Generic.List[string]
$names = @{}

$market = Get-Content (Join-Path $root '.claude-plugin\marketplace.json') -Raw | ConvertFrom-Json
foreach ($entry in $market.plugins) {
    $dir = Join-Path $root ($entry.source -replace '^\./', '')
    $manifestPath = Join-Path $dir '.claude-plugin\plugin.json'
    if (-not (Test-Path $manifestPath)) { $errors.Add("$($entry.name): missing $manifestPath"); continue }
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.name -ne $entry.name) { $errors.Add("$($entry.name): plugin.json name '$($manifest.name)' differs") }
    if ($manifest.version -ne $entry.version) { $errors.Add("$($entry.name): version $($manifest.version) (plugin.json) vs $($entry.version) (marketplace)") }

    $skillsDir = Join-Path $dir 'skills'
    if (-not (Test-Path $skillsDir)) { continue }
    foreach ($skill in Get-ChildItem $skillsDir -Directory) {
        $md = Join-Path $skill.FullName 'SKILL.md'
        if (-not (Test-Path $md)) { $errors.Add("$($skill.Name): missing SKILL.md"); continue }
        $text = Get-Content $md -Raw
        $fm = [regex]::Match($text, '^---\r?\n(.*?)\r?\n---', 'Singleline')
        if (-not $fm.Success) { $errors.Add("$($skill.Name): no frontmatter"); continue }
        $name = [regex]::Match($fm.Groups[1].Value, '(?m)^name:\s*(.+)$').Groups[1].Value.Trim()
        $desc = [regex]::Match($fm.Groups[1].Value, '(?m)^description:\s*(.+)$').Groups[1].Value.Trim()
        if ($name -ne $skill.Name) { $errors.Add("$($skill.Name): frontmatter name '$name' must equal folder name") }
        if ($desc.Length -lt 40) { $errors.Add("$($skill.Name): description too short to trigger reliably") }
        if ($desc.Length -gt 1024) { $errors.Add("$($skill.Name): description over 1024 chars") }
        if ($names.ContainsKey($name)) { $errors.Add("${name}: duplicate skill name (also in $($names[$name]))") } else { $names[$name] = $entry.name }
        $lines = (Get-Content $md).Count
        if ($lines -gt 150) { Write-Warning "$($skill.Name): SKILL.md is $lines lines - move detail to references/ (token economy)" }
    }
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    & claude plugin validate $root
    if ($LASTEXITCODE -ne 0) { $errors.Add('claude plugin validate reported problems') }
    foreach ($entry in $market.plugins) {
        & claude plugin validate (Join-Path $root ($entry.source -replace '^\./', ''))
        if ($LASTEXITCODE -ne 0) { $errors.Add("claude plugin validate failed for $($entry.name)") }
    }
}

if ($errors.Count) { $errors | ForEach-Object { Write-Host "ERROR: $_" -ForegroundColor Red }; exit 1 }
Write-Host "OK: $($names.Count) skills in $($market.plugins.Count) plugins" -ForegroundColor Green
