<#
.SYNOPSIS
  Turns <device>.usage.json (from collect-usage.ps1) into small Usage Hub documents:
  one per device and month (collection "usage", id <DEVICE>~<YYYY-MM>), each holding rows keyed by app+project+day.
  Rows already in the hub (downloaded to -ExistingDir) are kept and upserted by key, so days whose
  transcripts were since deleted stay in the hub. No prompt text is ever written.
  Prints the ArtifactData batch "writes" array (JSON) to pass as is. -Versions pins existing documents
  (ArtifactData refuses an unpinned write to a document that exists).
.EXAMPLE
  powershell -NoProfile -File hub-rows.ps1 -InFile "$env:LOCALAPPDATA\companion-analytics\$env:COMPUTERNAME.usage.json" -ExistingDir "$env:LOCALAPPDATA\companion-analytics\hub-existing" -Versions "PC1~2026-10=3,PC1~2026-09=1"
#>
param(
    [Parameter(Mandatory = $true)][string]$InFile,
    [string]$ExistingDir,
    [string]$Versions,
    [string]$OutDir = (Join-Path (Split-Path $InFile -Parent) 'hub-out')
)
$ErrorActionPreference = 'Stop'
# Relative weights in input-token equivalents (not dollar prices)
$W = @{ inp = 1.0; cw = 1.25; cr = 0.1; out = 5.0 }
function Weighted($o) { $W.inp * $o.input + $W.cw * $o.cacheWrite + $W.cr * $o.cacheRead + $W.out * $o.output }
function SafeId($s) { ($s -replace '[^A-Za-z0-9_.~-]', '_') }

$d = [IO.File]::ReadAllText($InFile) | ConvertFrom-Json
$device = $d.device
$rows = @{}
foreach ($s in $d.sessions) {
    $app = if ($s.entrypoint) { $s.entrypoint } else { 'unknown' }
    # Day = session start date (UTC)
    $day = $s.start.Substring(0, 10)
    $key = "$app|$($s.project)|$day"
    if (-not $rows.ContainsKey($key)) {
        $rows[$key] = [ordered]@{ device = $device; collectedAt = $d.collectedAt; app = $app; project = $s.project; day = $day
            sessions = 0; calls = 0; input = 0L; cacheWrite = 0L; cacheRead = 0L; output = 0L; cost = 0.0
            styles = [ordered]@{}; compact = New-Object System.Collections.ArrayList }
    }
    $r = $rows[$key]
    $cost = Weighted $s
    $r.sessions++; $r.calls += $s.calls; $r.input += $s.input; $r.cacheWrite += $s.cacheWrite; $r.cacheRead += $s.cacheRead; $r.output += $s.output; $r.cost += $cost

    # Prompt style buckets hold sums, so they merge across rows (avg = sum / n)
    foreach ($p in $s.prompts) {
        if ($p.slash) { continue }
        $sig = [int]$p.hasPath + [int]$p.hasCode + [int]$p.hasError + [int]$p.hasCriteria
        $style = if ($p.words -ge 40 -or $sig -ge 2) { 'detailed' } elseif ($p.words -lt 15 -and $sig -eq 0) { 'short' } else { 'medium' }
        if (-not $r.styles.Contains($style)) { $r.styles[$style] = [ordered]@{ n = 0; calls = 0; cost = 0.0; corr = 0 } }
        $b = $r.styles[$style]
        $b.n++; $b.calls += $p.calls; $b.cost += (Weighted $p); if ($p.nextIsCorrection) { $b.corr++ }
    }
    if ($s.callsOverCompact -ge 10) {
        [void]$r.compact.Add([ordered]@{ sid = $s.id.Substring(0, 8); start = $s.start; calls = $s.calls; over = $s.callsOverCompact
            peak = $s.peakContext; saved = [math]::Round($W.cr * $s.estCompactSavedCacheRead); cost = [math]::Round($cost) })
    }
}
foreach ($r in $rows.Values) {
    $r.cost = [math]::Round($r.cost)
    foreach ($b in $r.styles.Values) { $b.cost = [math]::Round($b.cost) }
    $r.compact = @($r.compact)
}

$ver = @{}
if ($Versions) { foreach ($p in $Versions -split '[,\s]+') { if ($p -match '^(.+)=(\d+)$') { $ver[$Matches[1]] = [long]$Matches[2] } } }

# One document per month, merged with what the hub already holds
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$writes = New-Object System.Collections.ArrayList
foreach ($m in $rows.Values | Group-Object { $_.day.Substring(0, 7) }) {
    $id = SafeId "$device~$($m.Name)"
    $merged = [ordered]@{}
    # ArtifactData saves "~" in an id as "@" in the file name
    $ex = if ($ExistingDir) { Get-ChildItem $ExistingDir -Recurse -Filter "$($id.Replace('~', '@')).json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($ex) {
        $e = [IO.File]::ReadAllText($ex.FullName) | ConvertFrom-Json
        foreach ($r in @($e.rows)) { if ($r) { $merged["$($r.app)|$($r.project)|$($r.day)"] = $r } }
    }
    foreach ($r in $m.Group) { $merged["$($r.app)|$($r.project)|$($r.day)"] = $r }
    $doc = [ordered]@{ device = $device; month = $m.Name; collectedAt = $d.collectedAt
        weights = 'input 1, cache write 1.25, cache read 0.1, output 5 (relative, not prices)'
        rows = @($merged.Values | Sort-Object { $_.day }, { $_.app }, { $_.project }) }
    $path = Join-Path $OutDir "$id.json"
    [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 6 -Compress), (New-Object Text.UTF8Encoding($false)))
    $w = [ordered]@{ op = 'set'; collection = 'usage'; doc_id = $id; file_path = $path }
    if ($ver.ContainsKey($id)) { $w.if_version = $ver[$id] }
    [void]$writes.Add([pscustomobject]$w)
}
ConvertTo-Json @($writes) -Depth 3 -Compress
