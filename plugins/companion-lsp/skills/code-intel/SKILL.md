---
name: code-intel
description: Navigate C#, JavaScript/TypeScript, CSS, HTML and Razor/Blazor code with the LSP tool - go to definition, find references/callers, hover types, document/workspace symbols, diagnostics after edits. Use for "where is X defined", "who calls X", "what uses X", rename impact, or checking an edit compiles, before falling back to grep.
---

# Code intelligence via LSP

**Prefer LSP over grep for symbols** in `.cs`, `.js/.ts`, `.css/.scss`, `.html`, `.cshtml`, `.razor`:
- Definition of a type/method/variable: `goToDefinition` at the usage.
- Callers / impact of a change: `findReferences` (exact, ignores same-named text), then `incomingCalls` for call chains.
- Type or signature without opening the file: `hover`.
- Outline of a large file: `documentSymbol`, then read only the needed line range.
- Class or method anywhere in the solution: `workspaceSymbol`.
- Interface implementations: `goToImplementation`.

**After editing**, check diagnostics for the changed file before building; fix errors you introduced.

**`.cshtml` views (razor-bridge)**: `.cs` and `.cshtml` share one server, `servers/razor-bridge.js`, which passes `.cs` straight to `csharp-ls`. No Razor compiler runs, so in a view:
- `goToDefinition` / `hover` / `findReferences` / `prepareCallHierarchy` on a C# name resolve **by name** through `workspaceSymbol`, narrowed by the qualifier (`Constants.X`, `Model.X` -> the `@model` type) and by types the view mentions. Several symbols with the same name -> several definitions; hover says how many.
- `findReferences` on a C# symbol, from a `.cs` file or a view, also lists **view call sites by text match**: static -> `Type.Name`, extension -> `.Name(`, instance -> `.Name` in views that mention the type, type -> the word. Treat view hits as candidates, not compiler-exact; capped at 5,000.
- `documentSymbol` and other markup requests go to the HTML server.
- No C# diagnostics in views: compile-check them with the project's own tool (e.g. a view-compat script) or a build.
`.razor` (Blazor) still gets HTML features only; its code-behind `.razor.cs` gets full C# support.

**Fall back to grep** for strings, config keys, SQL and comments.

**C# server** (`csharp-ls`) loads the `.sln`/`.slnx` at the workspace root; the first query in a big solution can take a minute. If results are empty, the solution may not have restored: run `dotnet restore` (SDK-style) or open from the folder that holds the `.sln`.

## Setup (once per machine)
```bash
dotnet tool install -g csharp-ls
npm install -g typescript-language-server typescript@5 vscode-langservers-extracted
```
TypeScript must stay on 5.x: TypeScript 7 (native) has no `tsserver.js`, so the JS/TS server fails to start.
.NET Framework (non-SDK) projects need MSBuild from Visual Studio Build Tools for `csharp-ls` to load them.
`node` must be on PATH (razor-bridge). Debug the bridge with `RAZOR_BRIDGE_LOG=<file>`; override the servers with `RAZOR_BRIDGE_CSHARP` / `RAZOR_BRIDGE_HTML`.
