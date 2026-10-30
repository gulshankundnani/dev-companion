---
name: csharp-expert
description: C#/.NET expertise (.NET Framework 4.x to .NET 9, ASP.NET Core/MVC, EF Core/EF6/Dapper, WPF/WinForms) - idioms, async, DI, performance, security, upgrades. Use when writing, reviewing, debugging or migrating C# code or .csproj files.
---

# C# / .NET

- **Target first**: check `TargetFramework`/`LangVersion` before using a feature (.NET Framework 4.x: no records, file-scoped namespaces, minimal APIs unless LangVersion allows). Project style (`.editorconfig`, analyzers) beats these defaults.
- **Readable C#**: one-line expressions over ceremony (`?.`, `??`, pattern matching, `switch` expressions, LINQ `Where/Select/Any` over loops with flags) when the target allows and it stays clear; `var` when the type is obvious; small methods, early return; no regions or comment banners.
- **Nullability**: no `!` to silence warnings; guard with `ArgumentNullException.ThrowIfNull`.
- **Async**: end to end, `Async` suffix, pass `CancellationToken`; no `async void` (except handlers), no `.Result`/`.Wait()`.
- **DI**: constructor injection; no scoped inside singleton; `IOptions<T>` for config; `IHttpClientFactory` for HTTP.
- **Logging**: `ILogger<T>` templates (`"Order {OrderId} failed"`), no interpolation, no secrets/PII.
- **Exceptions**: specific types; `throw;` not `throw ex;`; catch-all only at boundaries, with logging.
- **EF**: `AsNoTracking` for reads, `Select` to DTOs, no N+1, paginate, one `ToListAsync` at the end. **Dapper/ADO.NET**: parameterised, dispose connections. Schema changes: see `sql-expert`.
- **Performance**: `StringBuilder` in loops, `Dictionary`/`HashSet` lookups, no repeated `IEnumerable` enumeration; `Span`/`ArrayPool` only on proven hot paths.
- **Security**: validate input, `[Authorize]` by default, anti-forgery on MVC forms, no committed secrets, safe deserialization.
- **Build/test**: `dotnet build -v q`, `dotnet test --no-build -v q --filter …`; .NET Framework: `msbuild <sln> /m /v:m`, `vstest.console.exe`.
- Full review list: `references/review-checklist.md` (read only when reviewing).
