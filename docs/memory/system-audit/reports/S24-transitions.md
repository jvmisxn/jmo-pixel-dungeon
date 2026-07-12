# Transitions (floor/run) — Audit

- Files: `src/mechanics/floor_transition_coordinator.gd`, `src/mechanics/run_transition_coordinator.gd`
- Read in full: yes
- Verdict: needs-hardening — the coordinators are clean and SPD-faithful in flow, but `handle_descend` re-implements GameManager's depth mutation *without* its `MAX_DEPTH` cap (descend past floor 26 possible), ascend plays the wrong SFX, and the floor-change notification only reaches the equipped artifact.

## Improvements
- [P1] `handle_descend` bypasses the depth cap — `floor_transition_coordinator.gd:23-25` inlines `_cache_current_level()` / `GameManager.depth += 1` / `_on_depth_changed()` instead of calling `GameManager.descend()`. `GameManager.descend()` (game_manager.gd:146-155) guards `if depth >= ConstantsData.MAX_DEPTH (26): return -1`; the coordinator has no such guard, so from the deepest floor it advances `depth` to 27+, generating a level below the intended bottom. Only the `hero.pos != exit_pos` stair check (which may pass on any level with a down-stair) stands between the player and out-of-range depth. — Call `GameManager.descend()` / `ascend()` and bail on the `-1` sentinel, or add the `MAX_DEPTH` / `depth <= 1` cap here.
- [P1] Depth-mutation logic is duplicated and already drifting — `handle_descend`/`handle_ascend` (`:23-25`, `:54-56`) hand-copy the exact `_cache_current_level → depth ± 1 → _on_depth_changed` sequence that `GameManager.descend()`/`ascend()` (game_manager.gd:146-166) already encapsulate, minus their bounds checks. This is the root cause of the cap bug above and any future divergence. — Delegate to the GameManager API; keep messaging/audio/networking in the coordinator.
- [P2] `handle_ascend` plays the descend SFX — `floor_transition_coordinator.gd:52` calls `AudioManager.play_sfx("descend")` on an ascend. No `"ascend"` cue is registered anywhere (grep: only `"descend"` exists), so this is a missing asset, not a typo — going up sounds like going down. — Register/route an ascend cue, then fix the literal.
- [P3] Latent null-deref on `_current_level` — `handle_descend:15` / `handle_ascend:41` dereference `scene._current_level.exit_pos` / `.entrance` unconditionally, but the immediately-preceding guard (`:10`, `:36`) short-circuits to false when `_current_level` is null, letting a null level fall through to the deref. Harmless in the normal flow (level is set before input) but a crash if reached mid-teardown. — Add an explicit null check.

## Optimizations
- [P3] `party_ready_for_stairs` / `notify_party_floor_change` take a `scene` param they only null-check (`:61-77`, `:79-89`) — the body reads from `GameManager` exclusively. Minor dead-coupling; harmless but signals the coordinator boundary isn't crisp. Leave until the API is consolidated (call sites pass `self`).

## Additions
- [P2] Floor-change hook only reaches the equipped artifact — `notify_party_floor_change:85-89` calls `on_floor_change()` on `belongings.get_equipped_artifact()` only (the sole implementor is `artifact.gd:742`). SPD's `Item.onLevelChange()` fires on *all* belongings and buffs on descent (e.g. Chalice/Horn regen, timed-buff bookkeeping). — Introduce a generic `on_floor_change()` contract on Item/Buff and iterate belongings + active buffs, so non-artifact floor-change effects can exist.
- [P2] No surface exit at depth 1 — `handle_ascend:44-48` hard-blocks ascent from floor 1 ("The way to the surface is sealed"), yet a `surface_scene.gd` exists. SPD's up-stairs on floor 1 return the hero to the surface village (leave-run). — Route depth-1 ascent to the surface scene instead of blocking.
- [P2] No transition tests — floor/run transitions have zero coverage despite touching depth, caching, networking, and scene swaps. — Add unit tests for the cap/seal guards, party-gate, and cause-of-death parsing (`run_transition_coordinator.gd:80-88`) using a stub scene/GameManager.

## Save/load & coupling notes
- Persistence: transitions cache the departing level via `GameManager._cache_current_level()` (serialize into `_level_cache[depth]`, then free mob Nodes) before the loading scene regenerates/reloads. No scheduling state travels (see S04). Coordinators mutate `GameManager.depth` directly — the single biggest coupling smell.
- Autoload deps: `GameManager`, `MessageLog`, `AudioManager`, `SceneManager`, `TurnManager`, `NetworkManager` + `OnlineEventCodec`/`OnlineSnapshotUtils` for host/client broadcast. All null-guarded, so headless/test use degrades gracefully.
- Online: host broadcasts `broadcast_level_transition` / `broadcast_run_end`; client path (`handle_online_run_ended`) is receive-only. No readiness barrier before a host descends — clients follow on the next broadcast.

## Research notes
- SPD parity: dungeon bottom is depth 26 (Amulet floor); `MAX_DEPTH = 26` in `constants.gd:11` matches. SPD `InterlevelScene` (DESCEND/ASCEND/RETURN) gates on `Dungeon.depth` bounds and returns to the surface from floor 1 — both absent here.
- SPD `onLevelChange`: called broadly across belongings/buffs, not just the equipped artifact.
- Coordinators were extracted from `game_scene.gd` (dispatch stubs at `game_scene.gd:2330-2348`); unlike S23's leftover dead input code, no drifted duplicate remains in the scene for these two.
