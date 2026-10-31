<#
.SYNOPSIS
  Shows which Claude Code sessions and subagents on this machine spent tokens recently,
  and how many of their calls were idle waiting (sleep, polling, short wake-ups, repeated reads).
.EXAMPLE
  powershell -NoProfile -File background-usage.ps1 -Minutes 120
#>
param(
  [int]$Minutes = 60,
  [string]$ProjectsDir = (Join-Path $env:USERPROFILE '.claude\projects')
)

$since = (Get-Date).ToUniversalTime().AddMinutes(-$Minutes)
$sinceIso = $since.ToString('yyyy-MM-ddTHH:mm:ss')
$waitCommand = 'Start-Sleep|\bsleep\s+\d|timeout\s+/t|ping\s+-n\s+\d'
$pollTools = @('TaskOutput', 'BashOutput', 'Monitor')

function Get-WeightedTokens($usage) {
  # Relative cost: input 1, cache write 1.25, cache read 0.1, output 5
  return [double]$usage.input_tokens + 1.25 * $usage.cache_creation_input_tokens +
         0.1 * $usage.cache_read_input_tokens + 5 * $usage.output_tokens
}

function Test-IdleWait($toolUse) {
  if ($pollTools -contains $toolUse.name) { return $true }
  if ($toolUse.name -eq 'ScheduleWakeup') { return ([int]$toolUse.input.delaySeconds -lt 270) }
  if ($toolUse.name -in @('Bash', 'PowerShell')) { return ($toolUse.input.command -match $waitCommand) }
  return $false
}

$files = Get-ChildItem -Path $ProjectsDir -Filter *.jsonl -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTimeUtc -ge $since }

$rows = foreach ($file in $files) {
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $reads = @{}
  $calls = 0; $weighted = 0.0; $waitCalls = 0; $waitWeighted = 0.0; $context = 0
  $cwd = ''; $last = ''; $isSubagent = $false

  foreach ($line in [IO.File]::ReadLines($file.FullName)) {
    if ($line.IndexOf('"usage"') -lt 0 -or $line.IndexOf('"assistant"') -lt 0) { continue }
    $stamp = [regex]::Match($line, '"timestamp"\s*:\s*"([^"]+)"').Groups[1].Value
    if ($stamp -lt $sinceIso) { continue }
    try { $entry = $line | ConvertFrom-Json } catch { continue }
    $message = $entry.message
    if (-not $message.usage -or -not $seen.Add([string]$message.id)) { continue }

    $cost = Get-WeightedTokens $message.usage
    $calls++; $weighted += $cost; $last = $stamp
    $context = $message.usage.input_tokens + $message.usage.cache_creation_input_tokens + $message.usage.cache_read_input_tokens
    if ($entry.cwd -and -not $cwd) { $cwd = $entry.cwd }
    if ($entry.isSidechain) { $isSubagent = $true }

    foreach ($part in @($message.content | Where-Object { $_.type -eq 'tool_use' })) {
      if (Test-IdleWait $part) { $waitCalls++; $waitWeighted += $cost; break }
      if ($part.name -eq 'Read') { $reads[$part.input.file_path] = 1 + [int]$reads[$part.input.file_path] }
    }
  }
  if ($calls -eq 0) { continue }

  [pscustomobject]@{
    Session     = $file.BaseName.Substring(0, [Math]::Min(12, $file.BaseName.Length))
    Project     = if ($cwd) { Split-Path $cwd -Leaf } else { $file.Directory.Name }
    Kind        = if ($isSubagent -or $file.FullName -match '\\subagents\\') { 'subagent' } else { 'main' }
    LastActive  = ([datetime]::Parse($last)).ToLocalTime().ToString('dd MMM HH:mm')
    LastUtc     = $last
    Calls       = $calls
    ContextK    = [Math]::Round($context / 1000)
    WeightedK   = [Math]::Round($weighted / 1000, 1)
    IdleWaits   = $waitCalls
    IdleShare   = if ($weighted) { '{0:P0}' -f ($waitWeighted / $weighted) } else { '0%' }
    RepeatReads = @($reads.Values | Where-Object { $_ -gt 3 }).Count
  }
}

if (-not $rows) { "No Claude Code activity in the last $Minutes minutes."; return }
$rows = @($rows | Sort-Object WeightedK -Descending)
$rows | Select-Object * -ExcludeProperty LastUtc | Format-Table -AutoSize | Out-String -Width 200
$total = ($rows | Measure-Object WeightedK -Sum).Sum
"Last $Minutes min: $($rows.Count) transcripts, $($total)k weighted tokens. Active now (last 5 min): " +
  @($rows | Where-Object { $_.LastUtc -ge (Get-Date).ToUniversalTime().AddMinutes(-5).ToString('yyyy-MM-ddTHH:mm:ss') }).Count
"IdleWaits = calls spent sleeping, polling or waking early; RepeatReads = files read more than 3 times."
