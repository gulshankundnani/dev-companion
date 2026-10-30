---
name: project-memory
description: Per-project knowledge store (profile, changes, decisions, lessons) plus global preferences. Use to initialise memory in a repo, save a preference ("remember...", "from now on..."), or recall how something was done before.
---

# Project memory

## Layout (segregated per project)

Each project has one **store**, kept where the user chose at Init:
- **Project**: `<repo>/.claude/knowledge/` - can be committed and shared with the team.
- **Local**: `~/.claude/knowledge/projects/<name>/` - only on this machine, nothing in the repo. Mapped in `~/.claude/knowledge/locations.txt` (one line per repo: `<repo path>|<store path>`).

The session hook prints the store path when it is local. Wherever any skill says `.claude/knowledge`, use the active store.

```
<store>/
  INDEX.md          # ≤ 40 lines. Auto-loaded at session start. Pointers + top facts only
  profile.md        # stack, versions, build/test/run commands, conventions, team preferences
  architecture.md   # layers, modules, key flows, diagram          (owner: architecture-map)
  graph.md          # knowledge graph as triples                   (owner: architecture-map)
  reuse-catalog.md  # reusable components / helpers / patterns     (owner: code-reuse)
  changes.md        # log of changes made with Claude, newest first
  decisions.md      # ADR-lite: decision, why, date
  lessons.md        # corrections, pitfalls, what worked           (owner: learning-loop)
  profile.local.md  # personal prefs for this project (project store: gitignored)

~/.claude/knowledge/               # global, per user, all projects
  global.md         # cross-project preferences (style, tools, communication)
  projects.md       # registry: project | repo path | store (project/local) | stack | one-liner
  locations.txt     # repo path -> local store path (local stores only)
  projects/<name>/  # local stores
```
Router and consent-guard state is always local (`~/.claude/companion-router/`, `~/.claude/companion-guard/`), never in the repo.

Precedence when facts conflict: user's current message > `profile.local.md` > `profile.md` > `global.md`.

## Load (task start)
1. Read `INDEX.md` (often already injected by the SessionStart hook). Read other files **only when the task needs them** — e.g. `changes.md` when touching an area changed before, `reuse-catalog.md` before writing new helpers.
2. Read `~/.claude/knowledge/global.md` if present (short by design).
3. Verify before trusting: a remembered path/class/command may be stale — check it exists before relying on it.

## Init (no store yet)
Ask once, as one question with two options (use AskUserQuestion when available), before creating anything:
"Where should project memory (knowledge, graph, change log, lessons) be kept?"
- **In the project** - `<repo>/.claude/knowledge/`; can be committed and shared with your team.
- **Local only** - `~/.claude/knowledge/projects/<name>/`; stays on this machine, nothing is added to the repo.

Then:
1. Create the store and copy the templates from this skill's `templates/` folder into it.
   - Project: `<repo>/.claude/knowledge/`. Add `.claude/knowledge/profile.local.md` to `.gitignore` (TFVC: `.tfignore`).
   - Local: `<name>` = repo folder name (add `-2`, `-3` if already used by another repo). Append `<repo absolute path>|<store absolute path>` to `~/.claude/knowledge/locations.txt`. Write nothing inside the repo.
2. Fill `profile.md` from manifests (`*.sln`, `*.csproj`, `package.json`, `Directory.Build.props`, CI files, README). Keep it factual and short.
3. Run `architecture-map` → Build to fill `architecture.md` + `graph.md` (the scanner finds a local store through `locations.txt`).
4. Register the project in `~/.claude/knowledge/projects.md`, including the store type.

## Move (switch between project and local)
On request ("move project memory to local / into the repo"): copy the files to the new location, add or remove the `locations.txt` line, update `projects.md`, then ask before deleting the old copy. A project store that was committed also needs a delete commit, which is only done on request.

## Record (task end)
Append to `changes.md` (newest first, ≤ 6 lines per entry):
```
## 2026-10-28 — <short title>
- Why: <intent / ticket id>
- Files: <paths or module names>
- Approach: <pattern used, key decision>
- Reusable: <new helper/pattern worth reusing, or "none">
```
Then: new reusable code → `reuse-catalog.md`; real design decision → `decisions.md`; correction/pitfall → `lessons.md` (via `learning-loop`). Update `INDEX.md` only if a top-level fact changed.

## Save a preference
- "Remember X" / "from now on X": decide scope — this project (`profile.md`, or `profile.local.md` if personal) or all projects (`global.md`). If unclear, ask "This project or all projects?".
- One fact per bullet. Update an existing bullet instead of adding a duplicate. Delete facts proven wrong.

## Rules
- Store facts, not transcripts. No secrets, connection strings, tokens, or personal data.
- Don't store what code/git already records (full diffs, file listings); store the *why* and the *where*.
- Keep every file skimmable: if one passes ~300 lines, consolidate (merge duplicates, drop stale entries, summarise old `changes.md` entries by area).
