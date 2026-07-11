# Blobs (gases/liquids) — Audit

- Files: `src/actors/blobs/` — `blob.gd` (base), `fire_blob.gd`, `toxic_gas.gd`,
  `confusion_gas.gd`, `paralytic_gas.gd`, `web_blob.gd`, `water_of_health.gd`.
  Cross-refs read: `src/levels/level.gd` (blobs array, add_blob, serialize/deserialize,
  smoke LOS), `src/autoloads/save_manager.gd` (blob (de)serialize, store_var),
  `src/autoloads/turn_manager.gd` (actor scheduling), `src/items/bombs/bomb.gd`,
  `src/actors/mobs/sewer/fetid_rat.gd`, `src/actors/mobs/caves/spinner.gd`,
  `src/items/potions/potion.gd`.
- Read in full: yes (all blob files; relevant sections of the cross-refs).
- Verdict: **fragile** — the base sim is faithful to SPD in shape but is *never driven*:
  `Blob.act()` is never called, so no gas spreads, applies effects, or decays. Blobs are
  inert visual overlays. Plus a crashing seeder and dead persistence contract.

## Improvements
- [P1] **The whole blob simulation is dead — `Blob.act()` is never called.** `act()`
  runs `_spread()` → `_apply_effects()` → `_decay()` (blob.gd:32-45), but nothing ticks it.
  TurnManager only registers mobs (`level.gd:548,562`); blobs live in `level.blobs`
  (`Array[Dictionary]{blob,pos}`) and are used only for rendering
  (`scene_visual_coordinator.gd:140`) and smoke LOS (`level.gd:257`). There is no
  `level.tick_blobs()` and no `_process`/per-turn hook. Result: every gas seeded by a
  bomb, fetid rat, or spinner sits as a frozen overlay at its seed cell forever — never
  poisons/paralyzes/burns/roots anyone, never spreads, never disappears. This is *why*
  S15/S19 found potions/plants applying one-shot 3×3 buffs instead of blobs: the blob
  layer was never functional. Direction: register blobs as turn actors, or add a
  `level.tick_blobs()` invoked each hero round (mirror `tick_pending_bombs`, level.gd:946),
  guarding hero-in-gas effects.
- [P1] **`fetid_rat.gd` toxic-gas drop crashes on arg-count mismatch** (fetid_rat.gd:26-28).
  `blob.seed(death_level, death_pos, 6)` calls `Blob.seed(cell, amount)` with **3** args
  (and passes the level object as `cell`); `death_level.add_blob(blob)` calls
  `add_blob(blob, cell)` with **1** arg. Both are runtime argument-count errors → fetid rat
  death throws and no toxic gas ever spawns. Fix: `blob.seed(death_pos, 6)` and
  `add_blob(blob, death_pos)`.
- [P2] **Blob persistence bypasses its own contract; relies on `store_var(full_objects)`.**
  `Blob.serialize()` (blob.gd:100) and the blob factory `_create_entity_by_type("blob")`
  (save_manager.gd:496-499) both exist but are **never called**. `level.serialize`
  (level.gd:759-762) and `save_manager._serialize_blobs` (save_manager.gd:434) just
  `.duplicate(true)` the `{blob:<live Node>,pos}` dict — the object is copied by reference,
  and `_deserialize_blobs` re-appends the raw dict without reconstruction (save_manager.gd:443).
  It only round-trips at all because the save uses `store_var(data, true)` (full_objects) on a
  `Node`-derived Blob — fragile and no `Blob.deserialize` exists. Direction: serialize via
  `blob.serialize()` and rebuild through the factory + a real `Blob.deserialize`.
- [P2] **`add_blob` clobbers caller-provided density** (level.gd:923-929). It unconditionally
  `blob.seed(cell, 1)` after the caller may have seeded a stronger cloud, forcing a floor of
  1.0 regardless of intent (seed uses `maxf`, so an intended 6 survives but a weaker intent is
  overridden). Density should come from the caller, not be hard-coded.

## Optimizations
- [P2] **`_spread` mutates `active_cells` while iterating it** (blob.gd:51-62): the loop
  appends freshly-touched neighbors into the same array it's iterating, so newly-added cells
  can be visited in the same pass (single-turn cascade) and the subsequent
  `_apply_effects`/`_decay` operate on a set that just changed under them. Build the new active
  set separately (e.g. a `Dictionary`/`PackedInt32Array`) and swap at the end.
- [P2] **FOV scans every blob twice per update for smoke** (level.gd:257,273) even when zero
  smoke blobs exist. Cheap to short-circuit with a cached `has_smoke` flag maintained on
  add/remove.

## Additions
- [P1] **Blob layer is under-wired vs SPD** — only FireBlob (bomb), ToxicGas (fetid rat,
  broken), and WebBlob (spinner) are ever seeded. `ConfusionGas`, `ParalyticGas`, and
  `WaterOfHealth` have **zero seeders anywhere** (grep-confirmed) — fully dead classes.
  Potions never call `add_blob` (potion.gd). Missing SPD blobs entirely: Freezing, CausticGas,
  StenchGas, StormCloud, Regrowth, SmokeScreen. Once ticking works, wire gas potions/plants/
  traps to seed the correct blob rather than one-shot buffs.
- [P2] **`smoke_screen` blob referenced but the class does not exist.** level.gd LOS code
  branches on `blob_id == "smoke_screen"` (level.gd:259,275) but there is no SmokeScreen blob
  file — the LOS-blocking smoke path is unreachable dead code until a SmokeScreen blob is added.
- [P3] **No blob unit tests.** The spread/decay/active-cell lifecycle is pure and grid-based —
  ideal for headless tests once `act()` is actually driven.

## Save/load & coupling notes
- Persistence: `store_var(full_objects=true)` currently carries blobs incidentally by
  deep-copying live `Node` objects; the intended `serialize()`/factory/`deserialize` contract is
  dead. Fragile across script/structure changes.
- Coupling: Blob → Actor(Node) but is never added to the tree nor registered with TurnManager;
  it depends on `level.is_passable/find_char_at/get_terrain/set_terrain` (all `has_method`-guarded,
  safe) and on buff classes (Burning/Poison/Paralysis/Amok/Blindness/Rooted). Downstream, S15/S19
  workarounds exist *because* this layer is inert — fixing the tick unblocks proper gas/flame/
  frost behavior there.

## Research notes
- SPD reference: `Blob` in Shattered Pixel Dungeon is an `Actor` that is `add()`-ed to the level
  and processed via `Actor.process()` each turn (`evolve()` spreads volume across the 4-neighbor
  `cur`/`off` arrays, then swaps). The port mirrors the double-buffer idea (`new_density`) but
  omits the scheduling half — hence the dead sim. SPD gases (ToxicGas, ParalyticGas, ConfusionGas,
  Fire, Web, Freezing, CausticGas, StormCloud, Regrowth, SmokeScreen) are seeded by shattered
  potions, plants, traps, and mob deaths — matching the "under-wired" gap above.
- No auto-fixes this run: the tick wiring and fetid_rat fix are behavioral; the dead
  serialize()/smoke branch live in `level.gd` (in TRUNCATED_FILES) or are intended-future content
  that SPD parity says to wire, not delete. All findings routed to backlog.
