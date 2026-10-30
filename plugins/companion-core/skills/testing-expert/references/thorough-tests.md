# Thorough test playbook

Read when testing a change that touches user input, authentication, sessions, data access, HTML output, files or external calls. Pick the sections that apply; report each as passed, failed or not tested (with reason).

**Scope and safety**: run security tests only against local or dev environments of the user's own application. Never against production or third-party systems. Load and brute-force loops: small counts on shared dev servers, and ask first.

## 1. Edge cases and validation
- Inputs: null, empty, whitespace, min/max and +-1, negative, zero, very long (10k chars), Unicode/emoji/RTL, leading zeros, special characters (`' " < > & % _ ; \`), wrong type.
- Dates: leap day, month end, time zones, DST change, culture formats (`dd/MM` vs `MM/dd`), decimal separators.
- **Server-side validation on every field**: bypass the browser (post directly with curl/Postman/browser tool, or disable JS). Client-only validation = fail.
- Over-posting / mass assignment: post extra fields (`IsAdmin=true`, `Fee=0`, another user's `Id`); only view-model/allow-listed fields may bind.
- Double submit and concurrency: click twice, two tabs editing the same record; expect one result or a concurrency error, not duplicates.
- File uploads: wrong extension, renamed executable, oversized, zero bytes, `..\..\name`, duplicate name; check type by content, size limit, stored outside web root, random name.
- Errors: friendly message to the user, details only in logs, no stack trace in the response.

## 2. Brute force and authentication
- Login, OTP, password reset, PIN: N+1 wrong attempts -> lockout or throttling (per account and per IP); lockout expiry works.
- Same message and similar response time for wrong user and wrong password (no user enumeration); same for "forgot password".
- Password rules, hashed storage (no plain/reversible), reset tokens single-use and expiring.
- Session: new session ID after login (no fixation), logout and timeout invalidate it server-side, `HttpOnly` + `Secure` + `SameSite` cookies.

## 3. Access control (most common real bug)
- IDOR: change ids in URL, query, form, AJAX (`/Fees/Edit/123` -> another student's/org's id); expect 403/404.
- Call every action as: anonymous, lowest role, other tenant/trust/branch. Hidden buttons are not protection: call the URL directly.
- `[Authorize]`/role checks on controllers and AJAX endpoints; downloads and reports included.

## 4. Injection
- **SQL**: payloads `'`, `' OR 1=1--`, `'; WAITFOR DELAY '0:0:5'--`, `%` and `_` in LIKE searches, column names in sort/filter (`ORDER BY` from input must be allow-listed). Expect: no error leak, no delay, no extra rows. Code check: parameters everywhere; dynamic SQL only via `sp_executesql` with parameters + `QUOTENAME`.
- Command, LDAP, XPath: no input concatenated into commands/queries.
- Path traversal: `..\`, `../`, encoded `%2e%2e%2f`, absolute paths in file names/ids.
- Header/CRLF and log injection: `%0d%0a` in values written to headers or logs.
- Deserialization: no `TypeNameHandling.All`/`BinaryFormatter` on untrusted data.
- Open redirect: `returnUrl=https://evil.example` must be rejected (`Url.IsLocalUrl`).
- SSRF: user-supplied URLs fetched by the server are allow-listed.

## 5. XSS
- Payloads in every text field that is shown again (stored), in query strings (reflected) and in values used by JS (DOM): `<script>alert(1)</script>`, `"><img src=x onerror=alert(1)>`, `javascript:alert(1)` in links, `'-alert(1)-'` inside JS strings.
- Expect them displayed as text, never executed. Check contexts: HTML body, attributes, `<script>` blocks (use `Json.Encode`/`JsonSerializer`), URLs.
- Code check: no `Html.Raw` on user data; jQuery `.text()`/`.val()` not `.html()`/`.append(string)` for user data; no `eval`/`innerHTML` with user data.
- Headers: `Content-Security-Policy` where the app allows it.

## 6. CSRF
- Every state-changing action is POST/PUT/DELETE (no changes on GET) with `[ValidateAntiForgeryToken]` (or a global filter); AJAX sends the token header.
- Test: replay the POST without the token, or with another session's token -> rejected (400). Auth cookies `SameSite=Lax` or `Strict`.

## 7. Sniffing
- **Network**: HTTPS only, HTTP redirects to HTTPS, HSTS, TLS 1.2+; no passwords, tokens or personal data in URLs (they end up in logs and history); `Secure` cookies; no secrets in JS, HTML comments, or logs.
- **MIME sniffing**: `X-Content-Type-Options: nosniff`; downloads with correct `Content-Type` and `Content-Disposition: attachment`.
- **SQL parameter sniffing**: run the proc/query with skewed parameters (a small and a very large customer/trust/date range), compare duration and plans; fix with rewrite, `OPTIMIZE FOR`, `RECOMPILE` on that statement, or split procs.

## 8. Pooling and resources
- DB connections: every connection/command/reader in `using`; no connection kept in static fields. Load test: more concurrent requests than `Max Pool Size` (default 100) -> no "timeout expired ... pool" errors; watch `sys.dm_exec_sessions` count return to baseline.
- `HttpClient`: reused (factory/static), not `new` per call (socket exhaustion).
- Thread pool: no `.Result`/`.Wait()` in request paths (starvation under load).
- Memory/handles: repeat the action 100x, memory and handle counts stay flat; files and streams disposed.
- Rate/size limits: large payloads, huge page sizes (`pageSize=100000`), long-running reports have limits or timeouts.

## 9. Other known vulnerabilities (OWASP Top 10)
- Vulnerable components: `dotnet list package --vulnerable --include-transitive`, `npm audit`, old jQuery/Bootstrap versions in `Scripts/`.
- Misconfiguration: `customErrors`/`DeveloperExceptionPage` off in release, `debug="false"`, no `Server`/`X-Powered-By`/`X-AspNet-Version` headers, directory browsing off, `X-Frame-Options`/`frame-ancestors` (clickjacking).
- Secrets: none in source, config committed to the repo, or client code.
- Logging: security events (login failures, access denied) logged without passwords or personal data.
- Crypto: no MD5/SHA1 for passwords, no home-made encryption, random tokens from a CSPRNG.

## Report format
```
Tested: edge/validation 14 cases pass; SQL injection 4 payloads pass; XSS 3 fields pass;
CSRF token missing -> 400 pass; IDOR /Fees/Edit/{id} other trust -> 403 pass.
Failed: none. Not tested: brute force (no login change), pooling under load (no dev load tool).
```
