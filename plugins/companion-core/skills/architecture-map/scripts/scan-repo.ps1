<#
.SYNOPSIS
  Scans a repository and writes knowledge-graph triples into .claude/knowledge/graph.md
  (only the "## Generated" section is replaced; "## Curated" is kept).

.DESCRIPTION
  Covers: .NET projects (TargetFramework, ProjectReference, PackageReference, packages.config,
  HintPath assembly references, EF DbSet, controllers), MVC controller -> view folders, Razor views
  (scripts, bundles, partials, app JS functions they call), app JavaScript functions/classes (vendor
  libraries skipped), optional public C# types with inheritance, SQL scripts (tables, FKs, procs,
  views, functions), and package.json dependencies. Works on Windows PowerShell 5.1 and PowerShell 7+.

.EXAMPLE
  powershell -NoProfile -File scan-repo.ps1 -Root D:\src\MyApp -IncludeTypes
#>
param(
    [string]$Root = (Get-Location).Path,
    [string]$Out,
    [switch]$IncludeTypes
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

# Default output: the project's knowledge store - <repo>\.claude\knowledge, or a local store
# mapped in ~/.claude/knowledge/locations.txt (lines "<repo path>|<store path>")
function ConvertTo-PathKey([string]$p) { (($p.Trim() -replace '\\', '/').ToLower() -replace '^/([a-z])/', '$1:/').TrimEnd('/') }
if (-not $Out) {
    $Out = Join-Path $Root '.claude\knowledge\graph.md'
    $locations = Join-Path $HOME '.claude\knowledge\locations.txt'
    if (-not (Test-Path (Split-Path $Out)) -and (Test-Path $locations)) {
        $key = ConvertTo-PathKey $Root
        foreach ($line in [IO.File]::ReadAllLines($locations)) {
            $parts = $line.Split('|')
            if ($parts.Count -ge 2 -and (ConvertTo-PathKey $parts[0]) -eq $key) { $Out = Join-Path $parts[1].Trim() 'graph.md'; break }
        }
    }
}

$skipDirs = @('bin', 'obj', 'node_modules', '.git', '.vs', 'dist', 'build', 'packages', 'out', 'TestResults', '.claude')

# One pruned walk of the tree (Get-ChildItem -Recurse per pattern is very slow on large repos)
$allFiles = New-Object System.Collections.Generic.List[IO.FileInfo]
$stack = New-Object System.Collections.Generic.Stack[IO.DirectoryInfo]
$stack.Push((New-Object IO.DirectoryInfo $Root))
while ($stack.Count) {
    $d = $stack.Pop()
    try {
        foreach ($sub in $d.GetDirectories()) { if ($skipDirs -notcontains $sub.Name) { $stack.Push($sub) } }
        $allFiles.AddRange($d.GetFiles())
    } catch { }
}
function Get-RepoFiles([string[]]$patterns) {
    $rx = '^(' + (($patterns | ForEach-Object { [regex]::Escape($_).Replace('\*', '.*') }) -join '|') + ')$'
    foreach ($f in $allFiles) { if ($f.Name -match $rx) { $f } }
}

$triples = New-Object 'System.Collections.Generic.HashSet[string]'
function Add-Triple($s, $r, $o) { [void]$triples.Add("$s --$r--> $o") }
function Get-RelPath([string]$path) { ($path.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/' }
$controllers = New-Object System.Collections.Generic.List[object]

# ---------- .NET projects ----------
$projects = @(Get-RepoFiles @('*.csproj', '*.vbproj', '*.fsproj'))
foreach ($proj in $projects) {
    $name = [IO.Path]::GetFileNameWithoutExtension($proj.Name)
    try { [xml]$xml = [IO.File]::ReadAllText($proj.FullName) } catch { continue }

    # local-name() so old-style projects with the msbuild/2003 XML namespace match too
    $tfm = @($xml.SelectNodes("//*[local-name()='TargetFramework' or local-name()='TargetFrameworks' or local-name()='TargetFrameworkVersion']") | ForEach-Object { $_.InnerText }) -join ';'
    if ($tfm) { Add-Triple "proj:$name" 'targets' "ext:$tfm" }

    $sdk = $xml.Project.Sdk
    if ($sdk) { Add-Triple "proj:$name" 'uses_sdk' "ext:$sdk" }

    foreach ($ref in $xml.SelectNodes("//*[local-name()='ProjectReference']")) {
        $refName = [IO.Path]::GetFileNameWithoutExtension(($ref.Include -replace '\\', '/'))
        Add-Triple "proj:$name" 'depends_on' "proj:$refName"
    }
    foreach ($pkg in $xml.SelectNodes("//*[local-name()='PackageReference']")) {
        $verNode = $pkg.SelectSingleNode("*[local-name()='Version']")
        $ver = if ($pkg.Version) { $pkg.Version } elseif ($verNode) { $verNode.InnerText } else { '' }
        $id = if ($ver) { "$($pkg.Include)@$ver" } else { $pkg.Include }
        Add-Triple "proj:$name" 'references' "ext:$id"
    }

    # .NET Framework style: packages.config, and assembly references to libraries (those with a HintPath)
    $projDir = $proj.DirectoryName
    $pkgConfig = Join-Path $projDir 'packages.config'
    if (Test-Path $pkgConfig) {
        try {
            [xml]$pc = [IO.File]::ReadAllText($pkgConfig)
            foreach ($p in $pc.SelectNodes('//package')) { Add-Triple "proj:$name" 'references' "ext:$($p.id)@$($p.version)" }
        } catch { }
    } else {
        # No packages.config: library references are the only package information
        foreach ($ref in $xml.SelectNodes("//*[local-name()='Reference'][*[local-name()='HintPath']]")) {
            $asm = ($ref.Include -split ',')[0].Trim()
            if ($asm) { Add-Triple "proj:$name" 'references' "ext:$asm" }
        }
    }

    # C# sources owned by this project
    $projPrefix = $projDir.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    foreach ($cs in $allFiles) {
        if ($cs.Extension -ne '.cs' -or -not $cs.FullName.StartsWith($projPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($cs.Name -match '\.(Designer|g|g\.i|AssemblyInfo)\.cs$') { continue }
        $text = [IO.File]::ReadAllText($cs.FullName)
        if (-not $text) { continue }

        # EF Core / EF6 DbSet<T>
        $ctx = [regex]::Match($text, 'class\s+(\w+)\s*(?:\([^)]*\))?\s*:\s*[\w\.<>, ]*DbContext')
        if ($ctx.Success) {
            Add-Triple "type:$($ctx.Groups[1].Value)" 'owned_by' "proj:$name"
            foreach ($m in [regex]::Matches($text, 'DbSet<(\w+)>\s+(\w+)')) {
                Add-Triple "type:$($ctx.Groups[1].Value)" 'maps' "table:$($m.Groups[2].Value)"
                Add-Triple "table:$($m.Groups[2].Value)" 'entity' "type:$($m.Groups[1].Value)"
            }
        }

        # Controllers
        foreach ($m in [regex]::Matches($text, 'class\s+(\w+Controller)\b')) {
            $route = [regex]::Match($text, '\[Route\("([^"]+)"\)\]')
            $api = if ($route.Success) { $route.Groups[1].Value -replace '\[controller\]', ($m.Groups[1].Value -replace 'Controller$', '') } else { $m.Groups[1].Value }
            Add-Triple "type:$($m.Groups[1].Value)" 'exposes' "api:$api"
            Add-Triple "type:$($m.Groups[1].Value)" 'owned_by' "proj:$name"
            $controllers.Add([pscustomobject]@{ Name = $m.Groups[1].Value; File = $cs.FullName; ProjDir = $projDir })
        }

        if ($IncludeTypes) {
            $typeRx = 'public\s+(?:(?:sealed|abstract|static|partial|readonly)\s+)*(class|interface|record|struct|enum)\s+(\w+)(?:<[^>]+>)?(?:\s*\([^)]*\))?(?:\s*:\s*([\w\.<>, ]+?))?\s*(?:where\b|\{|$)'
            foreach ($m in [regex]::Matches($text, $typeRx, 'Multiline')) {
                $tname = $m.Groups[2].Value
                if ($tname -match 'Controller$') { continue }
                Add-Triple "type:$tname" 'owned_by' "proj:$name"
                if ($m.Groups[3].Success) {
                    foreach ($base in ($m.Groups[3].Value -split ',')) {
                        $b = ($base.Trim() -replace '<.*$', '')
                        if (-not $b) { continue }
                        $rel = if ($b -match '^I[A-Z]') { 'implements' } else { 'inherits' }
                        Add-Triple "type:$tname" $rel "type:$b"
                    }
                }
            }
        }
    }
}

# ---------- MVC: controller -> views (Views/<Name>/ or Areas/<Area>/Views/<Name>/) ----------
$viewLinks = 0
foreach ($c in $controllers) {
    $short = $c.Name -replace 'Controller$', ''
    $area = [regex]::Match($c.File, '^(.*[\\/]Areas[\\/][^\\/]+)[\\/]Controllers[\\/]')
    $viewDir = if ($area.Success) { Join-Path $area.Groups[1].Value "Views\$short" } else { Join-Path $c.ProjDir "Views\$short" }
    if (-not (Test-Path $viewDir)) { continue }
    foreach ($v in Get-ChildItem -Path $viewDir -File -Filter '*.cshtml' -ErrorAction SilentlyContinue) {
        Add-Triple "type:$($c.Name)" 'renders' "ui:$(Get-RelPath $v.FullName)"
        $viewLinks++
    }
}

# ---------- JavaScript: top-level functions/classes defined in app scripts (vendor libraries skipped) ----------
$vendorRx = '(?i)\.min\.js$|[\\/](lib|libs|vendor|kendo|telerik|ckeditor|tinymce|fonts)[\\/]|jquery|bootstrap|modernizr|knockout|angular|moment|select2|datatables|respond|globalize|signalr|chart|highcharts|\.intellisense\.js$|-vsdoc\.js$'
$jsFiles = @(Get-RepoFiles @('*.js') | Where-Object { $_.FullName -notmatch $vendorRx -and $_.Length -lt 400KB })
$jsNames = New-Object 'System.Collections.Generic.HashSet[string]'
# JS hooks: CSS classes named js<Upper>... that scripts select, e.g. class="btn jsSaveFees" + $(".jsSaveFees")
$hookSelectRx = '\$\(\s*["'']\.(js[A-Z][\w-]*)'
$hookClassRx = 'class\s*=\s*"([^"]*)"'
$jsDefRx = '^[ \t]{0,4}(?:function\s+([A-Za-z_$][\w$]*)\s*\(|(?:var|let|const)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:function\b|class\b|\(|\{|new\b)|class\s+([A-Za-z_$][\w$]*)|([A-Za-z_$][\w$]*)\s*=\s*function\b)'
foreach ($js in $jsFiles) {
    $text = [IO.File]::ReadAllText($js.FullName)
    $rel = Get-RelPath $js.FullName
    foreach ($m in [regex]::Matches($text, $hookSelectRx)) { Add-Triple "file:$rel" 'selects' "hook:.$($m.Groups[1].Value)" }
    foreach ($m in [regex]::Matches($text, $jsDefRx, 'Multiline')) {
        $fn = $null
        foreach ($i in 1..4) { if ($m.Groups[$i].Success) { $fn = $m.Groups[$i].Value; break } }
        if (-not $fn -or $fn.Length -lt 4) { continue }
        Add-Triple "js:$fn" 'defined_in' "file:$rel"
        if ($fn.Length -ge 6) { [void]$jsNames.Add($fn) }
    }
}

# ---------- Razor views: scripts, bundles, partials, JS hooks and app JS functions used ----------
$viewFiles = @(Get-RepoFiles @('*.cshtml'))
$callers = @{}
foreach ($v in $viewFiles) {
    $text = [IO.File]::ReadAllText($v.FullName)
    if (-not $text) { continue }
    $ui = "ui:$(Get-RelPath $v.FullName)"
    foreach ($m in [regex]::Matches($text, 'src\s*=\s*"~?/?([^"?]+\.js)')) { Add-Triple $ui 'uses' "file:$($m.Groups[1].Value)" }
    foreach ($m in [regex]::Matches($text, 'Scripts\.Render\(\s*"([^"]+)"')) { Add-Triple $ui 'uses' "bundle:$($m.Groups[1].Value)" }
    foreach ($m in [regex]::Matches($text, '(?:Html\.(?:Render)?Partial(?:Async)?|<partial\s+name=)\(?\s*"([^"]+)"')) { Add-Triple $ui 'includes' "partial:$($m.Groups[1].Value)" }
    foreach ($m in [regex]::Matches($text, $hookClassRx)) {
        foreach ($h in [regex]::Matches($m.Groups[1].Value, '\bjs[A-Z][\w-]*')) { Add-Triple $ui 'marks' "hook:.$($h.Value)" }
    }
    foreach ($m in [regex]::Matches($text, $hookSelectRx)) { Add-Triple $ui 'selects' "hook:.$($m.Groups[1].Value)" }
    if ($jsNames.Count) {
        foreach ($m in [regex]::Matches($text, '(?:\bnew\s+)?\b([A-Za-z_$][\w$]{5,})\s*\(')) {
            $fn = $m.Groups[1].Value
            if (-not $jsNames.Contains($fn)) { continue }
            if (-not $callers.ContainsKey($fn)) { $callers[$fn] = New-Object 'System.Collections.Generic.HashSet[string]' }
            [void]$callers[$fn].Add($ui)
        }
    }
}

# Calls: list each calling view, except for widely shared helpers, which get one summary line
# (thousands of identical lines would bury useful results when grepping the graph)
foreach ($fn in $callers.Keys) {
    $set = $callers[$fn]
    if ($set.Count -gt 100) { Add-Triple "js:$fn" 'called_by' "ui:$($set.Count) views (shared helper)" }
    else { foreach ($ui in $set) { Add-Triple $ui 'calls' "js:$fn" } }
}

# ---------- SQL scripts ----------
$sqlFiles = @(Get-RepoFiles @('*.sql'))
foreach ($sql in $sqlFiles) {
    $text = [IO.File]::ReadAllText($sql.FullName)
    if (-not $text) { continue }
    $nameRx = '((?:\[?\w+\]?\.)?\[?\w+\]?)'
    foreach ($m in [regex]::Matches($text, "CREATE\s+(?:OR\s+ALTER\s+)?(TABLE|PROC|PROCEDURE|VIEW|FUNCTION|TRIGGER)\s+$nameRx", 'IgnoreCase')) {
        $kind = $m.Groups[1].Value.ToUpper()
        # drop brackets and the default dbo schema so names match EF DbSet nodes
        $obj = $m.Groups[2].Value -replace '[\[\]]', '' -replace '^dbo\.', ''
        $prefix = switch -Regex ($kind) { 'TABLE' { 'table' } 'PROC' { 'sp' } 'VIEW' { 'view' } 'FUNCTION' { 'fn' } 'TRIGGER' { 'trigger' } }
        $rel = ($sql.FullName.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/'
        Add-Triple "${prefix}:$obj" 'defined_in' "file:$rel"
        if ($kind -eq 'TABLE') {
            # only look for FKs up to the next CREATE so they aren't attributed to the wrong table
            $rest = $text.Substring($m.Index + $m.Length)
            $next = [regex]::Match($rest, '\bCREATE\s', 'IgnoreCase')
            $body = if ($next.Success) { $rest.Substring(0, $next.Index) } else { $rest }
            foreach ($fk in [regex]::Matches($body, "REFERENCES\s+$nameRx", 'IgnoreCase')) {
                Add-Triple "table:$obj" 'references' ("table:" + ($fk.Groups[1].Value -replace '[\[\]]', '' -replace '^dbo\.', ''))
            }
        }
    }
}

# ---------- package.json ----------
foreach ($pj in @(Get-RepoFiles @('package.json'))) {
    try { $json = Get-Content -LiteralPath $pj.FullName -Raw | ConvertFrom-Json } catch { continue }
    $pname = if ($json.name) { $json.name } else { Split-Path $pj.DirectoryName -Leaf }
    foreach ($section in 'dependencies', 'devDependencies') {
        $deps = $json.$section
        if ($deps) { $deps.PSObject.Properties | ForEach-Object { Add-Triple "proj:$pname" 'references' "ext:$($_.Name)@$($_.Value)" } }
    }
}

# ---------- write ----------
$unique = [string[]]@($triples)
[Array]::Sort($unique, [StringComparer]::Ordinal)
$generated = @("## Generated (scan-repo script - regenerate, don't hand-edit)", "<!-- scanned $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $($unique.Count) triples -->") + $unique

$curated = "## Curated (hand-maintained - survives regeneration)`r`n"
$header = "# Knowledge graph`r`n`r`n> One triple per line: ``Subject --relation--> Object``. Grep-friendly.`r`n"
if (Test-Path $Out) {
    $existing = Get-Content -LiteralPath $Out -Raw
    $gi = $existing.IndexOf('## Generated')
    $ci = $existing.IndexOf('## Curated')
    if ($gi -ge 0) { $header = $existing.Substring(0, $gi) }
    if ($ci -ge 0) { $curated = $existing.Substring($ci) }
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
}

$content = $header.TrimEnd() + "`r`n`r`n" + ($generated -join "`r`n") + "`r`n`r`n" + $curated
[IO.File]::WriteAllText($Out, $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Output "Scanned $Root"
Write-Output ("Projects: {0}  Controllers: {1} (view links: {2})  Views: {3}  App JS files: {4} (functions: {5})  SQL files: {6}" -f $projects.Count, $controllers.Count, $viewLinks, $viewFiles.Count, $jsFiles.Count, $jsNames.Count, $sqlFiles.Count)
Write-Output ("Triples: {0}  Size: {1} KB" -f $unique.Count, [math]::Round((Get-Item $Out).Length / 1KB))
Write-Output "Wrote $Out"
