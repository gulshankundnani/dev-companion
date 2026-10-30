---
name: code-reuse
description: Find and reuse existing helpers, components, SQL objects and patterns from past changes before writing new code, then catalog new reusable code. Use for a broad reuse search, or when asked "do we already have...", "reuse", "like we did X".
---

# Code reuse

## Before writing new code (search order — stop when found)
1. **Reuse catalog**: `.claude/knowledge/reuse-catalog.md` (table + patterns section).
2. **Past changes**: grep `.claude/knowledge/changes.md` for the feature area / similar intent — a previous change may already show the pattern.
3. **Knowledge graph**: grep `graph.md` for related types/tables.
4. **Codebase search** — by intent, not just by name:
   - Likely names/verbs: `Grep "(Format|Parse|Convert|Map|Validate|Paged|Retry|Cache)\w*"` scoped to `Common|Shared|Core|Utils|Helpers|Extensions|Infrastructure`.
   - Extension methods on the type you work with: `Grep "this <TypeName> "`.
   - Base classes / generic services: `Grep "abstract class|class \w+Base\b|<T> where T"`.
   - Same library already referenced? Check package refs before adding a dependency.
   - SQL: existing procs/views/functions for the same tables (`graph.md`, `*.sql`).
   - UI: existing components/styles in shared component folders.
5. **Framework/BCL**: does the platform already provide it (LINQ, `System.Text.Json`, `IHttpClientFactory`, built-in validation)?

## Decide
- **Reuse as-is** when it fits ≥ 90%.
- **Extend** (overload, optional parameter, new extension) when close — keep backward compatible, don't change behaviour for existing callers.
- **New code** only when nothing fits; place it where the next person will find it (the project's shared/common location), following its naming.
- Duplicate found while working? Mention it as an optional follow-up; don't refactor outside scope without consent.

State the outcome in the plan: "Reusing `X` from `path`" or "No existing helper found (searched: …)".

## After writing (remember)
Add a row to `reuse-catalog.md` for anything reusable:
```
| ToPagedAsync | src/Common/Extensions/QueryableExtensions.cs | Paged query → PagedResult<T> | `query.ToPagedAsync(page, size, ct)` |
```
Add recurring "how we do X here" knowledge to the Patterns section. Note `Reusable:` in the `changes.md` entry.
