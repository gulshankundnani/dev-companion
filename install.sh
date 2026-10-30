#!/bin/sh
# Installs the Dev Companion skills for Claude Code (macOS / Linux / Git Bash).
# Usage:
#   ./install.sh                                   # plugin mode, core + dotnet + ui
#   ./install.sh plugin companion-core companion-guard
#   ./install.sh skills                            # copy skills to ~/.claude/skills (no hooks)
#   SOURCE=https://github.com/<you>/ClaudeSkills ./install.sh
set -e

here="$(cd "$(dirname "$0")" && pwd)"
mode="${1:-plugin}"; [ $# -gt 0 ] && shift
plugins="${*:-companion-core companion-dotnet companion-ui}"
source="${SOURCE:-$here}"
marketplace="dev-companion"

mkdir -p "$HOME/.claude/knowledge"
[ -f "$HOME/.claude/knowledge/global.md" ] || {
  cp "$here/plugins/companion-core/skills/project-memory/templates/global.md" "$HOME/.claude/knowledge/global.md"
  echo "Created ~/.claude/knowledge/global.md"
}
[ -f "$HOME/.claude/knowledge/projects.md" ] || printf '# Project registry\n\n| Project | Repo path | Store | Stack | One-liner |\n|---|---|---|---|---|\n' > "$HOME/.claude/knowledge/projects.md"

if [ "$mode" = "plugin" ]; then
  command -v claude >/dev/null || { echo "claude CLI not found; use: ./install.sh skills"; exit 1; }
  claude plugin marketplace add "$source"
  for p in $plugins; do claude plugin install "$p@$marketplace"; done
  echo "Done. Restart Claude Code (or /reload-plugins), then try: /companion-core:workflow"
else
  target="$HOME/.claude/skills"; mkdir -p "$target"
  for p in $plugins; do
    [ -d "$here/plugins/$p/skills" ] || { echo "skip $p (no skills)"; continue; }
    for s in "$here/plugins/$p/skills"/*/; do
      name="$(basename "$s")"; rm -rf "$target/$name"; cp -R "$s" "$target/$name"
      echo "Installed skill $name"
    done
  done
  echo "Done. Restart Claude Code, then try: /workflow"
fi
