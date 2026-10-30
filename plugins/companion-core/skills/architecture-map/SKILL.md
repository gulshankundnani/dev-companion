---
name: architecture-map
description: Map and remember a codebase's architecture as a knowledge graph (projects, packages, types, tables, procs, endpoints) in .claude/knowledge. Use in an unfamiliar repo, for impact analysis ("what uses X"), before cross-module changes, or to explain or diagram architecture.
---

# Architecture map & knowledge graph

## Query (most common — cheap)
Before reading code, grep the graph:
- What depends on X: `Grep "--> .*X$" .claude/knowledge/graph.md`
- What X depends on: `Grep "^.*X --" .claude/knowledge/graph.md`
- Who reads/writes a table: `Grep "table:Orders" .claude/knowledge/graph.md`
- MVC: views of a controller `Grep "type:FeesController --renders"`; where a JS function is defined/used `Grep "js:openPopup"`; a JS hook class `Grep "hook:.jsSaveFees"` (marks = element has it, selects = script uses it).
- The graph can be large: always grep with a specific name and `head_limit`; never read the whole file.
Then open only the files the graph points to. If the graph is missing or `Last scanned` in `architecture.md` is old relative to big changes, offer to rebuild.

## Build / refresh
1. **Scan** (generated triples). Run the bundled script from this skill's folder:
   ```
   powershell -NoProfile -File "<skill-dir>/scripts/scan-repo.ps1" -Root "<repo>"
   ```
   Options: `-IncludeTypes` (add public C# types + inheritance; bigger graph), `-Out <path>`.
   It covers .NET (SDK and old-style `.csproj`, `packages.config`, EF `DbSet`, controllers), MVC controller-to-view folders, Razor views (scripts, bundles, partials, JS hooks, app JS calls), app JavaScript functions (vendor libraries skipped), SQL scripts and `package.json` deps. About 2 minutes for ~35k files. It rewrites only the `## Generated` section of `graph.md`; `## Curated` is preserved.
   No PowerShell? Do the same with Grep/Glob by hand, smaller scope.
2. **Curate** (the valuable part — the script can't infer intent). Read entry points (Program/Startup, DI registration, routing, main modules) and add to `## Curated`:
   - key runtime flows: `api:POST /orders --calls--> type:OrderService`, `type:OrderService --writes--> table:Orders`
   - external systems, queues, config keys, ownership
3. **Summarise** into `architecture.md` (template in `project-memory/templates/`): overview, mermaid diagram (≤ 15 nodes), module table, key flows, cross-cutting concerns, `Last scanned: <date>`.
4. Update `INDEX.md` must-know rules if you discovered architectural rules (e.g. "Domain has no infrastructure references").

## Impact analysis (before cross-module edits)
List direct + one-hop dependents of what you'll change, flag public APIs, DB objects and config used elsewhere, and include this in the plan shown at the consent gate.

## Rules
- Respect existing architecture; follow its layering and patterns. Propose architectural changes as suggestions, never sneak them into a task.
- Triples: one per line, `Subject --relation--> Object`, node prefixes per `graph.md` header. Keep nodes at module/type/table level, not method level.
- After a change that adds/removes modules, tables, endpoints or dependencies, update the graph (re-run scan and/or edit Curated).
