# Input & Targeting — Audit

- Files: `src/mechanics/input_coordinator.gd` (176 L), `src/mechanics/targeting_coordinator.gd` (63 L). Context: `src/scenes/game_scene.gd` (wrappers + targeting state), `src/actors/hero/hero.gd` (`get_auto_ranged_action`), `src/actors/char.gd` (`distance_to`), `src/autoloads/event_bus.gd` (`enter_targeting` signal).
- Read in full: yes (both coordinators). game_scene.gd read only around the input wrappers (truncated file, read-only).
- Verdict: **needs-hardening** — the two coordinators themselves are clean, faithful, and correctly extracted (range = Chebyshev + FOV gate, matching SPD `Level.distance` + `heroFOV`). But the extraction left ~185 lines of **dead, already-drifted duplicate input code** in `game_scene.gd`, and targeting mode does not block non-ESC keyboard input.

## Improvements
- [P1] **~185 lines of dead, unreachable, already-drifted input code in `game_scene.gd`.** All four scene wrappers delegate then `return`, leaving the pre-extraction body live-looking but unreachable: `_handle_cell_click` (game_scene.gd:1162 `return`, dead 1165–1218), `_handle_key_input` (:1221, dead 1223–1309), `_move_direction` (:1312, dead ~1315–1336), `_attack_adjacent_enemy` (:1339, dead ~1342–1359). **Proven drift:** the coordinator merged `KEY_SPACE`/`KEY_PERIOD` into one `match` case (input_coordinator.gd:106) while the dead copy still splits them (game_scene.gd:1279–1284) — the copies have already diverged, so any future edit to the dead body is silently ignored. Direction: delete the dead bodies (mechanically safe deletion), but `game_scene.gd` is in `TRUNCATED_FILES.txt` → backlog for a careful hand-edit, no auto-fix.
- [P1] **Targeting mode does not block non-ESC keyboard input** (input_coordinator.gd:53–56). When `_targeting_active`, `handle_key_input` intercepts only `KEY_ESCAPE`; every other key falls through to the normal `match`. Pressing a movement key during wand/throw targeting calls `move_direction` → submits a real `move` hero action **while targeting stays armed**; `KEY_I`/quickslots also fire mid-target. SPD's `CellSelector` swallows the turn until a cell (or cancel) is chosen. Direction: while `_targeting_active`, handle only ESC (cancel) and consume/ignore the rest.
- [P2] **`resolve` fires the callback without validating cell bounds** (targeting_coordinator.gd:40, 61). The FOV check is guarded by `cell >= 0 and cell < visible.size()`, so an out-of-range `cell` skips the visibility gate and still reaches `callback.call(cell)` → potential downstream crash/no-op. Add a `ConstantsData.is_valid_pos(cell)` guard before resolving.

## Optimizations
- [P2] Deleting the dead `game_scene.gd` input bodies (P1 above) shrinks a 2458-line hot autoload-adjacent file by ~7% and removes a class of "edited the wrong copy" bugs. Pure win once done safely.
- [P3] `resolve` recomputes the acting hero twice: `_get_input_hero()` at line 30 (`hero`) and again at line 57 (`acting_hero`) for the same frame. Reuse the first.

## Additions
- [P2] **No auto-aim / last-target memory** (SPD `QuickSlotButton` auto-targets nearest enemy and remembers the last target; re-tapping the quickslot fires at it — see SPD issues #1727/#291). Our targeting requires an explicit cell click every activation with no pre-aim and no default. High QoL/parity value; would live as an `autoAim(item, range)` helper feeding `enter()`.
- [P2] **No tests** for the input dispatch table or the targeting range+FOV gate — both are pure, side-effect-light static logic (mockable `scene`), ideal for regression coverage of the SPACE/PERIOD-style drift that already happened.
- [P3] **Attack-animation item detection is a fragile heuristic** (targeting_coordinator.gd:51–56): plays the cast animation only for `item_id == "spirit_bow"` or `has_method(proc/explode/zap)`; thrown potions/other items (which expose `shatter`) get no animation. Prefer an explicit `wants_cast_animation()` contract on items.
- [P3] `attack_adjacent_enemy` picks the **first** `DIRS_8` enemy and skips any char exposing `interact` (input_coordinator.gd:166–174); no priority (lowest-HP / last-target) and charmed/allied mobs are still attacked since they lack `interact`.

## Save/load & coupling notes
- No persistence surface — both coordinators are stateless `static func`s on `RefCounted`; all targeting state (`_targeting_active/_item/_max_range/_callback`) lives on the scene (transient, not serialized). Targeting does not survive save/load, which matches SPD (targeting is a UI mode, not run state).
- **Tight scene coupling:** the coordinators reach into ~10 private scene fields (`_targeting_active`, `_targeting_callback`, `_current_level`, `_hero_sprites`, `_hud`, `_awaiting_hero_input`, …) and private methods (`_submit_hero_action`, `_start_auto_walk`, `_cancel_auto_walk`, `_get_input_hero`). Fine as scene helpers; a framework extraction would need a small `InputContext` interface. Autoload deps: `GameManager`, `MessageLog`, `ConstantsData`, `EventBus` (all guarded with `has_method`/truthiness).

## Research notes
- SPD range gate: wands/thrown use `Dungeon.level.distance` (Chebyshev) + `heroFOV[cell]` — our `distance_to` (char.gd:585, documented as matching `Level.distance`) + `visible[cell]` check is faithful.
- Auto-aim/last-target: SPD `QuickSlotButton`/`CellSelector` (GitHub issues #1727 "auto-target last targeted ward", #291 "spirit bow quickslot auto-aim", #1703 "auto-target detected enemies"). Our port has none of this.
- Sources: [SPD #1727](https://github.com/00-Evan/shattered-pixel-dungeon/issues/1727), [SPD #291](https://github.com/00-Evan/shattered-pixel-dungeon/issues/291), [SPD #1703](https://github.com/00-Evan/shattered-pixel-dungeon/issues/1703).
