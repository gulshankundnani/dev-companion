---
name: find
description: Find anything in a project fast and cheaply - files, classes, actions, views, JS functions, SQL objects, config keys, text - using the search map and knowledge first, then the narrowest search. Remembers where things live for future sessions. Use for "where is", "find", "locate", "which file", "search for".
---

# Find

Goal: the answer in the fewest calls and tokens, and never search for the same thing twice.

## Search map (remembered paths)
- Location: `<knowledge store>/search-map.md` when project memory exists; otherwise local `~/.claude/knowledge/search/<key>.md`, where `<key>` is the repo path lowercased with `:`, `\` and `/` replaced by `-` (`D:\Src\Shop` -> `d--src-shop.md`). The session hook names the file when it exists.
- **Folder index** (tree view, greppable): always local, `~/.claude/knowledge/search/<key>.tree.txt`. One line per folder with its full relative path and source file counts (`MCampusUI/Areas/Fees/Views/FeeHead/  .cshtml 12`). Grep it to find folders by name in one call; never Read it whole (large repos: 5k+ lines). A full path per line beats an indented tree: every grep hit is a usable path.
- No map yet and the repo is large or the search is not trivial: run once (~12 s for 25k files, in the background):
  `powershell -NoProfile -File "<this skill>/scripts/search-roots.ps1" -Root <repo> -TreeOut <folder index path>`
  Save the printed **Roots** into the map with `references/search-map-template.md`. Writing the map and index is memory, not a project change: no consent needed; mention it in one line.
- Rebuild the index when a remembered path no longer exists or it is older than ~7 days and folders were added.

## Ladder (stop at the first step that answers)
1. **Map and knowledge**: Grep the term in `search-map.md`, then `graph.md` / `reuse-catalog.md` if they exist. A hit gives the path: verify it exists, read only the lines needed.
2. **Folder by name -> Grep the folder index** (`-i`, `head_limit: 20`; `count` first for broad words like "fee"): gives the exact folder to scope the next step.
3. **File name known -> Glob**: `**/FeesController.cs`, `**/Views/Fees/*.cshtml`, `**/*Installment*`. Scope to the folder from Roots.
4. **Content -> Grep** (ripgrep, fastest): `output_mode: files_with_matches` or `count` first, with `path` from Roots and `glob`/`type` (`*.cs`, `*.cshtml`, `*.sql`); then `content` with `-n`, small `-C`, `head_limit`. Anchor patterns to definitions:
   - C# class/action: `class FeesController\b`, `ActionResult\s+SaveInstallment\(`, `\bSaveInstallment\s*\(` for callers
   - Razor view of an action: `Views/<Controller>/<Action>.cshtml` (Areas: `Areas/<Area>/Views/...`); partials: `Html.Partial\("Name"`, `RenderPartial`
   - JS function: `function\s+name\b|name\s*[:=]\s*function|name\s*=\s*\(`; JS hooks: `jsName` in `*.cshtml` and `*.js`
   - SQL object: `(CREATE|ALTER)\s+(OR\s+ALTER\s+)?(PROC|PROCEDURE|FUNCTION|VIEW|TABLE)\s+(\[?dbo\]?\.)?\[?Name\b`
   - Config key: `key="Name"` in `*.config`; route: `Route\("...` or `MapRoute`
   - Text on screen: search the exact UI text in `*.cshtml`, `*.resx`, `*.js`, then the DB scripts
5. **Read** the hit with `offset`/`limit` around the line, not the whole file.
6. **Still unknown and broad** (many folders, vague concept): one Explore subagent with the Roots block and a precise question; it returns paths, not dumps.

Never: `Get-ChildItem -Recurse`, `dir /s`, `findstr /s`, `find` without pruning, or reading whole large files to search. Always skip `bin obj node_modules packages .git dist`, `*.min.js`, `*.Designer.cs`, vendor folders noted in the map.

## Remember (after a find)
Add one line to **Found** when the answer took more than one search or was non-obvious:
`- <term or feature> -> <path>[:line] (<how: glob/grep pattern>)`
- One line per concept; update the line if the path changed; delete lines whose path no longer exists.
- Add folders that only produced noise to **Skip**, and a search pattern that worked well for this codebase to **Recipes**.
- Keep the map under ~80 lines: merge feature lines into folder lines when a folder holds many of them.
