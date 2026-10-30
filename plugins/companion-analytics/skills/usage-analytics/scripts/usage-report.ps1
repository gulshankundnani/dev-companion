<#
.SYNOPSIS
  Merges every <device>.usage.json in -InDir (written by collect-usage.ps1) into a markdown report.
.EXAMPLE
  powershell -NoProfile -File usage-report.ps1 -InDir "$env:OneDrive\ClaudeUsage"
#>
param(
    [Parameter(Mandatory = $true)][string]$InDir,
    [string]$OutFile = (Join-Path $InDir 'usage-report.md'),
    [string]$Since,
    [int]$Top = 10
)
$ErrorActionPreference = 'Stop'
# Relative weights in input-token equivalents (not dollar prices)
$W = @{ inp = 1.0; cw = 1.25; cr = 0.1; out = 5.0 }
function Weighted($o) { $W.inp * $o.input + $W.cw * $o.cacheWrite + $W.cr * $o.cacheRead + $W.out * $o.output }
function Fmt($n) { if ($n -ge 1e9) { '{0:N2}B' -f ($n / 1e9) } elseif ($n -ge 1e6) { '{0:N1}M' -f ($n / 1e6) } elseif ($n -ge 1e3) { '{0:N0}k' -f ($n / 1e3) } else { '{0:N0}' -f $n } }
function Pct($a, $b) { if ($b) { '{0:N0}%' -f (100.0 * $a / $b) } else { '-' } }
function Row { '| ' + ($args -join ' | ') + ' |' }

$sessions = New-Object System.Collections.ArrayList
foreach ($f in Get-ChildItem $InDir -Filter *.usage.json -File) {
    $d = [IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json
    foreach ($s in $d.sessions) {
        if ($Since -and $s.end.Substring(0, 10) -lt $Since) { continue }
        $s | Add-Member device $d.device -Force
        $s | Add-Member cost (Weighted $s) -Force
        $s | Add-Member tokens ($s.input + $s.cacheWrite + $s.cacheRead + $s.output) -Force
        [void]$sessions.Add($s)
    }
}
if (-not $sessions.Count) { throw "No sessions found in $InDir (*.usage.json)" }
$allCost = ($sessions | Measure-Object cost -Sum).Sum
$md = New-Object System.Collections.Generic.List[string]
$from = ($sessions | Sort-Object start | Select-Object -First 1).start.Substring(0, 10)
$to = ($sessions | Sort-Object end | Select-Object -Last 1).end.Substring(0, 10)
$md.Add("# Claude Code usage report"); $md.Add('')
$md.Add("$($sessions.Count) sessions, $from to $to, devices: $((@($sessions.device | Sort-Object -Unique)) -join ', '). Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
$md.Add('')
$md.Add('**Cost** = relative weight in input-token equivalents: input x1, cache write x1.25, cache read x0.1, output x5. These are relative weights, not dollar prices; on a Team subscription there is no per-token bill, but the same weights roughly track how fast plan limits are used.')

function Group-Table($title, $keyFn, $keyName) {
    $md.Add(''); $md.Add("## $title"); $md.Add('')
    $md.Add((Row $keyName 'Sessions' 'Calls' 'Input' 'Cache write' 'Cache read' 'Output' 'Cost' 'Share'))
    $md.Add('|---|--:|--:|--:|--:|--:|--:|--:|--:|')
    $groups = $sessions | Group-Object $keyFn | ForEach-Object {
        $g = $_.Group
        [pscustomobject]@{ k = $_.Name; n = $g.Count; calls = ($g | Measure-Object calls -Sum).Sum
            input = ($g | Measure-Object input -Sum).Sum; cacheWrite = ($g | Measure-Object cacheWrite -Sum).Sum
            cacheRead = ($g | Measure-Object cacheRead -Sum).Sum; output = ($g | Measure-Object output -Sum).Sum
            cost = ($g | Measure-Object cost -Sum).Sum }
    } | Sort-Object cost -Descending
    foreach ($r in $groups) { $md.Add((Row $r.k $r.n $r.calls (Fmt $r.input) (Fmt $r.cacheWrite) (Fmt $r.cacheRead) (Fmt $r.output) (Fmt $r.cost) (Pct $r.cost $allCost))) }
}
Group-Table 'Per device' { $_.device } 'Device'
Group-Table 'Per device and app' { "$($_.device) / $($_.entrypoint)" } 'Device / app'
Group-Table 'Per project' { "$($_.device) / $($_.project)" } 'Device / project'

$md.Add(''); $md.Add("## Top $Top sessions by cost"); $md.Add('')
$md.Add((Row 'Device' 'Project' 'Start' 'Prompts' 'Calls' 'Peak context' 'Cache read share' 'Cost'))
$md.Add('|---|---|---|--:|--:|--:|--:|--:|')
foreach ($s in $sessions | Sort-Object cost -Descending | Select-Object -First $Top) {
    $md.Add((Row $s.device $s.project $s.start.Substring(0, 10) @($s.prompts).Count $s.calls (Fmt $s.peakContext) (Pct $s.cacheRead $s.tokens) (Fmt $s.cost)))
}

# Prompt style
$prompts = foreach ($s in $sessions) { foreach ($p in $s.prompts) {
    if ($p.slash) { continue }
    $sig = [int]$p.hasPath + [int]$p.hasCode + [int]$p.hasError + [int]$p.hasCriteria
    $style = if ($p.words -ge 40 -or $sig -ge 2) { '3 detailed (40+ words or 2+ signals)' } elseif ($p.words -lt 15 -and $sig -eq 0) { '1 short/vague (<15 words, no signals)' } else { '2 medium' }
    $p | Add-Member style $style -Force
    $p | Add-Member cost (Weighted $p) -Force
    $p
} }
function Style-Rows($label, $set) {
    $set = @($set); if (-not $set.Count) { return }
    $n = $set.Count
    $corr = @($set | Where-Object { $_.nextIsCorrection }).Count
    $md.Add((Row $label $n ('{0:N0}' -f ($set | Measure-Object words -Average).Average) ('{0:N1}' -f ($set | Measure-Object calls -Average).Average) (Fmt ($set | Measure-Object cost -Average).Average) (Fmt (($set | Measure-Object cost -Sum).Sum)) (Pct $corr $n)))
}
$md.Add(''); $md.Add('## Prompt style vs cost'); $md.Add('')
$md.Add('Signals: file path, code, error message, acceptance criteria (should/must/expected/only/do not...). Tokens and calls are counted from the prompt until the next prompt, subagents included. "Followed by correction" = the next prompt starts with no/wrong or says instead/still/doesn''t/not working/again. Slash commands excluded.')
$md.Add('')
$hdr = (Row 'Group' 'Prompts' 'Avg words' 'Avg calls' 'Avg cost' 'Total cost' 'Followed by correction')
$md.Add($hdr); $md.Add('|---|--:|--:|--:|--:|--:|--:|')
foreach ($g in $prompts | Group-Object style | Sort-Object Name) { Style-Rows $g.Name.Substring(2) $g.Group }
Style-Rows '**all**' $prompts
$md.Add(''); $md.Add('By signal:'); $md.Add('')
$md.Add($hdr); $md.Add('|---|--:|--:|--:|--:|--:|--:|')
foreach ($k in 'hasPath', 'hasCode', 'hasError', 'hasCriteria') {
    Style-Rows "$k yes" ($prompts | Where-Object { $_.$k })
    Style-Rows "$k no" ($prompts | Where-Object { -not $_.$k })
}
Style-Rows 'is itself a correction' ($prompts | Where-Object { $_.isCorrection })
$md.Add('')
$md.Add('Cost per prompt is driven mostly by how long the session already is (every call re-reads the context), so compare groups with that in mind; the correction rate is the cleaner prompt-quality signal.')

# Compaction
$cand = @($sessions | Where-Object { $_.callsOverCompact -ge 10 } | ForEach-Object {
    $_ | Add-Member savePct ($W.cr * $_.estCompactSavedCacheRead / [math]::Max(1, $_.cost)) -Force; $_ } | Sort-Object { $W.cr * $_.estCompactSavedCacheRead } -Descending)
$limit = ($sessions | Select-Object -First 1).compactAt; if (-not $limit) { $limit = 130000 }
$md.Add(''); $md.Add("## Compaction candidates (10+ calls above $(Fmt $limit) context)"); $md.Add('')
if ($cand.Count) {
    $md.Add("Estimate: one /compact (or a fresh session) when context first passed $(Fmt $limit), back to ~30k, saves the re-read of that history on every later call.")
    $md.Add('')
    $md.Add((Row 'Device' 'Project' 'Start' 'Calls' 'Calls over' 'Peak context' 'Est. cache read saved' 'Est. saving'))
    $md.Add('|---|---|---|--:|--:|--:|--:|--:|')
    foreach ($s in $cand | Select-Object -First $Top) {
        $md.Add((Row $s.device $s.project $s.start.Substring(0, 10) $s.calls $s.callsOverCompact (Fmt $s.peakContext) (Fmt $s.estCompactSavedCacheRead) ('{0:N0}%' -f (100 * $s.savePct))))
    }
    $totSave = $W.cr * ($cand | Measure-Object estCompactSavedCacheRead -Sum).Sum
    $md.Add(''); $md.Add("$($cand.Count) sessions qualify; compacting would have saved about $(Pct $totSave $allCost) of all cost.")
} else { $md.Add('None.') }

# Skills
$skills = @{}
foreach ($s in $sessions) { if ($s.skills) { foreach ($p in $s.skills.PSObject.Properties) { $skills[$p.Name] = [int]$skills[$p.Name] + [int]$p.Value } } }
if ($skills.Count) {
    $md.Add(''); $md.Add('## Skills invoked'); $md.Add('')
    $md.Add((Row 'Skill' 'Calls')); $md.Add('|---|--:|')
    foreach ($k in $skills.GetEnumerator() | Sort-Object Value -Descending) { $md.Add((Row $k.Key $k.Value)) }
}

[IO.File]::WriteAllText($OutFile, ($md -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
Write-Output "Wrote $OutFile ($($sessions.Count) sessions, $(@($prompts).Count) prompts)"
