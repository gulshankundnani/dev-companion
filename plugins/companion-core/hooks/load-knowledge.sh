#!/bin/sh
# SessionStart hook: print the always-on rules plus real project/global knowledge into Claude's context.
# Everything printed here is re-read on every API call of the session, so it is kept minimal:
# template placeholders, headings and blank lines are filtered out. Never fails the session.

dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
global="$HOME/.claude/knowledge/global.md"
locations="$HOME/.claude/knowledge/locations.txt"

# Find the knowledge store: <repo>/.claude/knowledge, or a local store mapped in locations.txt
# (lines "<repo path>|<store path>"). Paths are compared case-insensitively with / separators.
norm() { printf '%s' "$1" | tr '\134' '/' | tr 'A-Z' 'a-z' | sed -e 's#^/\([a-z]\)/#\1:/#' -e 's#/*$##'; }
store="$dir/.claude/knowledge"
where=project
if [ ! -f "$store/INDEX.md" ] && [ -f "$locations" ]; then
  key=$(norm "$dir")
  mapped=$(while IFS='|' read -r repo path; do
    [ "$(norm "$repo")" = "$key" ] && { printf '%s' "$path" | tr '\134' '/' | sed 's/[[:space:]]*$//'; break; }
  done < "$locations")
  [ -n "$mapped" ] && [ -f "$mapped/INDEX.md" ] && { store="$mapped"; where=local; }
fi
index="$store/INDEX.md"

# Real content only: drop placeholder lines (<...>), notes (>), headings, blanks and the INDEX file list
facts() { sed '/^## Files/,$d' "$1" | grep -v '<' | grep -v '^>' | grep -v '^#' | grep -v '^[[:space:]]*$' | grep -v '^- *$' | head -n 25; }

cat <<'EOF'
[companion] Rules:
- Consent: one approval per conversation before the first file change (short plan). Ask again only for deletes, schema/data changes, new dependencies, commits, pushes.
- Tools: fetch only what's needed (grep then line ranges, specific elements, filtered capped output). Reuse existing code first.
- Waiting: long commands run in background; wait for the completion notice. No polling, sleep loops or re-reading output.
- Code: smallest clear solution, intent-revealing names, short single-purpose functions, early returns, no dead code or what-comments; follow the file's idioms.
- Test non-trivial code before editing (scratch run, failing test, rolled-back SQL): edge/invalid inputs; injection, XSS, CSRF, access control, brute force when input/auth/data/HTML is touched. Then build and run the narrowest tests. Say what was tested.
- Replies: result first; no opener, recap or offers. Keep not/never/no/only, code, paths, numbers, errors exact. Changed lines only. Full sentences for warnings and questions.
EOF

# An open handoff (saved task state) in the store or the local handoff folder: offer to resume it
for h in "$store/handoff" "$dir/.claude/handoff" "$HOME/.claude/handoff/$(basename "$dir")"; do
  open=$(grep -l '^Status: open' "$h"/*.md 2>/dev/null | tail -n 1)
  [ -n "$open" ] && { echo "- Open handoff: $open. Offer to resume it (handoff skill)."; break; }
done

if [ -f "$index" ]; then
  [ "$where" = local ] && echo "- Knowledge store is local (outside the repo): $store. Use it wherever skills say .claude/knowledge."
  echo "- Knowledge: check .claude/knowledge (graph.md, reuse-catalog.md) before exploring code. After a task, add a short entry to changes.md; record corrections in lessons.md."
  project=$(facts "$index")
  [ -n "$project" ] && printf '[companion] Project:\n%s\n' "$project"
else
  echo "- No project memory here. For non-trivial work, offer once to initialise it (it asks: in the project or local only)."
fi

if [ -f "$global" ]; then
  prefs=$(facts "$global")
  [ -n "$prefs" ] && printf '[companion] Preferences:\n%s\n' "$prefs"
fi

exit 0
