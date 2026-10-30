<#
.SYNOPSIS
  Summarises this device's Claude Code transcripts (~/.claude/projects) into <OutDir>\<COMPUTERNAME>.usage.json.
  Stores token totals and prompt metrics only; prompt text is kept only with -IncludeText.
.EXAMPLE
  powershell -NoProfile -File collect-usage.ps1 -OutDir "$env:OneDrive\ClaudeUsage"
.EXAMPLE
  powershell -NoProfile -File collect-usage.ps1 -OutDir D:\usage -Since 2026-10-01 -IncludeText
#>
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Since,
    [string]$ProjectsDir = (Join-Path $env:USERPROFILE '.claude\projects'),
    [int]$CompactAt = 130000,
    [switch]$IncludeText
)
$ErrorActionPreference = 'Stop'
$sinceIso = if ($Since) { ([datetime]$Since).ToString('yyyy-MM-dd') } else { '' }

$reId = [regex]'"id":"(msg_[^"]+)"'
$reModel = [regex]'"model":"([^"]+)"'
$reTs = [regex]'"timestamp":"([^"]+)"'
$reSkill = [regex]'"id":"(toolu_[^"]+)","name":"Skill","input":\{"skill":"([^"]+)"'
$reUsage = @{}
foreach ($k in 'input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens') { $reUsage[$k] = [regex]('"' + $k + '":(\d+)') }

$rePath = [regex]'(?i)([a-z]:\\|\\\\|[\w.-]+/[\w./-]+|\b[\w.-]+\.(cs|cshtml|js|ts|sql|json|md|ps1|sh|config|csproj|sln|xml|html|css|py)\b)'
$reCode = [regex]'(```|`[^`]+`|=>|;\s*$|\{\s*$|\b(select|update|insert|delete)\b.+\b(from|set|into)\b|\b(public|private|class|function|var|const)\s+\w+)'
$reError = [regex]'(?i)(exception|error|stack ?trace|failed|failure|cannot|can''t find|undefined|null reference|http \d{3}|\bat [\w.]+\()'
$reCriteria = [regex]'(?i)(\bshould\b|\bmust\b|expected|acceptance|so that|done when|done =|make sure|ensure|verify|\bonly\b|without changing|do not|don''t)'
$reCorrection = [regex]'(?i)(^\s*(no|nope|wrong|not that)\b|\binstead\b|\bstill\b|doesn''?t|does not|didn''?t|not working|isn''?t working|not fixed|same (issue|error|problem)|\bagain\b|revert|undo)'
$skipPrefix = '<task-notification', '<local-command', '<command-', '<side-sessions', '<ci-monitor', '<system-reminder', 'Caveat:', '[Request interrupted'

function Get-PromptText($content) {
    if ($content -is [string]) { return $content }
    $parts = @()
    foreach ($b in @($content)) {
        if ($b.type -eq 'tool_result') { return $null }
        if ($b.type -eq 'text') { $parts += $b.text }
    }
    if ($parts.Count) { return ($parts -join "`n") }
    return $null
}

$seen = @{}
$sessions = @{}
$files = Get-ChildItem $ProjectsDir -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue
foreach ($file in $files) {
    $isSub = $file.DirectoryName -match '\\subagents$'
    $sid = if ($isSub) { Split-Path (Split-Path $file.DirectoryName -Parent) -Leaf } else { $file.BaseName }
    if (-not $sessions.ContainsKey($sid)) {
        $sessions[$sid] = @{ id = $sid; folder = ''; project = ''; entrypoint = ''; version = ''; models = @{}; skills = @{}; calls = New-Object System.Collections.ArrayList; prompts = New-Object System.Collections.ArrayList }
    }
    $s = $sessions[$sid]
    if (-not $s.folder) { $s.folder = if ($isSub) { Split-Path (Split-Path (Split-Path $file.DirectoryName -Parent) -Parent) -Leaf } else { $file.Directory.Name } }

    foreach ($line in [IO.File]::ReadLines($file.FullName)) {
        if (-not $s.entrypoint -and $line -match '"entrypoint":"([^"]+)"') { $s.entrypoint = $Matches[1] }
        if (-not $s.version -and $line -match '"version":"([^"]+)"') { $s.version = $Matches[1] }
        if (-not $s.project -and $line -match '"cwd":"([^"]+)"') { $s.project = (($Matches[1] -replace '\\\\', '\') -split '[\\/]')[-1] }

        if ($line.Contains('"type":"assistant"')) {
            $u = $line.LastIndexOf('"usage":{')
            if ($u -lt 0) { continue }
            $m = $reId.Match($line); if (-not $m.Success) { continue }
            $id = $m.Groups[1].Value
            $us = $line.Substring($u, [math]::Min(400, $line.Length - $u))
            $vals = @{}
            foreach ($k in $reUsage.Keys) { $mm = $reUsage[$k].Match($us); $vals[$k] = if ($mm.Success) { [long]$mm.Groups[1].Value } else { 0 } }
            if (($vals.input_tokens + $vals.cache_creation_input_tokens + $vals.cache_read_input_tokens + $vals.output_tokens) -eq 0) { continue }
            foreach ($sm in $reSkill.Matches($line)) {
                if ($seen.ContainsKey($sm.Groups[1].Value)) { continue }
                $seen[$sm.Groups[1].Value] = $true
                $n = $sm.Groups[2].Value; $s.skills[$n] = 1 + [int]$s.skills[$n]
            }
            if ($seen.ContainsKey($id)) {
                $c = $seen[$id]; if ($vals.output_tokens -gt $c.out) { $c.out = $vals.output_tokens }
                continue
            }
            $tsAll = $reTs.Matches($line); $ts = if ($tsAll.Count) { $tsAll[$tsAll.Count - 1].Groups[1].Value } else { '' }
            $model = $reModel.Match($line).Groups[1].Value
            $c = @{ ts = $ts; model = $model; sub = $isSub; inp = $vals.input_tokens; cw = $vals.cache_creation_input_tokens; cr = $vals.cache_read_input_tokens; out = $vals.output_tokens }
            $seen[$id] = $c
            [void]$s.calls.Add($c)
            continue
        }

        if ($isSub -or -not $line.Contains('"type":"user"') -or $line.Contains('"tool_use_id"') -or $line.Contains('"isMeta":true')) { continue }
        try { $o = $line | ConvertFrom-Json } catch { continue }
        if ($o.type -ne 'user' -or $o.isSidechain) { continue }
        if ($o.origin -and $o.origin.kind -and $o.origin.kind -ne 'human') { continue }
        $text = Get-PromptText $o.message.content
        if (-not $text) { continue }
        $t = $text.TrimStart()
        $skip = $false; foreach ($p in $skipPrefix) { if ($t.StartsWith($p)) { $skip = $true; break } }
        if ($skip) { continue }
        $words = @($t -split '\s+' | Where-Object { $_ }).Count
        $pr = [ordered]@{
            ts = [string]$o.timestamp; chars = $t.Length; words = $words; lines = @($t -split "`n").Count
            slash = $t.StartsWith('/')
            hasPath = $rePath.IsMatch($t); hasCode = $reCode.IsMatch($t); hasError = $reError.IsMatch($t); hasCriteria = $reCriteria.IsMatch($t)
            isCorrection = $reCorrection.IsMatch($t)
        }
        if ($IncludeText) { $pr.text = $t }
        [void]$s.prompts.Add($pr)
    }
}

$out = New-Object System.Collections.ArrayList
foreach ($s in $sessions.Values) {
    $calls = @($s.calls | Sort-Object { $_.ts })
    if (-not $calls.Count) { continue }
    $start = $calls[0].ts; $end = $calls[-1].ts
    if ($sinceIso -and $end.Substring(0, 10) -lt $sinceIso) { continue }
    $prompts = @($s.prompts | Sort-Object { $_.ts })

    # Totals, peak context, compaction estimate (main thread only: subagents have their own context)
    $tot = @{ inp = 0L; cw = 0L; cr = 0L; out = 0L }
    # Saving if compacted once (to ~30k) at the first call over CompactAt: each later call re-reads up to CompactAt-30k less
    $peak = 0L; $over = 0; $firstCross = 0L; $saved = 0L; $subCalls = 0
    foreach ($c in $calls) {
        $tot.inp += $c.inp; $tot.cw += $c.cw; $tot.cr += $c.cr; $tot.out += $c.out
        if ($c.model) { $s.models[$c.model] = 1 + [int]$s.models[$c.model] }
        if ($c.sub) { $subCalls++; continue }
        $ctx = $c.inp + $c.cw + $c.cr
        if ($ctx -gt $peak) { $peak = $ctx }
        if ($ctx -gt $CompactAt) {
            $over++
            if (-not $firstCross) { $firstCross = $ctx } else { $saved += [math]::Max(0, [math]::Min($ctx, $CompactAt) - 30000) }
        }
    }

    # Attribute each call to the last prompt at or before it
    $pi = -1
    $agg = @(for ($i = 0; $i -lt $prompts.Count; $i++) { @{ calls = 0; inp = 0L; cw = 0L; cr = 0L; out = 0L } })
    foreach ($c in $calls) {
        while ($pi + 1 -lt $prompts.Count -and $prompts[$pi + 1].ts -le $c.ts) { $pi++ }
        if ($pi -lt 0) { continue }
        $a = $agg[$pi]; $a.calls++; $a.inp += $c.inp; $a.cw += $c.cw; $a.cr += $c.cr; $a.out += $c.out
    }
    $plist = for ($i = 0; $i -lt $prompts.Count; $i++) {
        $p = $prompts[$i]; $a = $agg[$i]
        $p.calls = $a.calls; $p.input = $a.inp; $p.cacheWrite = $a.cw; $p.cacheRead = $a.cr; $p.output = $a.out
        $p.nextIsCorrection = ($i + 1 -lt $prompts.Count) -and $prompts[$i + 1].isCorrection
        [pscustomobject]$p
    }

    [void]$out.Add([pscustomobject][ordered]@{
        id = $s.id; project = $(if ($s.project) { $s.project } else { $s.folder }); entrypoint = $s.entrypoint; version = $s.version
        start = $start; end = $end; models = @($s.models.Keys); skills = [pscustomobject]$s.skills
        calls = $calls.Count; subagentCalls = $subCalls
        input = $tot.inp; cacheWrite = $tot.cw; cacheRead = $tot.cr; output = $tot.out
        peakContext = $peak; callsOverCompact = $over; estCompactSavedCacheRead = $saved
        prompts = @($plist)
    })
}

$doc = [pscustomobject][ordered]@{
    device = $env:COMPUTERNAME; user = $env:USERNAME; collectedAt = (Get-Date).ToUniversalTime().ToString('o')
    since = $sinceIso; compactAt = $CompactAt; includesText = [bool]$IncludeText
    sessions = @($out | Sort-Object start)
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$path = Join-Path $OutDir "$($env:COMPUTERNAME).usage.json"
[IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
$np = ($out | ForEach-Object { $_.prompts.Count } | Measure-Object -Sum).Sum
$nc = ($out | Measure-Object calls -Sum).Sum
Write-Output "Wrote $path ($($out.Count) sessions, $np prompts, $nc API calls)"
