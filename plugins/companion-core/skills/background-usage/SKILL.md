---
name: background-usage
description: Stop tokens leaking while background tasks, scripts, builds, subagents or other sessions run - wait without polling, and audit what spent tokens recently on this machine. Use for "background usage", "idle tokens", "what is using tokens", or before long-running work.
---

# Background usage

A waiting session still pays: every call re-reads the whole context. Idle waiting is pure waste.

## While work runs in the background
- Start long commands (builds, test suites, scans, installs, deploys) with `run_in_background`. Then end the turn or do other independent work; the completion notice wakes the session.
- Never poll: no `sleep`/`Start-Sleep` loops, no repeated reads of the output file or log, no "check status" calls. Read the result once, filtered to errors and the summary line.
- External state the harness can't see (CI, a deploy, a remote job): one check timed to how long it takes (a ~10 min CI run = one check at ~10 min), or `Monitor` with an until-condition. `/loop` and `ScheduleWakeup`: 20-30 min for idle checks, never under ~5 min.
- Subagents: only for wide searches; don't wait on them with status checks. Several sessions in parallel multiply cost; start them only when the user asked.
- Scripts that take minutes: run them once with output to a file, then read only the summary.

## Audit (what spent tokens recently)
```
powershell -NoProfile -File "<this skill>/scripts/background-usage.ps1" -Minutes 60
```
Lists every main session and subagent on this machine with calls, context size, weighted tokens (input 1, cache write 1.25, cache read 0.1, output 5), idle-wait calls (sleep, polling, wake-ups under 270 s) and files read more than 3 times. Report: the top consumers, idle share, and one fix per offender (stop it, compact, or switch to background + notification). Also check scheduled tasks and loops (`CronList`, scheduled-tasks list) when those tools exist: a frequent job in a large session costs every run.

Stopping or archiving another session needs the user's yes.
