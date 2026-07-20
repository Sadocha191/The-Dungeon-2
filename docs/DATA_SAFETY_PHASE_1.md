# Player data safety phase 1

Date: 2026-07-20

## Scope

This phase hardens the existing persistent-data architecture without changing DataStore names, player keys, remotes, TeleportData fields, or gameplay balance.

Implemented:

- fail-closed profile loading for `GlobalPlayerProgress_v1` and `PlayerState_v2`;
- bounded retry/backoff for DataStore reads and writes;
- cross-server session leases stored in `_profileMeta`;
- `UpdateAsync`-based saves that reject stale server ownership;
- one shared, backward-compatible schema for `GlobalPlayerProgress_v1` in Four Peaks and Level;
- confirmed save barriers before lobby-to-dungeon and dungeon-to-lobby teleports;
- dirty-state retention after failed scheduled saves;
- bounded release retries and parallel shutdown flushing;
- Studio-only volatile fallback when DataStore access is unavailable.

## Persistent compatibility

Unchanged:

- `GlobalPlayerProgress_v1` DataStore name;
- `GlobalProfile_v4` legacy source;
- `PlayerState_v2` DataStore name;
- player key formats;
- existing public `PlayerData` and `PlayerStateStore` APIs;
- existing remotes and TeleportData fields.

The only new persisted field is `_profileMeta`, containing schema revision and session-lease metadata. Existing unknown fields are retained by schema sanitization.

Legacy migration is attempted only after a successful main-store read confirms that the current profile does not exist. A failed main-store read can no longer fall through to defaults or legacy data.

## Failure behavior

Production servers:

- do not cache or save a default profile after a load failure;
- kick the player with a retry message when data cannot be acquired safely;
- block teleport when either persistent store fails its save barrier;
- reject a write when another server owns the current lease.

Studio:

- uses a clearly marked non-persistent in-memory profile when DataStore access is unavailable;
- never writes that volatile fallback to production stores.

## Runtime work

New bounded work:

- one maintenance task per persistent module, every 60 seconds;
- dirty profiles are saved, clean profiles renew their lease;
- no Heartbeat, Stepped, RenderStepped, per-NPC, per-drop, or per-projectile loop is added;
- shutdown release operations run in parallel with a 25-second bound.

## Remaining critical architecture work

This phase does not make operations across `GlobalPlayerProgress_v1` and `PlayerState_v2` atomic. Crafting, weapon upgrades, weapon sales, and gacha still mutate two independent records. A later phase must either:

1. move all player economy and weapon-instance state into one session-owned profile, or
2. add an idempotent transaction journal with reconciliation and recovery tooling.

Also not addressed here:

- guild directory hot-key and guild-record concurrency redesign;
- transaction-safe guild treasury operations;
- DataStore version recovery/admin tooling;
- chest, NPC replication, spell targeting, and drop runtime bottlenecks from the audit.

## Validation checklist

Static checks performed for this PR:

- whitespace/diff checks on generated Lua files;
- balanced block/token scan for Luau control structures;
- preserved DataStore names and key formats;
- preserved remote names and TeleportData fields;
- no new `_G` dependency;
- no new frame-based runtime loop.

Not verified in this environment:

- Roblox Studio compile/play test;
- live DataStore outage simulation;
- real cross-place teleport handoff;
- multi-server lease contention;
- shutdown under DataStore throttling.

## Rollback

Revert this PR. Existing records remain readable because DataStore names and key formats are unchanged. `_profileMeta` is ignored by the previous code. Profiles written while this PR is deployed retain all pre-existing fields.
