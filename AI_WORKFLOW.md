# AI_WORKFLOW

This workflow is for future AI-assisted work on this repo.

## Default order of work

1. Reach Studio/repo parity 1:1 first.
2. Keep documentation current while parity work progresses.
3. After parity, do only small LOW-risk migrations first.
4. Reorganize by systems only after parity is complete.
5. Use MCP only for specific verification steps.
6. Create commits only after a manual Roblox Studio test.

## Working expectations

- Read `PROJECT_MAP.md`, `AGENTS.md`, `ROBLOX_REPO_SYNC.md`, `STUDIO_REPO_PARITY_PLAN.md`, and `CHANGELOG_AI.md` before touching code.
- Treat Studio as the source of truth unless the user explicitly says otherwise.
- Prefer minimal diffs.
- Avoid opportunistic refactors.
- Do not rename remotes, modules, attributes, tags, or object folders without a usage audit.
- Keep each task narrowly scoped.

## Recommended execution flow per task

1. Confirm which place is affected: `Poziom`, `Cztery szczyty`, or both.
2. Check whether the task is a parity issue, a bug fix, or a new feature.
3. If parity is not complete for the touched path, fix parity drift first unless the user explicitly wants a live fix first.
4. Use MCP only for the exact object or script that needs confirmation.
5. Apply the smallest repo change that solves the task.
6. Update `CHANGELOG_AI.md`.
7. Report changed files, verification, risks, and rollback.

## Example prompt

```text
Napraw tylko problem: [opis].
Najpierw przeczytaj PROJECT_MAP.md, AGENTS.md i STUDIO_REPO_PARITY_PLAN.md.
Nie zmieniaj innych systemow.
Nie przenos skryptow.
Zrob minimalny diff.
MCP uzyj tylko do konkretnego sprawdzenia.
Na koncu napisz, co mam sprawdzic w Roblox Studio.
```
