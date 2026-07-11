# Level base & grid (S07) — Audit

- Files: `src/levels/level.gd` (1033 lines), `src/levels/regular_level.gd` (536 lines)
- Read in full: yes
- Verdict: **needs-hardening** — grid/FOV/AStar core is faithful and clean, but mob population
  is thin (under-spawns + no respawn), a few hot-path lookups are O(n)/full-FOV, and `rooms`
  are not persisted. Both files are in `TRUNCATED_FILES.txt`, so nothing was auto-fixed.

## Improvements
- [P1] `mob_spawn_positions` under-spawns mobs — `regular_level.gd:411` decrements `remaining`
  every iteration even when placement failed (`placed=false`; the `pass` at :410 does nothing),
  so a floor can end up with fewer mobs than `mob_count()` intends → less XP, easier floors.
  Also the documented "25% chance to spawn a second mob in the same room" (:359) is never
  implemented, and the empty-`std_rooms` fallback (`regular_level.gd:378-382`) `return [pos]`
  yields **one** position regardless of `count`. — Loop on successful placements, not a fixed
  counter; implement the second-mob roll; make the fallback fill `count`.
- [P1] No periodic mob respawn — SPD `RegularLevel` runs a `respawner`/`spawnMobs` actor that
  slowly refills killed mobs (rooms-weighted, entrance-avoiding). Here mobs spawn only once in
  `_build`; killed mobs are never replaced, so floors deplete and long stays diverge from SPD
  balance. — Add a respawn timer (reuse `mob_spawn_positions` + `rooms`).
- [P2] Mimic spawn discards its item — `regular_level.gd:115-122`: on `heap_roll==5` a mimic is
  created but the rolled `item` is thrown away instead of held by the mimic, and the mimic isn't
  depth-scaled. Result: an item is silently lost and the mimic drops nothing, unlike SPD where
  the mimic carries the generated item. — Pass `item` into the mimic; call `scale_to_depth`.
- [P2] `rooms` not serialized — `level.serialize()/deserialize()` (level.gd:717,777) never
  persist `rooms`, so `level.rooms` is empty after load. Currently low-impact (only the painter,
  a generation-time consumer, reads it), but it blocks respawn and any room-based post-load
  feature, and diverges from SPD which persists room bounds/types. — Serialize room class +
  bounds + connections.
- [P3] `unlock_exit` (level.gd:624-631) brute-forces **every** `LOCKED_DOOR` on the level rather
  than the door gating the exit. Works for single-door boss levels but is coupling-fragile.
- [P3] DARK feeling is visual-only — `feeling==DARK` drives fog dimming in `game_scene.gd:439`
  but never reduces effective view distance in `update_fov`/`get_view_distance`. Low-confidence
  fidelity note; SPD darkens the light radius. Verify before acting.

## Optimizations
- [P2] `is_visible_from`/`has_los` (level.gd:591-609) allocate a full LEN-size `Array[bool]` via
  `ShadowCaster.cast_fov` for a single point-to-point LOS query — 5 call sites incl. the mob
  targeting hot path. `Ballistica` (src/mechanics/ballistica.gd, the SPD-correct O(distance) ray)
  already exists. — Route point LOS through Ballistica; reserve full FOV for the hero sweep.
- [P2] O(n) linear scans on hot paths — `mob_at`, `find_char_at`, `heaps_at`, `pickup_item`
  (level.gd:478-516) iterate every mob/heap on each call (pathfinding, movement, targeting).
  — Maintain a `pos -> mob` (and `pos -> heap`) index, invalidated on move/spawn/remove.
- [P3] `update_fov` runs 3–4 separate full-grid (LEN) passes per hero move
  (`_reveal_adjacent_walls`, the visited loop :359, `_update_wall_visited`, the heap loop :366).
  Fine at 32×32 but fusable into one or two passes if FOV ever shows up in profiling.

## Additions
- [P2] Extract a shared respawn/spawn service (pairs with the P1 respawn gap) reusable by region
  subclasses — framework-extraction hook.
- [P3] `static var _recent_specials` (regular_level.gd:505) is process-global, not per-run and
  not reset on a new game, so special-room-variety tracking bleeds across games in one session.
  — Move to per-dungeon state (and persist it) to match SPD's per-run rotation.
- [P3] Grid constants are duplicated: `level.gd:10-12` hardcodes `W=32/H=32/LEN` while
  `regular_level.gd` uses `ConstantsData.WIDTH/LENGTH`. Equal today (both 32/1024) but a latent
  divergence hazard. — Derive `W/H/LEN` from `ConstantsData`.
- [P3] Several `pos / W` integer divisions lack `@warning_ignore("integer_division")`
  (level.gd:298-299, 381-382, 405-406) → gdlint/parse warnings. Cosmetic.
- [P3] Tests: entrance→exit reachability (already asserted in `_build`), FOV symmetry, and
  serialize→deserialize round-trip for heaps/traps/plants/bombs would lock in the save contract.

## Save/load & coupling notes
- Serialized: depth, entrance, exit_pos, feeling, map/visited/mapped, heaps (item via
  `serialize`/`Generator.create_item`), mobs (via MobFactory + `resolve_post_load`), traps,
  plants, blobs, pending_bombs. Rederived on load via `build_flag_maps()`: passable, los_blocking,
  discoverable, AStar2D graph, visible. **Not** persisted: `rooms` (see P2), the region-subclass
  room-count config (generation-time, acceptable).
- Autoload coupling: GameManager (heroes/current_level/record_stat), TurnManager (add_actor),
  MobFactory, Generator, EventBus, MessageLog, ConstantsData, ShadowCaster, Pathfinder — heavy
  but expected for the level hub.

## Research notes
- SPD `RegularLevel.java`: `nMobs()`/`createMobs()` seed initial mobs, and a separate
  `respawner()` actor refills over time — the port implements the former, not the latter (P1).
- SPD mimic (`Mimic.spawnAt(pos, item)`) is constructed **with** the heap item; the port drops
  the item on the floor mentally but discards the object (P2).
- Verified in-repo: `sheep.spawn_at` correctly registers with `add_mob` + `TurnManager`
  (level.gd:535-538 is fine); Blindness is honored — `hero.get_view_distance()` returns 0 when
  blinded, driving the sense-only branch in `update_fov` (the level.gd comment at :240 is stale
  but behavior is correct); `ConstantsData.WIDTH==32==W`, `LENGTH==1024==LEN` (consistent today).
