---
name: preflight
description: Full pre-task checklist, plan with one recommended option, and consent rules before editing. Use for large or unclear tasks, or when asked "what's your plan".
---

# Preflight, plan, consent

## 1. Checklist (answer silently; ask only what you cannot find)
- [ ] **Goal**: one sentence of what "done" means. Acceptance criteria known?
- [ ] **Project**: which project/solution/module? Knowledge store loaded (`.claude/knowledge/INDEX.md`)?
- [ ] **Scope**: files/layers likely touched. Anything explicitly out of scope?
- [ ] **Constraints**: framework/runtime versions, coding standards, performance, security, backward compatibility, DB migration rules.
- [ ] **Reuse**: searched reuse catalog + codebase for existing helper/pattern/similar past change? (`code-reuse`)
- [ ] **Impact**: callers, public APIs, DB schema, config, UI, other teams affected? (`architecture-map`)
- [ ] **Data safety**: destructive ops (DROP, DELETE, migrations, file deletes) identified and flagged?
- [ ] **Pre-test**: how the suggested code will be proven before the real edit (scratch run, failing test, rolled-back SQL)
- [ ] **Verification**: how will it be tested — existing tests, new tests, manual steps, build command?
- [ ] **Source control**: branch / workspace state clean? Uncommitted user changes I must not overwrite?

Ask the user in ONE message, max 3–4 questions, only for blocking unknowns. Make sensible defaults for the rest and state them.

## 2. Plan with optimal suggestions
- Give **one recommended approach** first, with a one-line why. Mention an alternative only if the trade-off is real (cost, risk, effort).
- Prefer: reuse > extend > new code. Smallest change that fully solves the problem. Follow existing project patterns over personal preference.
- List files to change and the nature of each change (≤ 1 line each).
- Call out risks: breaking changes, migrations, performance, security.
- Suggest improvements you noticed, but keep them **separate** from the task ("Optional follow-ups") — never silently widen scope.

## 3. Consent gate (once per conversation)
- Before the first file change in a conversation, show the plan and ask: "Proceed with these changes?"
- One "yes" covers file changes for the rest of the conversation. Don't ask again per file or per task.
- Still ask separately, every time, for: deleting files, DB schema/data changes, dependency upgrades, commits/pushes/check-ins, anything outward-facing.
- Skip even the first ask if the user already said "go ahead / no need to ask", or the project profile says `consent: relaxed`.
- For an enforced version, install the `companion-guard` plugin (prompts on the first edit of each conversation, then allows the rest).
