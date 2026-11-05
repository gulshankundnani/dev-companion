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

**Fall back to grep** for strings, config keys, SQL, comments, and Razor/Blazor `@code` or `@{ }` C#: `.cshtml`/`.razor` get HTML features only (no standalone Razor server exists outside VS/VS Code). Their code-behind (`.razor.cs`, `.cshtml.cs`), controllers and view models get full C# support.

**C# server** (`csharp-ls`) loads the `.sln`/`.slnx` at the workspace root; the first query in a big solution can take a minute. If results are empty, the solution may not have restored: run `dotnet restore` (SDK-style) or open from the folder that holds the `.sln`.

## Setup (once per machine)
```bash
dotnet tool install -g csharp-ls
npm install -g typescript-language-server typescript@5 vscode-langservers-extracted
```
TypeScript must stay on 5.x: TypeScript 7 (native) has no `tsserver.js`, so the JS/TS server fails to start.
.NET Framework (non-SDK) projects need MSBuild from Visual Studio Build Tools for `csharp-ls` to load them.
