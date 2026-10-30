---
name: learning-loop
description: Turn corrections, mistakes and what worked into lessons, promote recurring ones across projects, and consolidate memory. Use for a retro or memory cleanup, or on "learn from this", "don't do that again".
---

# Learning loop

## Capture (immediately when it happens)
Triggers: user correction, rejected suggestion, build/test failure caused by you, a wrong assumption, an approach the user praised or confirmed.

Write one bullet to `.claude/knowledge/lessons.md` under the right area:
```
- [area] <rule to follow next time> — Why: <what happened>. (YYYY-MM-DD, seen 1x)
```
- Phrase as an actionable rule ("Run `dotnet build -c Release` before tests — Debug hides analyzer errors"), not a story.
- If a matching lesson exists, bump `seen Nx` and refine wording instead of adding a duplicate.
- Confirmed good approaches are lessons too — record them so they're repeated.

## Promote
- A lesson seen in 2+ projects, or clearly about the user rather than the codebase → move to `~/.claude/knowledge/global.md` → "Promoted lessons", remove from project file (leave a pointer if useful).
- A lesson that is really a convention → move to `profile.md` → Conventions.

## Apply
- At task start (`project-memory` Load), skim `lessons.md` sections relevant to the area being touched.
- Before repeating an action that a lesson warns about, follow the lesson and say so in one line.

## Retro (end of a large task, or on request)
Answer briefly, then record:
1. What slowed us down or caused rework?
2. What should be reused next time (→ `reuse-catalog.md`)?
3. Which assumption was wrong (→ `lessons.md`)?
4. Should any skill itself change? If yes, suggest a concrete edit to that skill's `SKILL.md` (the skills are open for upgrade — see CONTRIBUTING.md in the companion repo).

## Consolidate (when a knowledge file passes ~300 lines, or monthly)
Merge duplicates, delete stale/contradicted facts, compress old `changes.md` entries into per-area summaries, keep `INDEX.md` ≤ 40 lines. Show the user a summary of what was removed.
