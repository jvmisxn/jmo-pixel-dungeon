# Mobs & AI — Audit

- Files: `src/actors/mobs/mob.gd` (base AI/aggro/loot/XP), `src/actors/mobs/mob_factory.gd` (spawn tables + instancing), and 44 subclasses across `bosses/ caves/ city/ halls/ prison/ sewer/ special/`. Deep-read: `mob.gd`, `mob_factory.gd` in full; representative subclasses `rat`, `spinner`, `thief`, `necromancer`, `swarm`, `goo` in full; remaining subclasses surveyed.
- Read in full: yes (base + factory + 6 subclasses); others surveyed by pattern.
- Verdict: **needs-hardening** — AI state machine is faithful and clean, save/load object graph and post-load relinking (necromancer↔skeleton via `resolve_post_load`) work, but there is one real balance/fidelity bug (Swarm split duplicates HP), several inert/dead fields, and thin detection/targeting relative to SPD.

## Improvements
- [P1] **Swarm split duplicates HP instead of halving it** — `sewer/swarm.gd:43-45`. `_split()` sets `child.hp = hp` / `child.ht = hp` (a full copy of the parent's current HP) while the parent's HP is left unchanged. In original `Swarm.java` the current HP is *divided* between the two flies (each gets ~half). Result here: total swarm HP roughly doubles on every split, and because each fly grants full `xp_value` on death, killing a split swarm also over-grants XP. Direction: split the parent's remaining HP — `child.hp = hp / 2; hp -= child.hp` (guard `hp >= 2`), keep `child.ht/hp_max` in sync with the child's HP.
- [P2] **`_find_visible_heroes()` returns unsorted; callers always take `heroes[0]`** — `mob.gd:250-266`, used at `:139/:154/:461` and in subclass `_find_hero_target()`. On a multi-hero level (the code advertises "multiplayer-ready") the "target" is whichever hero happens to be first in the array, not the nearest/most-threatening. `_find_nearest_char()` (`:268`) already does distance selection; wake/notice paths should route through it rather than `heroes[0]`.
- [P2] **Spinner reimplements `_act_hunting` and drops shared AI guards** — `caves/spinner.gd:_act_hunting`. Its override never consults `should_flee()`, `Amok`, or `Terror/Dread` handling that the base `_act_hunting` (`mob.gd:170`) provides, so an amok/terrified spinner still hunts normally. Direction: fold web logic into a pre-check and delegate the movement/attack tail to `super._act_hunting()`.
- [P2] **`create_boss` fallback returns a bare `Mob.new()`** — `mob_factory.gd:170`. An unexpected boss depth yields a statless, nameless `Mob` (hp 0 via `setup` never called) rather than failing loudly. Return `null` and let the caller handle it, matching `create_mob`'s `push_warning` + `null` contract (`:137-138`).

## Optimizations
- [P3] **Dead field `_path`** — `mob.gd:38-39`. Declared (with `@warning_ignore`) but never read or written anywhere in the repo (verified by repo-wide grep). Pure clutter. *(auto-fixed this run — see below.)*
- [P3] **`first_summon` is inert** — `prison/necromancer.gd:16,127,162,171`. Tracked, serialized, and set to `false`, but never *read* to change behavior; the docstring promises "first summon is faster (1 turn instead of 2)" but summon timing is a flat single `spend_turn()`. Either wire it into summon timing (behavioral — backlog) or drop the field.
- [P3] **`did_visible_action` bookkeeping duplicated per subclass** — many overrides manually set `did_visible_action = true` / `last_visible_action`. Could be centralized via the `on_move`/`on_attack_hit` hooks that already exist on the base (`mob.gd:391,406`).

## Additions
- [P2] **Halls spawn table ignores depth** — `mob_factory.gd:79` `_halls_table(_depth)` returns a flat set with no depth gating, unlike every other region. Low-priority parity item but worth a depth ramp for the deepest floors.
- [P3] **Goo's `damage_roll()` mutates state (`pumped_up = 0`) as a side effect** — `bosses/goo.gd:damage_roll()`. A method named like a pure getter clears the pump flag; the ranged-attack branch then redundantly re-zeroes it. Extract pump consumption to the attack path so `damage_roll()` is side-effect-free (aids testability).
- [P3] **No unit tests for the AI state machine or `MobFactory` weighting** — `create_random_mob` weighted selection (`mob_factory.gd:141`) and sleeping/wandering detection rolls are pure functions ripe for deterministic tests (seeded RNG).

## Save/load & coupling notes
- Serialization stores `_class` = script `resource_path`; `Level.deserialize` reinstantiates from that path and then calls `resolve_post_load` on each mob (`src/levels/level.gd:820-825`), so Necromancer's skeleton relink via saved `actor_id` works. Swarm/Spinner/Thief/Goo persist their extra state correctly.
- `target` is intentionally dropped on load (`mob.gd:529`), leaving `state=HUNTING` + `target_pos`; `_act_hunting`'s null-target branch walks to `target_pos` then reverts to WANDERING — acceptable "lost the target" behavior.
- Autoload coupling: `TurnManager`, `GameManager`, `EventBus`, `MessageLog`, `Generator`, `ConstantsData`. All guarded with truthiness/`has_method` checks — safe but verbose.
- `scale_to_depth` is applied by `Level` (`:545,558`) and summoning trap; only Swarm/Bee/Wraith define it, matching SPD (most mobs don't scale).

## Research notes
- Compared against Shattered PD `Mob.java` (Sleeping/Wandering `detectionChance = 1/(dist(/2)+stealth)` — the port matches at `mob.gd:142,157`) and `Swarm.java` (HP is split, not duplicated — the divergence flagged P1 above).
- Necromancer behavior (single linked skeleton, HT/5 heal, Adrenaline buff, skeleton dies with necromancer) faithfully mirrors `Necromancer.java`.
