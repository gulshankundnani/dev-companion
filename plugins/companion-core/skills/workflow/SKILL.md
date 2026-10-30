---
name: workflow
description: Sequenced workflow for multi-step dev work (feature, bug fix, refactor, migration) - context, preflight, reuse, plan, consent, implement, test, document, record. Use at the start of non-trivial coding tasks or on "start task" / "follow the workflow".
---

# Development workflow

Each phase's essentials are inline below. **Load another skill only where a phase says "Load"** - the rest of the time this page is enough.

## Scale first
- **Trivial** (typo, one-line fix): phases 6, 7, 11 only.
- **Standard** (one feature/bug, a few files): all phases, lightweight.
- **Large** (cross-module, schema change, new subsystem): all phases; the plan is reviewed with the user before any edit.

## Phases
1. **Context.** INDEX.md and global preferences are injected at session start. Open other knowledge files only when the task touches their area. No knowledge store and the task is non-trivial: offer to create one. Load `project-memory` only to initialise it.
2. **Preflight.** Know the goal, scope, constraints and how it will be verified. Ask at most 3 blocking questions in one message; state the defaults you chose for the rest. Load `preflight` only for large or unclear tasks.
3. **Architecture.** Grep `graph.md` for the modules/tables you'll touch and their dependents; open only the files it points to. Load `architecture-map` only if the graph is missing or stale and the task crosses modules.
4. **Reuse.** Grep `reuse-catalog.md`, then `changes.md`, then the code for an existing helper or pattern. Say "Reusing X from path" or "Nothing found (searched: ...)". Load `code-reuse` only for a broad search.
5. **Plan.** Files to change with one line each, one recommended option, risks. Extra improvements go in a separate "optional" list, never into the task.
6. **Consent.** Ask "Proceed?" before the first file change of the conversation; one yes covers later file changes. Always ask separately for deletes, schema/data changes, new dependencies, and commits.
6b. **Test the suggestion before editing** (non-trivial logic, SQL, regex, date/number formatting, algorithms): run it outside the real files first - see `testing-expert` "Test before editing". Show the result with the plan. Skip only for trivial edits (rename, text, config value) and say so.
7. **Implement.** Match the surrounding code; minimal diff. Load the domain expert for domain work - `csharp-expert`, `sql-expert`, `ui-ux-expert` - their checklists prevent rework. Load `clean-code` for refactoring or optimization tasks.
8. **Verify.** Build, then run the narrowest relevant tests; report exactly what ran and what didn't. Load `testing-expert` when writing new tests or diagnosing failures.
9. **Document.** Only where usage, setup or a public API changed. Load `documentation` for a README, release notes or PR description.
10. **Source control.** Only when the user asks. Load `git-tfs`.
11. **Record.** Append a <= 6-line entry to `changes.md`; new reusable code goes in `reuse-catalog.md`, user corrections in `lessons.md`. Load `learning-loop` for a retro or memory cleanup.

## Rules
- Never skip phase 6 for the first edit of a conversation. Reading and searching need no consent.
- If the user corrects you, apply it and note it for phase 11.
- Finish by reporting what changed, what was verified, and what was not.
