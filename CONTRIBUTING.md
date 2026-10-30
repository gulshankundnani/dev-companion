# Extending & upgrading Dev Companion

## Principles
- **One responsibility per skill.** If two skills would give conflicting advice, merge them or make one hand off to the other.
- **Short SKILL.md, deep references.** Keep `SKILL.md` ≤ ~120 lines; put long checklists/examples in `references/*.md` and link them. Only `name` + `description` are loaded until a skill is used, so descriptions must carry the trigger words.
- **Respect the shared contract** — every skill:
  - honours the consent gate in `preflight` for edits and destructive actions,
  - reads/writes knowledge only in the `.claude/knowledge/` layout defined by `project-memory`,
  - follows `token-economy`.

## Add a skill to an existing plugin
1. Copy `templates/SKILL.template.md` to `plugins/<plugin>/skills/<skill-name>/SKILL.md`.
2. `name` must equal the folder name (kebab-case). Write a description that says *what* and *when* (trigger phrases, file types).
3. If it belongs in the sequence, add a row to the phase table in `plugins/companion-core/skills/workflow/SKILL.md`.
4. Add it to the skill map in `README.md`.

## Add a new domain plugin (e.g. Angular, Python, Azure)
1. Create `plugins/companion-<domain>/.claude-plugin/plugin.json` (copy one from `companion-dotnet`).
2. Add `skills/<skill>/SKILL.md` files.
3. Register it in `.claude-plugin/marketplace.json` with the same `name` and `version`.
4. Reference it from `workflow` phase 7 ("domain expert") if it's an implementation expert.

## Upgrade a skill
- Edit in place; keep backward-compatible knowledge file formats (other projects already have `.claude/knowledge/` files). If a format must change, make the skill migrate old files on first use.
- Ideas for upgrades often come from `learning-loop` retros — a lesson that recurs across projects usually belongs in a skill, not in memory.

## Release
1. Bump `version` in the plugin's `plugin.json` **and** its entry in `marketplace.json` (semver: patch = wording, minor = new skill/rule, major = knowledge-format change).
2. Add a line to `CHANGELOG.md`.
3. Run `powershell -NoProfile -File tools\validate.ps1`.
4. Commit, tag (`claude plugin tag plugins/<plugin>` creates `<name>--v<version>`), push.
5. Users update with `/plugin marketplace update dev-companion`.

## Test a change locally
- `claude --plugin-dir plugins/companion-core` loads a plugin from disk for one session without installing.
- Try the skill's trigger phrases in a real repo and check it activates and behaves.
