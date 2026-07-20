# Player data safety and single-profile migration

Date: 2026-07-20

## Scope

This change hardens player persistence and removes the split source of truth between account economy and weapon inventory.

Implemented:

- fail-closed loading for `GlobalPlayerProgress_v1`;
- bounded retry/backoff for DataStore reads and writes;
- cross-server session leases stored in `_profileMeta`;
- ownership-checked `UpdateAsync` saves;
- one shared, backward-compatible `GlobalPlayerProgress_v1` schema in Four Peaks and Level;
- weapon instances, equipped weapon, favorites, tutorial and compatibility profile state embedded under `GlobalPlayerProgress_v1.PlayerState`;
- one-time migration from `PlayerState_v2` before inventory systems become ready;
- preservation of the old `PlayerState_v2` record as a rollback/recovery backup;
- confirmed save barriers for blacksmith, inventory, gacha, currency conversion and cross-place teleports;
- per-player serialization and server-side rate limits for high-value lobby mutations;
- dirty-state retention, bounded release retries and parallel shutdown flushing;
- Studio-only volatile fallback when DataStore access is unavailable.

## Persistent model

Canonical player record:

```text
GlobalPlayerProgress_v1 / <userId>
```

The record now contains both account progression and embedded lobby state:

```text
silver, tickets, materials, pity, missions, ...
PlayerState = {
    WeaponInstances,
    EquippedWeaponInstanceId,
    FavoriteWeapons,
    Tutorial,
    Profile,
    ...
}
```

`PlayerStateStore` remains the public compatibility API used by existing lobby systems, but its mutations now modify the same in-memory profile owned by `PlayerData`. It no longer performs normal runtime writes to `PlayerState_v2`.

New top-level fields:

- `_profileMeta`;
- `PlayerState`;
- `PlayerStateMigrationVersion`;
- `PlayerStateMigratedAt`;
- `PlayerStateLegacyBackupAvailable`.

Existing unknown fields are retained by schema sanitization in both Four Peaks and Level.

## Migration

For an account without `PlayerStateMigrationVersion >= 1`:

1. `GlobalPlayerProgress_v1` must load and acquire its session lease successfully.
2. `PlayerState_v2 / u:<userId>` is read.
3. When a legacy record exists, a temporary migration lease is acquired.
4. The legacy state is sanitized and copied into `GlobalPlayerProgress_v1.PlayerState`.
5. The unified profile must complete a confirmed save.
6. Only then is `PlayerStateReady` set and inventory/economy systems may use the state.
7. The legacy lease is released. The old record is not deleted.

A failed migration does not expose a default inventory in production and does not overwrite the old record.

## Atomic economy behavior

Crafting, upgrades, weapon sales and gacha now mutate one cached profile. Their cost and result are persisted in one `UpdateAsync` snapshot, so a successful record cannot contain only one side of the operation.

High-value remote operations are serialized per player. After a successful mutation, the server confirms persistence before returning or broadcasting final success.

If the save cannot be confirmed:

- the profile remains dirty for release/shutdown retry;
- further economy mutations are blocked for that server session;
- production removes the player with a retry message;
- the client cannot continue stacking unconfirmed operations.

A Roblox DataStore error is not interpreted as proof that the backend committed nothing. Because the whole operation is one profile snapshot, a reconnect resolves to either the old complete state or the new complete state instead of a split cost/reward state.

## Compatibility

Unchanged:

- `GlobalPlayerProgress_v1` DataStore name;
- `GlobalProfile_v4` legacy source;
- `PlayerState_v2` DataStore name and `u:<userId>` key format;
- public `PlayerData` and `PlayerStateStore` method names;
- existing remote names;
- existing `TeleportData` field names;
- weapon instance identifiers and payload shape.

`PlayerState_v2` remains readable for migration and recovery but is no longer the active writer after migration.

## Runtime and DataStore cost

Normal post-migration runtime uses one active player profile and one lease-renewal/autosave loop every 60 seconds.

One-time migration adds bounded work per account:

- legacy read;
- temporary legacy lease acquisition;
- unified profile save;
- legacy lease release.

After migration, normal inventory and economy changes no longer write a second DataStore record. Confirmed high-value mutations intentionally add an immediate unified-profile save.

No `Heartbeat`, `Stepped`, `RenderStepped`, per-NPC, per-drop or per-projectile loop is added.

## Mandatory deployment procedure

This change must not be rolled out beside long-lived servers running the previous data code.

Required production sequence:

1. Publish matching Four Peaks and Level persistence scripts.
2. Verify a staging account migration and cross-place round trip.
3. Publish the universe update.
4. Shut down all old servers so a pre-migration cached snapshot cannot overwrite the unified profile.
5. Monitor profile-load, session-lock and migration-save failures before enabling broad traffic.

A rolling deployment without closing old servers is unsafe because the previous code does not enforce the new session lease contract.

## Validation checklist

Static validation performed:

- preserved DataStore names and key formats;
- preserved public store APIs, remote names and `TeleportData` fields;
- account and inventory mutations now share one profile object;
- `PlayerState_v2` has no normal post-migration writer;
- blacksmith, inventory and gacha mutations have per-player locks and confirmed saves;
- no new `_G` dependency;
- no new frame-based runtime loop;
- unused `SaveScheduler` changes were removed from the diff.

Still required in Roblox Studio/staging:

- Luau compile and Play tests in Four Peaks and Level;
- migration of a real legacy inventory with crafted/upgraded weapons;
- craft, multi-step upgrade, equipped-weapon sale and gacha persistence across reconnect;
- real lobby -> dungeon -> lobby round trip;
- two-server session contention;
- simulated DataStore failure during migration and immediately after a mutation;
- shutdown while a save is failing;
- profile-size test with the maximum supported weapon inventory.

## Remaining audit work

Not addressed by this player-profile change:

- guild directory hot-key and guild-record concurrency redesign;
- transaction-safe guild treasury operations;
- DataStore version recovery/admin tooling;
- chest, NPC replication, spell targeting and drop runtime bottlenecks.

## Rollback

Do not simply revert after players have performed post-migration inventory mutations.

The legacy `PlayerState_v2` record is retained, but it is not updated after migration. A plain code rollback would therefore restore an older weapon inventory.

Safe rollback requires one of these conditions:

- rollback before migrated players can mutate inventory; or
- a reverse migrator that writes the current embedded `PlayerState` back to `PlayerState_v2` before old code is restored.

`GlobalPlayerProgress_v1` itself remains backward-readable because previous code ignores unknown fields, but inventory rollback requires the explicit procedure above.
