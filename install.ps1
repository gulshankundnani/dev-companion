<#
.SYNOPSIS
  Installs the Dev Companion skills for Claude Code.

.DESCRIPTION
  Mode Plugin (default, recommended): registers this folder (or a Git URL) as a plugin marketplace and
  installs the chosen plugins with the `claude` CLI. Gets skills + hooks, and `claude plugin update` later.

  Mode Skills: copies the skill folders into ~/.claude/skills (User scope) or <project>/.claude/skills
  (Project scope). No hooks; skills appear without a plugin prefix. Use when the plugin CLI is unavailable.

  Both modes create ~/.claude/knowledge/global.md from the template if it doesn't exist.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Plugins companion-core,companion-dotnet,companion-guard
  .\install.ps1 -Mode Skills -Scope Project -ProjectPath D:\src\MyApp
  .\install.ps1 -Source https://dev.azure.com/org/proj/_git/ClaudeSkills
#>
param(
    [ValidateSet('Plugin', 'Skills')] [string]$Mode = 'Plugin',
    [string[]]$Plugins = @('companion-core', 'companion-dotnet', 'companion-ui'),
    [string]$Source = $PSScriptRoot,
    [ValidateSet('User', 'Project')] [string]$Scope = 'User',
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$marketplace = 'dev-companion'
$claudeHome = Join-Path $HOME '.claude'

# Global knowledge store (shared by all projects)
$knowledge = Join-Path $claudeHome 'knowledge'
New-Item -ItemType Directory -Force -Path $knowledge | Out-Null
$globalFile = Join-Path $knowledge 'global.md'
if (-not (Test-Path $globalFile)) {
    Copy-Item (Join-Path $PSScriptRoot 'plugins\companion-core\skills\project-memory\templates\global.md') $globalFile
    Write-Host "Created $globalFile"
}
$registry = Join-Path $knowledge 'projects.md'
if (-not (Test-Path $registry)) {
    Set-Content -Path $registry -Encoding utf8 -Value "# Project registry`r`n`r`n| Project | Repo path | Store | Stack | One-liner |`r`n|---|---|---|---|---|"
}

if ($Mode -eq 'Plugin') {
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        throw "The 'claude' CLI was not found on PATH. Install Claude Code, or rerun with -Mode Skills."
    }
    Write-Host "Registering marketplace '$marketplace' from $Source"
    & claude plugin marketplace add $Source
    foreach ($p in $Plugins) {
        Write-Host "Installing $p@$marketplace"
        & claude plugin install "$p@$marketplace"
    }
    Write-Host "`nDone. Restart Claude Code (or run /reload-plugins), then try: /companion-core:workflow"
    return
}

# Skills mode: copy skill folders
$target = if ($Scope -eq 'User') { Join-Path $claudeHome 'skills' } else { Join-Path $ProjectPath '.claude\skills' }
New-Item -ItemType Directory -Force -Path $target | Out-Null
foreach ($p in $Plugins) {
    $skillsDir = Join-Path $PSScriptRoot "plugins\$p\skills"
    if (-not (Test-Path $skillsDir)) { Write-Warning "No skills in $p (hooks-only plugins need -Mode Plugin)"; continue }
    foreach ($skill in Get-ChildItem $skillsDir -Directory) {
        $dest = Join-Path $target $skill.Name
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -Confirm:$false }
        Copy-Item $skill.FullName $dest -Recurse
        Write-Host "Installed skill $($skill.Name) -> $dest"
    }
}
Write-Host "`nDone. Restart Claude Code, then try: /workflow"
