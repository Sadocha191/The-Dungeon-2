# Changelog AI — 2026-08 — Boss, knockback, and Bat combat fix

## 2026-08-01

### Changes

- Grounded externally positioned ground NPCs through their authored/computed root ground offset before invalidating navigation. This fixes the boss dash/charge placing the root almost directly on the terrain surface and sinking the model underground.
- Set Boss and MiniBoss impulse resistance to zero in the canonical NPC lifecycle path. Both ordinary knockback and pull-style displacement now leave their stored impulse at zero while damage, hit feedback, slows, freezes, and self-authored ability movement remain intact.
- Added `DiveAttackBehavior` to the existing central NPC combat behavior scheduler.
- Configured `Bat` to use the new behavior: cooldown/hover, windup, locked predictive dive, one server-authoritative strike, obstacle abort, recovery climb, and cooldown.
- Added combat behavior resolver aliases and metrics for the dive behavior.

### Runtime cost and cleanup

- No per-Bat `Heartbeat`, `RenderStepped`, or permanent task loop was added. Bat behavior runs inside the existing central `NpcService` movement scheduler.
- Dive raycasts are bounded to active windup/dive/recovery work and ignore NPC/player presentation geometry.
- Behavior state is stored on the NPC record and cleared through the existing combat behavior cleanup path on death/despawn.

### Validation

- Reviewed the final branch diff against `main`; only the intended NPC modules, two new behavior/grounding modules, and this changelog are changed.
- Confirmed `MobConfig` differs from `main` only by `combatBehavior = "DiveAttack"` for `Bat`.
- Confirmed Boss/MiniBoss damage handling is unchanged; only impulse accumulation is rejected.
- Roblox Studio playtesting was not available from this GitHub-only session. The PR includes a focused Studio test checklist for boss charge grounding, projectile/pull immunity, and Bat state transitions.

### Risks

- External boss grounding relies on a nearby downward world raycast at the destination X/Z. A Studio test is required around overhangs, bridges, steep slopes, and map edges.
- Bat dive timings and hit radius are initial gameplay values and may need balancing after observing the authored Bat rig and animation scale.

### Rollback

- Remove `DiveAttackBehavior.lua` and `NpcExternalPositioning.lua`, unregister `DiveAttack`, remove the Bat `combatBehavior`, restore the previous movement-controller invalidation path, and restore the previous Boss/MiniBoss impulse resistance values.
