# CHANGELOG_AI 2026-07 — player data safety

## 2026-07-20 - Unified player profile and confirmed economy persistence (PR #128)

### Summary

- Replaced unsafe default-profile fallback and full-profile `SetAsync` writes with fail-closed loading, bounded retries, session leases and ownership-checked `UpdateAsync` saves.
- Kept `GlobalPlayerProgress_v1` as the canonical player record across Four Peaks and Level.
- Embedded weapon inventory and lobby profile state under `GlobalPlayerProgress_v1.PlayerState`.
- Converted `PlayerStateStore` into a compatibility API over the unified profile.
- Added one-time, confirmed migration from `PlayerState_v2`; the old record is retained as a recovery backup and is no longer the normal writer.
- Serialized blacksmith, inventory and gacha mutations across services with the shared `EconomyMutationBusy` player attribute.
- Added server rate limits and confirmed save barriers before final success for craft, upgrade, sale, equip, favorites, spell loadout, gacha and WeaponPoints conversion.
- Added confirmed save barriers before lobby/dungeon teleports.
- Fixed inventory selling of the currently equipped weapon by preserving the pre-sale equipped instance ID.

### Persistent compatibility

Unchanged:

- `GlobalPlayerProgress_v1`;
- `GlobalProfile_v4`;
- `PlayerState_v2` and `u:<userId>` legacy keys;
- public `PlayerData` and `PlayerStateStore` method names;
- remote names;
- `TeleportData` fields.

New persisted fields include `_profileMeta`, `PlayerState`, `PlayerStateMigrationVersion`, `PlayerStateMigratedAt` and `PlayerStateLegacyBackupAvailable`.

### Runtime work and cost

- One global-profile maintenance loop remains at 60-second cadence.
- No frame-based loop was added.
- Migrated accounts stop performing normal writes to `PlayerState_v2`.
- High-value mutations intentionally perform one immediate confirmed unified-profile save.
- First migration adds a bounded legacy read, lease acquisition, unified save and legacy lease release.

### Validation performed

- Reviewed public compatibility APIs and active blacksmith, inventory, gacha and teleport call paths.
- Confirmed `SaveScheduler.lua` is restored to its main-branch blob and is no longer part of the PR diff.
- Confirmed the PR adds no `_G`, `Heartbeat`, `Stepped` or `RenderStepped` dependency.
- Confirmed active weapon/economy state has one canonical profile object after migration.
- Confirmed `PlayerState_v2` is only used by migration code in the changed runtime.
- Confirmed high-value lobby services share one cross-service mutation attribute.

### Not verified

Roblox Studio/MCP was unavailable in this environment. The PR still requires:

- Four Peaks and Level compile/Play tests;
- real legacy inventory migration;
- reconnect persistence after craft, upgrade, sale and gacha;
- cross-place teleport round trip;
- two-server lease contention;
- DataStore failure and shutdown tests;
- maximum profile-size test.

### Deployment risk

All old servers must be closed after publishing. A server that cached a profile before this migration can overwrite the new embedded state because the previous code does not enforce the new lease contract.

### Rollback

A plain code revert is safe only before migrated players can mutate inventory. After live mutations, run a reverse migration from embedded `PlayerState` back to `PlayerState_v2` before restoring old code; otherwise weapon progress can roll back to the retained legacy backup.

See `docs/DATA_SAFETY_PHASE_1.md` for the detailed migration, failure and rollout contract.
