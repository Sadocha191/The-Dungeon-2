# Reactive grass removal and client diagnostics optimization

## Scope

Remove the live `ReactiveGrassClient` runtime from the `Poziom` place and keep the existing grass assets completely static. The MicroProfiler capture from the published game showed that the client performed a full reactive-grass scan roughly every 0.2 seconds. Those scan frames cost about 20–25 ms and caused visible frame-pacing stutters despite normal frames frequently reaching 60 FPS or more.

This change also reduces overhead from the optional F3 performance HUD:

- the diagnostics HUD performs no frame sampling while its `ScreenGui` is disabled;
- the detailed labels refresh once per second instead of four times per second;
- label text is written only when the displayed value changed;
- the frame-sample window is bounded to 600 samples;
- the duplicate FPS `RenderStepped` loop in `FPSCounterClient` is removed;
- `PerfHudClient.Update` is exposed as a MicroProfiler label.

## Required live Studio deletion

`ReactiveGrassClient` exists in the live `Poziom` place but has no tracked source file on the current `main` branch. Applying this change therefore requires deleting the live Studio object directly:

`game.StarterPlayer.StarterPlayerScripts.ReactiveGrassClient`

Do not replace it with another runtime updater or cleanup loop. Do not delete the grass models, bones, meshes, folders, textures, or map decoration. Only the reactive client script is removed, leaving the grass static.

Before publishing, search the entire `Poziom` DataModel for additional instances named `ReactiveGrassClient` and remove every active copy. Confirm that no client script still writes grass bone `Transform` values or calls `WorldToViewportPoint` for the removed system.

## Repository files

Modified:

- `Level/StarterGUI/FPSCounter/PerfHudClient.lua`
- `Level/StarterGUI/FPSCounter/FPSCounterClient.lua`

Added:

- `docs/changelog/CHANGELOG_AI_2026-07_REACTIVE_GRASS_REMOVAL.md`

No server gameplay, NPC simulation, drops, rewards, remotes, persistent data, movement, map assets, or Four Peaks files are changed.

## Required validation

1. Confirm the active Studio instance is `Poziom`; do not modify `Cztery szczyty`.
2. Delete `game.StarterPlayer.StarterPlayerScripts.ReactiveGrassClient`.
3. Start a Play test and verify that grass remains visible but no longer reacts to the player.
4. Verify there are no `ReactiveGrassClient` errors or warnings and no attempted `RenderFidelity` writes.
5. Verify F3 still opens and closes the performance HUD.
6. Verify FPS, frametime, low-FPS values, NPC count, peak NPC count, and memory update while the HUD is visible.
7. Capture at least 10 seconds in MicroProfiler in the same live-test area used before removal.
8. Confirm that `Script_ReactiveGrassClient` and its periodic 20–25 ms spikes are absent.
9. Confirm that the hidden F3 HUD produces no recurring `PerfHudClient.Update` markers and that visible updates occur about once per second.

## Rollback

Restore the previous live `ReactiveGrassClient` object and revert the two FPS counter files. Restoring the script also restores the known periodic reactive-grass scan and its frame-pacing cost.
