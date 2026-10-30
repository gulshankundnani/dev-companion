---
name: sync-usage
description: Sync Claude Code usage from every device logged in to this account into the Claude Usage Hub - publishes this device, then asks one Remote Control session on each other device to publish too. Use for /sync-usage, "sync usage", "sync usage across devices", "collect usage from all devices".
---

# Sync usage across devices

1. Publish this device: follow "Publish to the hub" in the `companion-analytics:usage-analytics` skill.
2. `ListAgents`. Keep rows that are Remote Control sessions on another machine; pick one per machine (prefer idle). Skip cloud sessions (no local transcripts) and local sessions (same device).
3. `SendMessage` to each: `Publish my usage to the hub (companion-analytics:usage-analytics, "Publish to the hub"), then reply "published <COMPUTERNAME>: <months>" or the error.` Send all, then end the turn; replies arrive as messages.
4. When all replied (or after one more turn), reply in a short table: device, result. Name devices with no reachable session: they need to be on, the Claude app open, Remote Control on, and the plugin installed. Give the hub link.

Never send prompt text or other data between devices; each device writes only its own rows.
