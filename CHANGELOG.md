# Changelog

## 1.12.0 core - 2026-10-30
- Thorough testing: `testing-expert` requires happy path, edge/invalid inputs and error paths for every change, plus security tests when input, auth, data access, HTML, files or external calls are touched.
- New `testing-expert/references/thorough-tests.md` (read only when needed): edge cases and server-side validation bypass, over-posting, brute force and sessions, access control/IDOR, SQL/command/path/header injection, open redirect, SSRF, XSS (stored, reflected, DOM), CSRF, sniffing (network, MIME, SQL parameter sniffing), DB connection and HttpClient pooling, thread pool, OWASP misconfiguration and vulnerable packages; payloads, pass criteria and a report format. Security tests only on local/dev environments of the user's own app.
- Always-on test rule extended (~25 tokens). Router: security, XSS, CSRF, injection, brute force, OWASP, testing load `testing-expert`.

## 1.11.0 core / 1.4.0 dotnet - 2026-10-30
- Test before editing: non-trivial suggested code is proven outside the repo before the real edit (failing test first for bug fixes; scratch run with edge inputs for logic, regex, formatting, algorithms; SQL in `BEGIN TRAN ... ROLLBACK` or temp tables), and the result is shown with the plan. Trivial edits skip it and say so.
- Always-on rule (~40 tokens), `workflow` step 6b, `preflight` checklist item, `testing-expert` "Test before editing" with per-language commands (C#, .NET Framework, JS, SQL, others), `sql-expert` test-first line.

## 1.10.0 core / 1.3.0 dotnet / 1.4.0 ui - 2026-10-30
Goal: smaller, readable code in every language (code is written once and read many times).
- Always-on rule (session hook, ~45 tokens): smallest clear solution, intent-revealing names, short single-purpose functions, early returns, no dead code or comments that restate code, follow the file's and language's idioms. Applies to all code without loading a skill.
- `clean-code`: new "Readable first (any language)" section (less code, naming, small units, flat flow, explicit, why-comments, consistent shape) and a readability check in self-review.
- `csharp-expert`: concise modern C# where the target framework allows. `sql-expert`: layout, aliases, CTEs. `web-frontend-expert`: small named functions, `const`/`let`, cached selections.
- Router: "clean code", "readable", "maintainable" load `clean-code`.

## 1.2.0 analytics - 2026-10-29
- Usage Hub: a private "Claude Usage Hub" artifact whose database holds one document per device and month (`usage/<DEVICE>~<YYYY-MM>`), rows keyed by app+project+day: sessions, calls, tokens, weighted cost, prompt-style sums (count, calls, cost, followed-by-correction) and compaction candidates. No prompt text. The page shows totals per device/app/project, cost per day, prompt style vs cost and top compaction candidates.
- New `hub-rows.ps1`: turns `<device>.usage.json` into hub documents, merging rows already in the hub so days whose transcripts were deleted are kept; prints the `ArtifactData` batch writes (pinned with `-Versions`).
- `usage-analytics`: "publish my usage to the hub" flow; working files moved to `%LOCALAPPDATA%\companion-analytics` (`~/.claude` is write-protected for downloads).
- New `sync-usage` skill (`/companion-analytics:sync-usage`): publishes this device, then asks one Remote Control session per other device to publish.

## 1.1.0 analytics / 1.9.0 core - 2026-10-29
- New `companion-analytics:analyst` skill: one 8-step method for any analysis (question, subject type, cheap evidence, decompose, measure/derive, patterns and causes, test against counter-examples, findings first). Kind-specific playbooks in `references/` (data, code, maths, patterns, behaviour/root cause, decisions/trade-offs/risk), read only when needed.
- Router: analysis intent (analyse, investigate, why does, root cause, pattern, trend, behaviour, statistics, solve/derive/prove, compare, evaluate) requires the analyst, even when phrased as a question; an analysis question gets only the analyst.
- Router: bare "sql" no longer requires `sql-expert` (it fired on "not limited to CSV, Excel, JSON, logs, SQL results"); it needs an action ("fix ... sql") or object ("sql query", "sql server"). Requests about skills, plugins or hooks get no domain expert.
- Router: on change requests the analyst is added after domain experts, so they keep priority within the 2-skill limit; bare "pattern" needs "in/of" or "find" ("follow the existing pattern" is not analysis); continuation summaries after compaction are not routed.
- New `tools/test-router.sh` + `tools/router-cases.txt` regression set (21 cases). Replay of 583 real prompts: 33 routes changed, all reviewed; `sql-expert` no longer fires on passing mentions.

## 1.0.0 analytics - 2026-10-29
- New opt-in plugin `companion-analytics`, skill `usage-analytics`. `collect-usage.ps1` summarises each device's transcripts into `<COMPUTERNAME>.usage.json` in a shared folder (tokens deduplicated per API message id, peak context, skills, per-prompt metrics; no prompt text unless `-IncludeText`). `usage-report.ps1` merges devices into a markdown report: per device/app/project totals, relative cost (input 1, cache write 1.25, cache read 0.1, output 5), prompt style vs cost and correction rate, compaction candidates.
- First run (MICM2026PC03, 29 sessions): 2.89B cache-read tokens = ~75% of weighted cost; 21 sessions ran 10+ calls above 130k context.

## 1.8.0 core - 2026-10-28
- Project memory asks where to keep its data at Init: **in the project** (`<repo>/.claude/knowledge/`, can be committed and shared) or **local only** (`~/.claude/knowledge/projects/<name>/`, nothing written to the repo). Local stores are mapped in `~/.claude/knowledge/locations.txt` (`<repo path>|<store path>`).
- The session hook and the graph scanner find a local store automatically (path matching ignores case and `\` vs `/`); the hook tells Claude the store path so all skills use it.
- New "move project memory to local / into the repo" flow. Project registry gains Repo path and Store columns.

## 1.7.0 core - 2026-10-28
Knowledge-graph scanner upgraded for large .NET Framework MVC solutions (tested read-only on MCampusMVC: 85 projects, 1,371 controllers, 23,812 views, 598 app JS files).
- Old-style `.csproj` (msbuild XML namespace) now parsed: target framework, project and package references were silently missed before. `packages.config` and HintPath assembly references added.
- MVC: controller -> view folder links (including Areas); Razor views -> scripts, bundles, partials, app JS functions called; JS hook classes (`class="... jsName"` = marks, `$(".jsName")` = selects) in views and scripts; app JS functions indexed, vendor libraries skipped.
- Helpers called from more than 100 views collapse to one `called_by` summary line, so searches stay useful (MCampusMVC: 48,550 call lines -> 2,577 + 38 summaries; graph 8.5 MB -> 6.2 MB).
- Speed: single pruned directory walk, fast file reads, HashSet de-duplication. MCampusMVC scan >10 min -> ~2 min.
- Router ignores background-task notifications (one triggered clean-code because its title said "optimized").

## 1.6.0 core / 1.2.0 dotnet / 1.3.0 ui - 2026-10-28
Goal: help productivity without adding per-trip tokens (anything in context is re-read on every API call).
- Session hook injects only real content: unfilled INDEX/global templates, headings and placeholders are filtered out; knowledge rules appear only in repos that have `.claude/knowledge`; rules compressed. Per-trip footprint without project memory: ~1.33k -> ~1.03k tokens (-22%).
- Router: optional hints removed (Claude ignored them and each stayed in context); questions get no output; required line and context nudge shortened.
- `csharp-expert`, `sql-expert`, `web-frontend-expert` rewritten terse (-38 to -42% each), so every trip after loading costs less. Detailed review checklists stay in `references/`, read only when reviewing.
- Benchmark (n=2): required skills still load 2/2; planning task $0.210 -> $0.187.

## 1.5.0 core / 1.2.0 ui - 2026-10-28
Fixes from a real MCampusMVC session (popup reload fix, ~17M tokens, sql-expert loaded by mistake):
- Router: SQL rule no longer fires on bare "index", "table", "column" or "query" (Index.cshtml, HTML tables, grid columns, LINQ); it needs a database term. C# rule also matches controllers and view models.
- Router: a request counts as a code change unless it reads like a question, so bug reports and task titles ("popup goes behind", "Reload on close") get the required expert.
- New `companion-ui:web-frontend-expert`: Razor views, JavaScript/jQuery, AJAX, Bootstrap/jQuery UI modals, stacked popups and close callbacks, script caching. Routed for .cshtml, JS, popup, modal and dialog requests.
- Context nudge: when the conversation reaches ~130k and ~170k tokens, Claude suggests `/compact` or a new session once, if the earlier task is done (in that session every call re-read 150-199k tokens).
- Always-on rule: fetch only what is needed from tools, e.g. specific page elements from the browser instead of full page text.

## 1.4.0 core - 2026-10-28
- Router splits skills into required and optional. Required: domain experts (C#, SQL, UI, clean-code) only on requests that change code, plus specialists for explicit actions (tests, commit/PR, docs, "remember", retro). Optional hints for questions; Claude decides. The workflow skill is no longer auto-loaded (its essentials are always on). Max 2 required + 2 optional per prompt; a required skill is named once per conversation.
- Measured vs 1.3.0 (n=2): question $0.166 -> $0.126 (no skills loaded, close to no-plugin $0.119); planning task $0.230 -> $0.210 (C# + SQL experts loaded), still +30% vs not auto-loading.

## 1.3.0 core - 2026-10-28
- Skills are used automatically when relevant: a UserPromptSubmit hook (`hooks/route.sh`) matches each prompt against keyword rules and tells Claude which companion skills to load (max 3 per prompt, each once per conversation; state in `~/.claude/companion-router/`, pruned after 7 days). Slash commands, short prompts and plain questions get no suggestion.
- The hint is worded as a requirement: a softer "relevant skills" hint reached Claude but was ignored in 4/4 benchmark runs; the required wording loaded the matched skills in 4/4.
- Measured cost of auto-loading (sample repo, n=2): +21% on a short question, +43% on a planning task vs 1.3 without loading, mostly from extra turns (one per skill). Asking for parallel skill calls did not reduce turns.

## 1.2.0 core / 1.1.0 guard - 2026-10-28
- Consent is now once per conversation: one approval before the first file change covers the rest of the conversation. Deletes, schema/data changes, new dependencies, commits and pushes still need their own approval. Updated in the session hook rules, `preflight`, `workflow` and the profile template.
- `companion-guard` asks on the first Edit/Write of each conversation, records the approval per session (`~/.claude/companion-guard/<session_id>`, pruned after 7 days), and allows later file changes in that conversation.
- Benchmark of 1.1.1's stronger output rules: answers 9-15% shorter than 1.1.0, cost not lower (n=2, within noise).

## 1.1.1 - 2026-10-28 (core)
- Stronger always-on output rules in the SessionStart hook: lead with the result, no announcing opener or recap closer, exact wording for negations/code/numbers, changed lines only, full sentences for warnings and questions.
- Correction to 1.1.0: a live headless benchmark showed no skill auto-loads on ordinary prompts (v1.0 or v1.1), so the "no longer loads ~8 skills" saving applies only when `/companion-core:workflow` is invoked. Measured 1.1.0 gains: ~1,400 fewer context tokens per turn than 1.0, and ~32% shorter long answers.

## 1.1.0 - 2026-10-28 (core, dotnet, ui)
- Token efficiency: the SessionStart hook now injects 5 always-on working rules, so they apply without loading any skill.
- `workflow` carries each phase's essentials inline and loads other skills only when a phase needs them (domain experts, init, graph rebuild, retros); a standard task no longer loads ~8 skills.
- `token-economy` rewritten: session habits (`/clear`, `/compact`, `/context`), honest subagent guidance, log reading; in-progress state no longer goes into `changes.md`.
- All 14 skill descriptions trimmed (~5,200 to ~3,200 chars always loaded).

## 1.0.0 — 2026-10-28
- `companion-core`: workflow, preflight, project-memory (+ templates), architecture-map (+ scan-repo.ps1), code-reuse, clean-code, testing-expert, documentation, git-tfs, token-economy, learning-loop; SessionStart knowledge loader hook.
- `companion-dotnet`: csharp-expert, sql-expert (+ review checklists).
- `companion-ui`: ui-ux-expert (visualization & mockups).
- `companion-guard`: PreToolUse consent hook for Edit/Write.
- Installers (`install.ps1`, `install.sh`), `tools/validate.ps1`, skill template.
