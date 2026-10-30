---
name: clean-code
description: Write small, readable code in any language (C#, SQL, JS, ...), review and optimize it - naming, simplicity, SOLID, error handling, performance (N+1, async, allocations), safe refactoring. Use when asked to refactor, optimize, speed up, simplify or review code quality.
---

# Clean & optimal code

## Readable first (any language)
Code is written once and read many times. Write the smallest code a newcomer understands on first read.
- **Less code**: the simplest thing that works. Use the language/framework built-in (LINQ, set-based SQL, `Array.map/filter`) before a hand-written loop; reuse existing helpers. Delete what the change makes unused.
- **Names say what and why**: `overdueInvoices`, not `list2`/`data`/`temp`; booleans read as questions (`isActive`, `hasAccess`); verbs for functions (`calculateFee`). Use the domain's words, consistently.
- **Small units**: a function does one thing at one level of detail and fits on a screen; a well-named helper beats a comment.
- **Flat flow**: guard clauses and early return instead of nested `if`; no clever one-liners, nested ternaries or chained side effects.
- **Explicit**: no magic numbers/strings (named constants), no hidden state or flag parameters; data in, result out.
- **Comments explain why** (business rule, workaround, non-obvious choice), never restate what the code says.
- **Same shape everywhere**: similar things look alike, so differences stand out.
- Check: could it be shorter without being harder to read? Would a teammate understand it without asking you?

## While implementing
- **Match the surrounding code** first: naming, structure, comment density, error-handling and DI style of the file/project. Consistency beats personal preference.
- **Minimal diff**: change only what the task needs. No drive-by reformatting, renames or reorders.
- No dead code, commented-out code, or TODOs without a ticket.
- Handle errors at the right layer; never swallow exceptions silently; validate input at boundaries.
- Don't add abstraction for a single use (YAGNI); do extract when the same logic appears 3+ times.
- Security basics: parameterised queries, no secrets in code, encode output, least privilege.

## Optimizing (measure → change → measure)
1. Find the real hotspot first (profiler, logs, query plans, timings). Don't optimize by guessing.
2. Typical big wins, in order:
   - **I/O & DB**: N+1 queries, missing indexes, fetching unused columns/rows, chatty calls → batch, project, page, cache.
   - **Algorithms**: O(n²) lookups → dictionary/set; repeated work in loops → hoist.
   - **Async**: no sync-over-async (`.Result`, `.Wait()`); parallelise independent I/O; stream large data.
   - **Allocations**: avoid needless `ToList()`, string concatenation in loops (use builder), boxing, large object churn.
   - **Caching**: only with a clear invalidation story.
3. Keep behaviour identical; verify with tests before/after and report the measured gain.
4. Prefer readable code unless the hot path proves otherwise; comment *why* a non-obvious optimization exists.

## Self-review before showing the diff
- [ ] Compiles / no new warnings; follows project conventions
- [ ] Readable on first pass: clear names, short functions, flat flow, nothing that can be removed
- [ ] No duplicated logic that exists elsewhere (`code-reuse`)
- [ ] Edge cases: null/empty, boundaries, concurrency, time zones, culture
- [ ] Resources disposed; no leaks; cancellation propagated
- [ ] Public API / schema changes intentional and called out
- [ ] Tests added/updated (`testing-expert`)
