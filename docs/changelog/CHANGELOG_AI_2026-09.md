# Changelog AI — 2026-09

## 2026-09-01 — LightningVFX and Gates of Babilon targeting fixes

### Changes and ownership

- `Lightning` now dispatches the authored `ReplicatedStorage.Assets.Animations.LightningVFX` template through the existing `SpellVFXEvent` authored-cast path. Damage, stun, repeats and server authority remain in the existing Nova execution.
- Higher-level `GatesOfBabilon` casts now reveal portals in a staggered sequence instead of broadcasting every `GilgameshMain` in the same frame. Each portal has a 0.5-second wind-up before its projectile is fired, and a dead assigned target is reacquired at reveal or fire time.
- Runtime spell-stat finalization now copies the post-upgrade `baseCount` back to `count`. This restores the documented Gates progression of 1/2/3/4/6 portals at levels 1/5/10/15/20; the shared catalog fix is also applied to the `Four Peaks` mirror.
- Each `GilgameshMain` is rotated by -90 degrees around its local X axis so its authored firing axis points at the target. Its world offset is converted to player-root space and the cloned VFX is welded to the current `HumanoidRootPart`, so the portal follows player movement during the wind-up.
- The shared VFX template player now preserves a requested BasePart world offset before creating an anchor weld. Existing anchored calls that already pass the anchor CFrame retain their previous placement.
- Server projectiles now use a swept segment test against their assigned target, with larger hit radii for Elite, MiniBoss and Boss ranks and an optional `SpellHitRadius` override. This prevents fast homing projectiles from stepping past large Golem/Ent visuals whose authoritative server proxy is intentionally small.
- Authored projectiles receive an ID and a server end event. The client destroys the matching visual on authoritative hit/range/run termination instead of letting it continue past a boss.
- Client homing resolves the matching pooled model in `workspace.NpcVisuals` by `NpcId`, so the visible projectile tracks the visible Golem/Ent rig rather than only the interpolated server proxy.
- Applied the same six combat-package source changes to the `Level/` and `Level2/` mirrors. No remote name, persistent-data shape, DataStore key or teleport payload changed.

### Validation

- All six changed active `Level` Studio template sources passed `loadstring` after synchronization: `SpellDefinitions`, `SpellTargeting`, `SpellProjectiles`, `SpellService`, `VfxTemplatePlayer` and `AuthoredSpellVFXClient`.
- A fresh `Level` Play installed 155 package roots, enabled 111 runtime scripts and reached `[SpellService] Ready` without a new product spell/VFX error. Later Output errors came only from two failed `AssistantCommand` test-harness attempts and were not emitted by the normal startup/gameplay path.
- Studio inspection confirmed `LightningVFX`, `GilgameshMain`, `GilProjectile` and `GilHitVFX` under the active shared `ReplicatedStorage.Assets.Animations` template.
- A controlled level-20 cast emitted `LightningVFX` and three six-portal Gates volleys. Portal reveal intervals within each volley were approximately 0.11–0.13 seconds; all sampled portal parts were unanchored, welded to `HumanoidRootPart` and retained a 5.0–6.9-stud authored offset.
- An isolated level-1 Gates cast produced exactly one portal, one projectile and one matching authoritative end event. The measured wind-up was 0.519 seconds, projectile origin matched the locked portal position and the rotated portal axis followed the shot direction while the target moved.
- The final active runtime contract probe returned Gates counts `1, 2, 3, 4, 6` for levels `1, 5, 10, 15, 20`, plus `LightningVFX` for Lightning. A fresh smoke after this finalization again reached `[SpellService] Ready` and the loading gate without a new product error.
- An isolated scheduler probe resolved the Boss hit radius to 8 studs and hit a target on a swept path offset by 6 studs, which the previous 3.3-stud point check would miss. Registered Golem and Ent proxies each received the expected 123 damage through the same radius/damage callbacks, and the active projectile count returned to zero.
- All six modified combat sources have exact SHA-256 parity between `Level/` and `Level2/`; final `git diff --check` passed with line-ending warnings only.

### Runtime loops, cost and cleanup

- No new `Heartbeat`, `Stepped` or `RenderStepped` connection was added. The existing central projectile `Heartbeat` performs one constant-time point-to-segment check for the assigned target before its existing nearby-enemy lookup.
- Gates uses at most six bounded reveal tasks and six bounded wind-up tasks per cast at the current level-20 cap. Every task checks current run/player state before work and retains no long-lived record.
- The existing single authored-VFX `RenderStepped` remains the owner of all visible projectile motion. A weak target cache avoids scanning `workspace.NpcVisuals` after the matching `NpcId` has been resolved; ended and range-expired projectiles remove both list and ID-map entries.
- The projectile scheduler still disconnects its central `Heartbeat` when its active list becomes empty. No per-projectile connection or new `_G` dependency was introduced.

### Not verified, risks and rollback

- The command-side Studio module context cannot insert an NPC into the already-running WaveController registry, so a natural Gates cast against the real scheduled Golem/Ent encounter was not completed. Timing, anchoring and projectile lifecycle were exercised through the active spell runtime; Golem/Ent damage was exercised through isolated registered proxies and the same authoritative projectile callbacks. Repeat the full scheduled encounter for final visual acceptance.
- `Level2` Studio was not connected. Its six files mirror `Level` exactly but still require package publication/Get Latest in Hollow Marsh.
- The -90-degree orientation follows the authored portal's positive-Y firing axis inferred from its current setup; verify its visual face during the next Studio acceptance pass if the asset is reauthored.
- Roll back by restoring the prior six `DungeonCombat` files in both `Level/` and `Level2/` and the matching active `Level` package-template sources. No saved data or authored VFX asset needs migration or restoration.
