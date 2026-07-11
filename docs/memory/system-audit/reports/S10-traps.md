# Traps — Audit

- Files: `src/levels/traps/` (base `trap.gd` + 23 subclasses); generation hooks in
  `src/levels/*_level.gd::_create_random_trap`; save/load in `level.gd:826-843`,
  `save_manager.gd:369-389`.
- Read in full: yes (all 24 trap `.gd` files; relevant Level/SaveManager slices).
- Verdict: **needs-hardening** — base lifecycle + serialize are faithful and clean, region
  trap-select scaffolding matches SPD, but two signature traps are inert (`pass` buffs), one
  fires an argument-swapped `drop_item` (item loss), and 7 implemented trap classes are never
  wired into any generation pool.

## Improvements
- [P1] `disarming_trap.gd:44-47` — calls `level.drop_item(weapon, drop_pos)` but the canonical
  signature is `drop_item(pos: int, item, heap_type)` (all 10 other callers pass `(pos, item)`).
  Weapon and cell are swapped → the heap is keyed by a weapon *object* as its `pos`; `pickup_item`
  compares `pos == cell(int)` so it never matches → **permanent weapon loss** whenever this trap
  fires. Fix = swap to `drop_item(drop_pos, weapon)`. (Behavioral → backlog, not auto-fixed.)
- [P1] `paralytic_trap.gd:14-15` — the paralysis effect is a literal `pass`; the `Paralysis`
  buff class exists (`src/actors/buffs/paralysis.gd`) but is never constructed. The trap only
  logs a message → wholly inert. (File is in `TRUNCATED_FILES.txt` → backlog only.)
- [P1] `fire_trap.gd:14-16` — the burning buff is a `pass`; only raw damage + ember spread run.
  Its stated "sets the triggering character on fire" effect is missing even though `Burning`
  exists and `blazing_trap.gd:15-18` applies it correctly. (Truncated file → backlog only.)
- [P2] `disarming_trap.gd:18-21` — weapon detection is dead on the hero: `Hero` has no
  `get_weapon()` and no `weapon` property (weapons live on `belongings.get_equipped_weapon()`),
  so the trap always hits the "You have nothing to disarm." branch.
- [P2] `cursing_trap.gd:17` — equipment-curse path is dead: `Hero` exposes no
  `get_equipped_items()`, so cursing always falls through to the `Hex` fallback.
- [P2] `pitfall_trap.gd:31-39` — does not drop the victim to the next depth; it proxies with a
  same-level `random_passable_cell()` teleport (acknowledged TODO). SPD `PitfallTrap` converts
  the tile to chasm and forces a depth descent with fall damage.

## Optimizations
- [P3] Neighbor loops across nearly every trap compute `adj = pos + dir` and bound only by
  `0 <= adj < LEN`. On left/right grid edges this **wraps to the adjacent row** (classic 1D-grid
  bug). Mitigated in practice by the wall border, but a `cell_valid`/adjacency guard (or reuse of
  `ConstantsData` helpers) would make edge behavior correct rather than incidental.
- [P3] `storm_trap.gd:34-39` re-fetches `mob_at(cell)` a second time for the water amplification
  when the value from line 27 is still in scope — redundant O(mobs) scan per water cell.
- [P3] `explosive_trap.gd:24-41` — a *mob* triggerer is hit twice (once via `mob_at(pos)`, once
  via the direct `triggerer` damage at full center damage). Fine for the hero, double-counts mobs.

## Additions
- [P2] Trap generation pools are incomplete vs SPD: 7 implemented trap classes are referenced by
  **no** `_create_random_trap` and can never spawn — `ParalyticTrap`, `FrostTrap`, `BlazingTrap`,
  `FlockTrap`, `CursingTrap`, `DisarmingTrap`, `PitfallTrap`. Wire them into the region tiers
  (SPD places e.g. Frost/Blazing/Disarming/Pitfall in caves/city trap pools) or delete the dead
  classes. Currently ~30% of trap content is unreachable.
- [P3] `grim_trap.gd:32-39` uses a bespoke "≤50% HP → deal `cur_hp+1` (lethal)" rule; SPD
  `GrimTrap` scales damage toward max HP without a hard 50% instakill cliff. Fidelity nit.
- [P3] `disarming_trap.gd:46` — `elif level.has_method("add_heap")` references a Level method
  that does not exist anywhere → permanently dead fallback branch.
- [P3] No unit coverage for trap activation/one-shot terrain flip/serialize round-trip; the
  `_do_effect` contract is a clean seam for a small test harness (framework-extraction hook).

## Save/load & coupling notes
- Serialize/deserialize is **solid**: `trap.serialize()` writes `_script_path`; `level.gd:834-843`
  reconstructs by script path and calls `deserialize()` (restores `pos/visible/active`). `one_shot`
  is a per-class `_init` constant (not persisted, correctly), and the INACTIVE_TRAP terrain flip is
  captured in the separately-serialized map. No trap save/load defects found.
- Coupling: traps duck-type against `Level` (`set_terrain`, `terrain_at`, `mob_at`, `is_passable`,
  `random_passable_cell`, `spawn_mob`, `drop_item`, `alert_all_mobs`) and autoloads
  (`MessageLog`, `MobFactory`, `TurnManager`, `EventBus`). Guarded with `has_method`, so a missing
  method degrades quietly — which is exactly why the disarming/cursing dead-paths went unnoticed.

## Research notes
- SPD `Trap.java`: activate → reveal → `activate()` effect → optional disarm/`inactivate`; region
  trap pools are defined per `Level.trapClasses()`/`trapChances()`. Confirms (a) the missing
  paralytic/burning applications and (b) the incomplete region pools here.
- Verified against repo: buff classes for Poison/Frozen/Burning/Rooted/Ooze/Hex/Weakness/Cripple/
  Vertigo/Blindness/Paralysis all exist under `src/actors/buffs/`; `drop_item` canonical arg order
  confirmed across 10 call sites; `add_heap`/`get_equipped_items`/`Hero.get_weapon` confirmed absent.

## Auto-fixes this run
- None. Every high-value item is behavioral (P1 arg-swap, inert buffs, pool wiring) and thus
  outside the mechanically-safe auto-fix envelope; the mechanical P3s (dead `add_heap` branch,
  storm redundant fetch) sit in files better fixed alongside their P1s. No safe auto-fix applied.
