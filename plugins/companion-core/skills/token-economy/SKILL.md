---
name: token-economy
description: Token-saving playbook: targeted search, partial reads, /clear, /compact, /context, subagents, background waits, concise output. Use when asked to use fewer tokens or a session or codebase is large.
---

# Token economy

The five always-on rules are injected at session start. This is the detail.

## Session habits (biggest savings)
- **`/clear` between unrelated tasks.** Old context is re-sent with every message; a fresh session for a new task is the single largest saving. Record what matters in `.claude/knowledge/` first.
- **Unfinished task, large context or usage limit near**: `handoff` saves the state in ~1-2k tokens; resume it in a fresh session (any login or device) instead of replaying the conversation.
- **Waiting on builds, scripts, CI or subagents**: see `background-usage` (no polling; audit script).
- **`/compact` in long sessions** (optionally with a focus: `/compact keep the Orders refactor plan`).
- **`/context`** shows what is filling the window (files, tool output, MCP tools, skills). Check it when a session feels heavy.
- Disable MCP servers/plugins you don't use in a project; their tool definitions cost tokens every turn.

## Reading
- **Knowledge first**: grep `graph.md` / `reuse-catalog.md` before exploring code.
- **Search, then read**: Grep with `files_with_matches` or `count` first, then `content` with small context; Read with `offset`/`limit`, not whole files.
- Don't re-read a file you just edited or already have in context.
- Skip: `bin/`, `obj/`, `node_modules/`, `dist/`, `*.Designer.cs`, `*.min.js`, migration snapshots, lock files, large generated JSON.
- Logs and long output: read the tail or grep for `error|fail|exception`, never the whole file.

## Subagents
- An Explore subagent keeps file dumps **out of the main context**, but usually spends **more tokens in total**. Use it only for wide searches across many folders where you need just the conclusion; for 2-3 known files, read them yourself.
- Search-only subagents can run on a cheaper model (Haiku).

## Tool use
- Batch independent tool calls in one message.
- Cap command output: `| head -50`, `dotnet build -v q`, test output filtered to failures.
- One precise Edit beats rewriting a file.

## Writing (output)
- Answer or result first. No restating the question, no preamble, no recap of what was already shown.
- Diffs/snippets, not whole files; reference code as `path:line`.
- Plans: bullets, one line each; alternatives only when the trade-off is real.
- Don't narrate tool calls.

## Memory hygiene
- Keep knowledge files short (INDEX <= 40 lines) so loading them stays cheap; link, don't duplicate.
- Long task still in progress? Keep its state in the plan / task list or use `/compact`. `changes.md` is only for finished changes.
