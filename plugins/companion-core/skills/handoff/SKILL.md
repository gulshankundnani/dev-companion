---
name: handoff
description: Save the current task to a compact handoff file and resume it in a new session, on another login, device or by a teammate, without replaying the old conversation. Use for "save handoff", "hand off", "resume handoff", usage limit reached, or before /clear on unfinished work.
---

# Handoff

A handoff file (~1-2k tokens) replaces replaying a long conversation (often 100k+ tokens re-read on every call). It is the cheapest way to continue after a usage limit, on another login or device, or after `/clear`.

## Save ("save handoff", limit near, context large, end of day)
1. Location (where project memory lives; else ask once and remember the answer in `profile.md`):
   - **Project**: `<repo>/.claude/handoff/` - travels with the repo; another device or teammate gets it by commit, push or a shared folder.
   - **Local**: `~/.claude/handoff/<project>/` - same machine only, any login on it.
2. Write `<yyyy-MM-dd-HHmm>-<task-slug>.md` from the template below. Facts only, no narrative. Exact paths with line numbers, commands, ids, error messages. Never secrets or credentials.
3. Tell the user the path and the resume line: `resume handoff <path>`.

```markdown
# Handoff: <task>
Status: open | Saved: <date time> | Repo: <path> | Branch: <branch or n/a>
## Goal
<one or two lines; user's acceptance criteria>
## Done
- <change> - `path:line` (tested: <how, result>)
## Next (in order)
1. <exact next step; file, function, command>
## Decisions and constraints
- <decision - why>; user preferences given in the conversation
## Verify
- <build/test commands and expected result>
## Open questions
- <question for the user, if any>
```

## Resume ("resume handoff", or the session hook reports an open handoff)
1. Read the newest open handoff (or the one named). Don't re-explore what it already records; read only the files in **Next**.
2. Check that the repo still matches (files in **Done** exist, branch). Report differences before continuing.
3. Continue from **Next**. When the task is done, set `Status: done` and add a short entry to `changes.md`.

## Another login or device
- Same machine, other login: `/login` (CLI) or sign out and in (desktop app), open a new session in the same folder, say `resume handoff`.
- Other device or teammate: share the handoff file (repo commit, shared folder, or paste it), then `resume handoff`.
- `claude --resume <session>` also works on the same machine, but replays the whole conversation; the handoff is far cheaper.
- Use only logins that are yours or a teammate's own; never share credentials.
