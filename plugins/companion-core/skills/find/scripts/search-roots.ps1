<#
.SYNOPSIS
  Prints a compact "where things live" map of a repository: for each source file type,
  the folders holding most of those files. Paste the output into search-map.md (Roots).
  With -TreeOut, also writes a folder index: one relative folder path per line with its
  source file counts. Grep it to find folders by name; never read it whole.
.EXAMPLE
  powershell -NoProfile -File search-roots.ps1 -Root D:\Repo -Depth 3
#>
param(
  [string]$Root = (Get-Location).Path,
  [int]$Depth = 3,
  [int]$TopFolders = 5,
  [string]$TreeOut
)

$skipDirs = @('bin', 'obj', 'node_modules', '.git', '.vs', 'dist', 'build', 'packages', 'out', 'TestResults', '.claude')
$sourceTypes = @('.cs', '.vb', '.cshtml', '.vbhtml', '.aspx', '.ascx', '.js', '.ts', '.tsx', '.jsx', '.vue', '.css', '.scss',
                 '.sql', '.config', '.json', '.xml', '.resx', '.rdlc', '.py', '.java', '.go', '.php', '.ps1', '.sh')
$Root = (Resolve-Path $Root -ErrorAction Stop).Path.TrimEnd('\')

function Get-FolderKey([string]$fullDir) {
  $relative = $fullDir.Substring($Root.Length).TrimStart('\')
  if (-not $relative) { return '.' }
  return (($relative -split '\\') | Select-Object -First $Depth) -join '/'
}

# One pruned walk; Get-ChildItem -Recurse is very slow on large repos
$countsByType = @{}
$countsByFolder = @{}
$minified = 0
$stack = New-Object System.Collections.Generic.Stack[IO.DirectoryInfo]
$stack.Push((New-Object IO.DirectoryInfo $Root))
while ($stack.Count) {
  $dir = $stack.Pop()
  try {
    foreach ($sub in $dir.GetDirectories()) { if ($skipDirs -notcontains $sub.Name) { $stack.Push($sub) } }
    foreach ($file in $dir.GetFiles()) {
      $type = $file.Extension.ToLowerInvariant()
      if ($sourceTypes -notcontains $type) { continue }
      if ($file.Name -match '\.min\.(js|css)$') { $minified++; continue }
      if (-not $countsByType[$type]) { $countsByType[$type] = @{} }
      $key = Get-FolderKey $dir.FullName
      $countsByType[$type][$key] = 1 + [int]$countsByType[$type][$key]
      if ($TreeOut) {
        $folder = $dir.FullName.Substring($Root.Length).TrimStart('\').Replace('\', '/')
        if (-not $countsByFolder[$folder]) { $countsByFolder[$folder] = @{} }
        $countsByFolder[$folder][$type] = 1 + [int]$countsByFolder[$folder][$type]
      }
    }
  } catch { }
}

"Roots ($Root, skipped: $($skipDirs -join ' '), $minified minified files)"
$countsByType.GetEnumerator() |
  ForEach-Object { [pscustomobject]@{ Type = $_.Key; Folders = $_.Value; Total = ($_.Value.Values | Measure-Object -Sum).Sum } } |
  Sort-Object Total -Descending |
  ForEach-Object {
    $top = $_.Folders.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $TopFolders |
      ForEach-Object { "$($_.Key) ($($_.Value))" }
    $more = $_.Folders.Count - $TopFolders
    $tail = if ($more -gt 0) { " +$more folders" } else { '' }
    "- $($_.Type) $($_.Total): $($top -join ', ')$tail"
  }

if ($TreeOut) {
  $lines = foreach ($folder in $countsByFolder.Keys) {
    $types = $countsByFolder[$folder].GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key) $($_.Value)" }
    "$(if ($folder) { $folder } else { '.' })/  $($types -join ', ')"
  }
  $sorted = [string[]]$lines
  [Array]::Sort($sorted, [StringComparer]::OrdinalIgnoreCase)
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($TreeOut))) | Out-Null
  [IO.File]::WriteAllLines([IO.Path]::GetFullPath($TreeOut), $sorted)
  "Folder index: $TreeOut ($($sorted.Count) folders)"
}
