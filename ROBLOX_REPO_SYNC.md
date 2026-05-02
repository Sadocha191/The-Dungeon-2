# ROBLOX_REPO_SYNC

This document defines the target standard for mirroring Roblox Studio into the repo without relying on Rojo as the primary workflow.

## Core principles

1. Studio is the current source of truth.
2. The repo should mirror the real Roblox Studio hierarchy.
3. Do not create artificial folders such as `Script`, `LocalScript`, or `ModuleScript` if they do not exist in Studio.
4. Every `Script`, `LocalScript`, and `ModuleScript` in Studio should have a matching `.lua` file in the repo.
5. Every important `Folder` or `Model` used by code should have a matching folder or a `MANIFEST.md` entry in the repo.
6. Important non-script objects should be documented in `MANIFEST.md`.
7. Do not remove repo-only files without an explicit user decision.
8. Repo-only files should be marked as one of:
   - `active`
   - `stale_snapshot`
   - `unknown`
   - `candidate_to_restore_to_studio`
   - `candidate_for_removal_later`
9. Studio-only scripts must be copied into the repo before any system-based reorganization starts.
10. Reorganization by systems can happen only after 1:1 parity is reached.

## Current workflow stance

- `Level/` and `Four Peaks/` are the current historical repo mirrors.
- `src/` and `default.project.json` exist, but they are not the current source of truth for parity work.
- The next parity-safe documentation baseline should point to a dedicated mirror tree under `roblox/`.
- The `roblox/` mirror tree has now started with a small Studio-only parity batch.
- This file defines the standard only. It does not mean the migration is already done.

## Proposed repo structure

```text
roblox/
  Poziom/
    ServerScriptService/
    ReplicatedStorage/
    StarterPlayer/
    StarterGui/
    Workspace/
    ServerStorage/
    ReplicatedFirst/
    Lighting/
    MANIFEST.md

  CzterySzczyty/
    ServerScriptService/
    ReplicatedStorage/
    StarterPlayer/
    StarterGui/
    Workspace/
    ServerStorage/
    ReplicatedFirst/
    Lighting/
    MANIFEST.md
```

## Naming policy

- The repo can keep original Polish place names if the user prefers that.
- The repo can also keep normalized names such as `CzterySzczyty/` if spaces become inconvenient.
- The important part is consistency.
- During the parity phase, a chosen place root name must map to one Studio place only.
- Current legacy names such as `Level/` and `Four Peaks/` should be treated as historical mirrors until a dedicated parity migration is performed.

## Mapping rules

### Scripts

- A Studio `Script`, `LocalScript`, or `ModuleScript` should become one `.lua` file in the repo.
- The file path should match the real Studio parent hierarchy.
- If Studio has `Workspace/NPCs/Witch/WitchNPC`, the repo path should reflect that same tree.
- Avoid artificial compatibility folder layers unless Studio itself has them.
- If a mirrored file cannot be verified as an exact byte match against live Studio, roll back that mirror attempt and mark it as `SKIPPED` in parity documentation instead of keeping a non-exact file under `roblox/`.

### Duplicate-name collisions

- If Studio contains duplicate sibling names under the same parent, the filesystem cannot represent both objects 1:1 by path alone.
- During parity work, do not invent suffixes, counters, or renamed folders just to make the mirror fit.
- If duplicate objects have identical source, keep one canonical `.lua` mirror and record the collision in `STUDIO_REPO_PARITY_PLAN.md` or a local `MANIFEST.md`.
- If duplicate objects do not have identical source, stop and require a separate plan before mirroring further.

### Non-script containers

- Important `Folder`, `Model`, `Tool`, `ScreenGui`, `ProximityPrompt`, `RemoteEvent`, `RemoteFunction`, `BoolValue`, and other code-relevant objects should be represented by:
  - a real folder in the mirrored tree, or
  - a `MANIFEST.md` file when scripts alone are not enough to describe the structure.

### MANIFEST.md purpose

Use `MANIFEST.md` when a path contains important objects that are not scripts, for example:

- `RemoteEvent` and `RemoteFunction` definitions
- `Folder` and `Model` layout expected by `WaitForChild`
- `Tool` internals under `ServerStorage.WeaponTemplates`
- `ScreenGui` structure important for UI scripts
- `ProximityPrompt`, `ValueBase`, and attribute-dependent objects

Each `MANIFEST.md` should describe:

- object name
- Roblox class
- expected children
- critical attributes
- critical tags
- notes about whether the object is mirrored fully or only described

## Repo-only status labels

### `active`

- The file is in the repo and is confirmed to match live Studio use.

### `stale_snapshot`

- The file exists in the repo but the current Studio state does not show a matching live object.
- Keep it until the user decides whether to restore, archive, or remove it later.

### `unknown`

- The file exists in the repo, but current evidence is not enough to decide whether it is active or stale.

### `candidate_to_restore_to_studio`

- The file exists in the repo but current evidence suggests it may need to be restored into live Studio later.
- Do not restore it automatically; first verify gameplay use and current Studio ownership.

### `candidate_for_removal_later`

- The file looks obsolete, but must still stay in the repo until the user explicitly approves cleanup.

## Parity procedure

1. Inspect Studio and confirm the exact live object path.
2. Check whether the repo already mirrors that path.
3. If Studio has a script and the repo does not, add it to the repo first.
4. If the repo has a file and Studio does not, mark it with a status instead of deleting it.
5. Add `MANIFEST.md` coverage for important non-script objects.
6. Update project documentation.
7. Reorganize by systems only after parity is complete.

## Parity levels

### Script parity

- `Script parity` means every known live `Script`, `LocalScript`, and `ModuleScript` from the verified Studio snapshot has a corresponding source file in the repo.
- In this project, that coverage may currently be split across the historical mirrors (`Level/`, `Four Peaks/`) plus the newer parity mirror tree under `roblox/`.
- `Script parity` does not automatically mean the whole `roblox/` tree is already a full standalone export of Studio.

### Full object parity

- `Full object parity` means the repo covers scripts plus the critical non-script hierarchy those scripts depend on.
- This includes important `Tool`, `Model`, `Folder`, `RemoteEvent`, `RemoteFunction`, UI, portal, NPC, and weapon-template structure.
- It also includes documenting duplicate-instance edge cases, critical attributes/tags, and unresolved repo-only snapshots.
- Reorganization by systems should wait for this level, or at minimum for a documented manual decision about which gaps are acceptable to carry forward.

## Things that must not be renamed casually

- `Remotes`
- `RemoteEvents`
- `RemoteFunctions`
- `ModuleScript`
- `ModuleScripts`
- `WeaponTemplates`
- `NPCs`
- `Portal`
- `PortalModel`
- `PortalTeleport`
- all critical attributes and CollectionService tags listed in `PROJECT_MAP.md`
