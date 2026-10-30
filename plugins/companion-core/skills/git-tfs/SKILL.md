---
name: git-tfs
description: Git and Azure DevOps/TFS (Git and TFVC) - branches, commits, shelvesets, PRs, work items, history/blame, conflicts. Use for any commit, branch, PR, check-in, shelve or merge, or to learn why code changed.
---

# Git / Team Foundation

## Safety rules (always)
- **Commit, push, check in, shelve, create PRs only when the user asks.** Show the message/file list first.
- Before any change: check state (`git status` / `tf status`) and never overwrite or discard the user's uncommitted work.
- Never force-push, reset --hard, rewrite published history, delete branches, or undo pending TFVC changes without explicit consent.
- Never commit secrets, `bin/`, `obj/`, `.vs/`, `*.user`, local settings, or `profile.local.md`.
- On the default/protected branch? Suggest a feature branch first.

## Detect which system
- `.git/` folder → Git (remote may be Azure DevOps: `dev.azure.com` / `visualstudio.com` / on-prem `tfs` URL).
- `$tf/` folder or `tf workfold` succeeds → TFVC. `tf.exe` ships with Visual Studio (Developer PowerShell).
Record it in `profile.md`.

## Git
- Context: `git log --oneline -15 -- <path>`, `git blame -L <a>,<b> <file>`, `git log -S "<symbol>"` (when was it introduced) — use history to understand *why* code is as it is.
- Branch naming per project convention (e.g. `feature/<id>-<slug>`, `bugfix/<id>-<slug>`).
- Commit: small, logical, imperative subject ≤ 72 chars; body = why. Link work items: `AB#1234` (Azure Boards) or project convention.
- Stage specific files (`git add <paths>`), not `git add -A`, unless the user wants everything.
- PR (Azure DevOps CLI): `az repos pr create --source-branch <b> --target-branch <t> --title "<t>" --description "<d>" --work-items <id>`; GitHub: `gh pr create`. Use the `documentation` PR template.
- Conflicts: explain both sides, propose a resolution, apply after consent, then build + test.

## TFVC (Team Foundation Version Control)
- Status / history: `tf status`, `tf history <path> /recursive /stopafter:15 /format:brief`, `tf annotate` (blame, VS UI) .
- Get latest: `tf get <path> /recursive` (ask first — may overwrite local).
- Edit is implicit in local workspaces; server workspaces need `tf checkout <file>`.
- Shelve (safe sharing/backup): `tf shelve "<name>" <paths> /comment:"<msg>"`.
- Check in (only on request): `tf checkin <paths> /comment:"<msg>" /associate:<workItemId>`.
- Undo (destructive — ask): `tf undo <path>`.

## Record
Branching model, commit/PR conventions, work-item format → `profile.md`. Useful "why" found in history → `decisions.md` or `changes.md`.
