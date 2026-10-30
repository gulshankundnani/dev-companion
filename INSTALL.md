# Installing Dev Companion from the zip

Requires Claude Code (desktop app or CLI) and the `claude` command on PATH.

## 1. Extract to a permanent folder
Extract the zip to a folder you'll keep, for example `C:\Tools\dev-companion`.
Claude Code reads the plugins from this folder, so **don't extract to Downloads or Temp and don't delete it later**.

## 2. Install

**Windows (PowerShell)**: open PowerShell in that folder and run:
```powershell
Get-ChildItem -Recurse | Unblock-File     # Windows blocks scripts from downloaded zips
.\install.ps1                             # core + dotnet + ui
.\install.ps1 -Plugins companion-core,companion-dotnet,companion-ui,companion-guard   # also enforce one approval per conversation before edits
```

**macOS / Linux**
```bash
sh install.sh
```

**Or from inside Claude Code**, no script needed:
```
/plugin marketplace add C:\Tools\dev-companion
```
Then open `/plugin` → Discover and install the `companion-*` plugins you want.

## 3. Start using it
Restart Claude Code (or run `/reload-plugins`). In a project, say *"initialise project memory"*, or start a task with:
```
/companion-core:workflow <describe your task>
```

## Updating to a new zip
Extract the new zip over the same folder, then run:
```
/plugin marketplace update dev-companion
```

## Uninstalling
```
/plugin uninstall companion-core@dev-companion
/plugin marketplace remove dev-companion
```
Repeat the first command for each `companion-*` plugin you installed.
