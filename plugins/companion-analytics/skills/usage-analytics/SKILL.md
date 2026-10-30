---
name: usage-analytics
description: Claude Code usage analytics across devices - token usage per device, app and project, relative cost, prompt analysis (short/vague vs detailed prompts, correction rate) and sessions that should have been compacted. Publishes this device's usage to the Claude Usage Hub artifact. Use for "usage analytics", "token usage per device", "prompt analysis", "where do my tokens go across machines", "publish my usage to the hub".
---

# Usage analytics

Plan limits are account-wide; per-device data exists only in each machine's local transcripts. `<dir>` = `$env:LOCALAPPDATA\companion-analytics`; `<s>` = this skill's `scripts` folder.

## Find or create the hub (each person has their own)
Hub = the URL in `<dir>\hub.txt`. If missing: `Artifact` `list` (`limit` 200); an artifact titled "Claude Usage Hub" is the hub. Still none ("create my usage hub"): copy `<skill dir>\hub\usage-hub.html` to your scratchpad, publish it with `icon` "chart" and `capabilities` `{"db":{"rules":[{"path":"usage","read":"owner","write":"owner"}]}}`. Save the URL to `<dir>\hub.txt`. Never write to another person's hub.

## Publish to the hub (default; "publish my usage to the hub")
Documents: collection `usage`, id `<DEVICE>~<YYYY-MM>`, rows upserted by app+project+day. No prompt text.
1. `powershell -NoProfile -File "<s>\collect-usage.ps1" -OutDir "<dir>"`
2. `ArtifactData` `query`, collection `usage`, `where [["device","==","<COMPUTERNAME>"]]`, `limit` 100, `out_dir` `<dir>\hub-existing`. Note each id's `version` from the result.
3. `powershell -NoProfile -File "<s>\hub-rows.ps1" -InFile "<dir>\<COMPUTERNAME>.usage.json" -ExistingDir "<dir>\hub-existing" -Versions "<id>=<version>,..."` (omit `-Versions` if step 2 found none). Prints the `writes` array.
4. `ArtifactData` `batch` with those `writes` unchanged. A version conflict: redo from step 2. Refused as not found: the hub isn't yours; delete `<dir>\hub.txt` and find or create it.
5. Reply in one line: months written, hub link. Don't read the JSON files.

New device, once: install this plugin; turn on Settings > "Connect new sessions to Remote Control" (the user does it). Then `/companion-analytics:sync-usage` on any device collects from all connected ones.

## Markdown report (offline, optional)
`powershell -NoProfile -File "<s>\usage-report.ps1" -InDir <folder of *.usage.json>` writes `usage-report.md` (`-OutFile`, `-Since`, `-Top`). Read headline tables only (grep `^## ` then line ranges). Collector options: `-Since 2026-10-01`, `-CompactAt 130000`, `-ProjectsDir`.

Cost = input-token equivalents (input 1, cache write 1.25, cache read 0.1, output 5): relative weights, not prices. Team plans have no per-token bill. Habits to suggest: compact or start fresh past ~130k; add paths, expected result and constraints to short prompts that get corrected.
