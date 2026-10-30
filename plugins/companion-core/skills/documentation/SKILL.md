---
name: documentation
description: Right-sized docs - why-comments, XML/JSDoc for public APIs, README, ADRs, release notes, PR/check-in descriptions. Use when asked to document something or write a README, release notes or PR description.
---

# Documentation

## Decide what's needed (smallest useful set)
| Change | Document in |
|--------|-------------|
| Non-obvious logic / workaround | Code comment explaining **why** (not what) |
| New/changed public API, library method | XML doc (`///`) / JSDoc — summary, params, returns, exceptions |
| New setup step, config key, env var, command | README / `profile.md` Commands |
| Architectural or design choice | `decisions.md` (ADR-lite) |
| HTTP endpoint | OpenAPI annotations / API doc per project convention |
| DB schema change | Migration script header comment + `architecture.md` if structural |
| Release | Release notes: user-facing changes, breaking changes, migration steps |

Match the project's existing documentation style and density. Don't add comments to code you didn't change.

## Writing rules
- Audience first: developer onboarding vs. end user vs. reviewer.
- Lead with what it does and how to use it; examples over prose; commands in code blocks.
- Keep docs next to what they describe; link instead of duplicating.
- Diagrams: mermaid in markdown (renders in Azure DevOps, GitHub, VS Code). See `ui-ux-expert` for mockups.
- Update docs in the same change as the code; remove docs that became wrong.

## Templates
**PR / check-in description**
```
## What
<one paragraph>
## Why
<ticket / problem>
## How
- <key change per bullet>
## Testing
<what ran, results, manual steps>
## Risks / rollout
<migrations, flags, breaking changes or "none">
```

**README skeleton**: Title → one-line purpose → Prerequisites → Setup → Run → Test → Configuration → Project structure → Contributing.
