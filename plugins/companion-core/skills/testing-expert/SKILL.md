---
name: testing-expert
description: Testing: prove suggested code before editing, edge cases, validation and security tests (XSS, CSRF, injection, brute force, access control, pooling, sniffing), tests in the project's framework, faithful reporting. Use when testing, fixing a bug test-first, or asked about tests or security.
---

# Testing expert

## Strategy
- **Detect first**: find the existing test projects, framework, mocking library, naming and folder conventions; copy them. Don't introduce a new framework.
- **Bug fix**: write a failing test that reproduces the bug → fix → test passes.
- **New feature**: test behaviour through the public surface; cover happy path, edge cases (null/empty/boundaries), error paths, and authorization where relevant.
- **Pyramid**: many fast unit tests; integration tests for DB/HTTP/serialization boundaries; few E2E/UI tests for critical flows.
- Don't test framework code, trivial getters, or implementation details that make refactoring painful.

## Test before editing
Prove suggested code works before it touches the real files. Work in the scratchpad (or a temp folder), never in the repo.
- **Bug fix / behaviour change**: write the failing test first, run it (red), then make the edit (green).
- **Logic, regex, parsing, date/number formatting, algorithms**: run the snippet with representative and edge inputs.
  - C#: existing test project (`dotnet test --filter`), or a scratch console (`dotnet new console -o <scratch>`, paste, `dotnet run`). .NET Framework: a scratch test in the existing test project, or `csc` + run.
  - JavaScript: `node -e` / a scratch `.js` for pure logic; DOM/jQuery in the running page's console or the browser tool on a local copy.
  - SQL: `BEGIN TRAN; ...; SELECT` the result; `ROLLBACK;` on a dev database (consent names server and database); or a temp table/table variable with sample rows. Check the plan for queries on large tables.
  - Any other language: its REPL or a scratch file.
- **Can't run it** (needs prod data, credentials, hardware): say so, test what can be isolated, and list manual checks.
- Report with the plan: inputs tried, actual output, what was not covered. Keep the scratch code if it can become the real test.
- Skip for trivial edits (text, rename, config value) and say it was skipped.

## Thorough, not just happy path
For every change test: happy path, edge and invalid inputs, error paths. When the change touches user input, login/session, data access, HTML output, files or external calls, also run the security tests that apply - brute force, validation bypass, access control/IDOR, SQL and other injection, XSS, CSRF, sniffing (network, MIME, SQL parameter), connection/HTTP pooling, OWASP misconfig and vulnerable packages. Playbook with payloads and pass criteria: `references/thorough-tests.md` (read when such a change is tested). Security tests only on local/dev environments of the user's own app.

## Writing tests
- Name: `Method_Scenario_ExpectedResult` (or the project's existing convention).
- Arrange–Act–Assert, one logical assertion per test; use builders/fixtures already in the project.
- Deterministic: no real clock, randomness, network or shared state — inject `TimeProvider`/clock, seed data, use test containers or in-memory fakes per project convention.
- Mock only what you own at boundaries; prefer fakes over deep mock chains.
- DB: tests run in a transaction / isolated database; tSQLt for stored-proc logic when the project uses it.

## Running
- Use the project's commands (`profile.md`). Typical: `dotnet build -v q` then `dotnet test --no-build -v q`, filter with `--filter FullyQualifiedName~Area`; `npm test -- --watchAll=false`.
- Show only failures and the summary line (token economy).
- Run the narrowest relevant tests first, then the broader suite if the change is cross-cutting.

## Reporting (faithful)
- List each test area as passed, failed or not tested with the reason (format in the playbook).
- State exactly what ran and the result: "Build OK; 142 passed, 0 failed (Orders.Tests)".
- If something was not run (no tests exist, needs DB, needs credentials), say so and give manual verification steps.
- Never claim a pass you didn't observe. If tests fail, show the relevant output and your diagnosis.
- A pre-existing failing test unrelated to your change: report it, don't "fix" it silently.

## Record
Flaky test, slow suite, or required setup discovered → `lessons.md` / `profile.md` (Commands).
