# Project Instructions

- When working in `E:\Github\The-Dungeon-2`, always attempt to connect to Roblox Studio through MCP before doing other project work.
- Start each task by calling `mcp__roblox_mcp__list_roblox_studios`.
- If a Studio instance is available, call `mcp__roblox_mcp__set_active_studio` for that instance and prefer Roblox MCP tools for inspection, editing, playtesting, and verification when relevant.
- If no Studio instance is available or the MCP connection fails, state that briefly and continue with filesystem-based work.

## Required Reading Before Work

- Read `PROJECT_MAP.md`, `AGENTS.md`, `ROBLOX_REPO_SYNC.md`, `STUDIO_REPO_PARITY_PLAN.md`, and `CHANGELOG_AI.md` before making changes.
- Treat those files as the current operational baseline for this repo unless the user explicitly overrides them.

# Project Context

- This is a Roblox survivors game inspired by Vampire Survivors and Megabonk.
- The lobby is a core part of the game and its meta progression.
- Combat is auto-attack based. Weapons attack automatically.
- Runs focus on exploration, loot, portal hunting, boss kills, and level progression.

## AI Working Rules

- Do not move scripts in Roblox Studio until the repo covers Studio 1:1.
- Fix Studio-vs-repo drift before attempting folder cleanup or system-based reorganization.
- Treat Studio as the source of truth unless the user explicitly says otherwise.
- Use MCP sparingly and only for a concrete verification step.
- Do not scan the entire game through MCP unless the task truly requires it.
- Do not rename `RemoteEvent`, `RemoteFunction`, `ModuleScript`, folder, `Attribute`, or `CollectionService` tag names without checking all known usages first.
- Do not refactor unless the user explicitly asks for refactoring.
- Prefer the smallest possible diff.
- One task should solve one problem or one narrowly scoped feature.
- After every repo change, update `CHANGELOG_AI.md`.
- After each change, report changed files, test/verification, risks, and rollback notes.

## Skills

- `the-dungeon-2-workflow`: Workflow and environment guidance for this repo. Use for code, debugging, sync, playtesting, and Studio-vs-filesystem comparisons in `The-Dungeon-2`. File: `C:\Users\Sadocha\.codex\skills\the-dungeon-2-workflow\SKILL.md`
