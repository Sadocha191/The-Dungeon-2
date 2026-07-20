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
- Removed a duplicate dungeon-teleport save barrier that wrote the same unified profile twice per player.
- Fixed legacy `coins` migration so a missing raw `silver` field cannot be masked by the schema default.
- Serialized a failed offline release with a same-server reconnect so a stale snapshot cannot overwrite the new session.
- Blocked the cached profile after ownership-checked save/renew reports `SessionLost` or `ProfileMissing`.
- Kept the released `PlayerState_v2` backup aligned with the exact migrated weapon instance IDs.

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
- High-value mutations intentionally perform one immediate confirmed unified-profile save; dungeon teleport also performs one barrier per player.
- First migration adds a bounded legacy read, lease acquisition, unified save and legacy lease release.

### Validation performed

- Reviewed public compatibility APIs and active blacksmith, inventory, gacha and teleport call paths.
- Confirmed `SaveScheduler.lua` is restored to its main-branch blob and is no longer part of the PR diff.
- Confirmed the PR adds no `_G`, `Heartbeat`, `Stepped` or `RenderStepped` dependency.
- Confirmed active weapon/economy state has one canonical profile object after migration.
- Confirmed `PlayerState_v2` is only used by migration code in the changed runtime.
- Confirmed high-value lobby services share one cross-service mutation attribute.
- Ran 36 in-memory Studio assertions for lease acquire/save/release, contention, expiry takeover, callback replay, retry recovery, corrupt/missing records, legacy and upgraded weapon migration, unknown-field retention, `coins -> silver`, migration markers and loadout compatibility.
- Ran 12 in-memory assertions for same-server reconnect ordering: pending release always settles before reads/acquire, transient or missing-record failure blocks the reconnect, recovery snapshots are retained, and terminal stale ownership is cleared safely.
- Ran 13 in-memory assertions for leave/shutdown failure behavior: one initial release plus three bounded retries, retained snapshot after exhaustion, worker cleanup and settlement before reconnect.
- Measured a deliberately oversized upgraded inventory profile: 500 instances encoded to 312,946 bytes and 5,000 to 3,119,948 bytes; the current weapon catalog contains 59 entries.
- Four Peaks Play loaded the changed persistence, inventory, blacksmith, gacha and portal services; verified the embedded state is the same profile object, weapon add/equip, a banner roll, remote classes and a confirmed volatile save.
- Level Play loaded the matching persistence modules, completed the loading gate with phase `running` and `RunStarted=true`, and verified return-teleport remotes plus a confirmed volatile save.
- Studio smoke tests used temporary Studio-only volatile guards and fake stores. The guards and harness objects were removed; normalized repository and Studio checksums match for every synchronized #128 script.

### Not verified

- No real DataStore record was read or written during this review.
- A staging-account migration, persistence across a real reconnect, cross-place teleport round trip and two live-server lease contention still require a non-production staging universe.
- Production publish, old-server shutdown and production-data inspection were intentionally not performed.

### Deployment risk

All old servers must be closed after publishing. A server that cached a profile before this migration can overwrite the new embedded state because the previous code does not enforce the new lease contract.

### Rollback

A plain code revert is safe only before migrated players can mutate inventory. After live mutations, run a reverse migration from embedded `PlayerState` back to `PlayerState_v2` before restoring old code; otherwise weapon progress can roll back to the retained legacy backup.

See `docs/DATA_SAFETY_PHASE_1.md` for the detailed migration, failure and rollout contract.
