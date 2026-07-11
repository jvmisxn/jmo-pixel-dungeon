# Turn scheduling — Audit

- Files: `src/autoloads/turn_manager.gd` (353 lines, read in full)
- Callers traced: `src/actors/actor.gd` (activate/spend_turn), `mobs/*` +
  `npcs/*` (add_actor/refresh_speed), `hero/hero.gd` (hero_action_complete/
  refresh_speed), `scenes/game_scene.gd` (process_until_hero, the turn loop),
  `scenes/loading_scene.gd` + `save_manager.gd` (clear_actors).
- Read in full: yes
- Verdict: **needs-hardening** — cooldown rebasing and the hero-pause loop are
  correct and re-entrant-safe, but scheduling state isn't persisted across
  save/load, cached `speed` can silently go stale, and a whole "async mob
  pacing" layer is dead code (`MOB_ACTION_DELAY` is const `0.0`).

## Improvements
- [P2] **No serialization of scheduling state.** On save `clear_actors()` wipes
  `_actors`, `_turn_count`, `_round_count`, `_round_hero_ids_pending`
  (`save_manager.gd:86`), and on load every actor re-registers at
  `initial_cooldown` `0.0` via `Actor.activate()` (`actor.gd:36-42`,
  `turn_manager.gd:107-119`). All relative cooldown offsets are lost, so a
  slowed / hasted / just-acted mob resumes as if freshly scheduled. SPD
  persists each actor's `time`. — Serialize a `{actor_id: cooldown}` map and
  restore it before `process_until_hero()`.
- [P2] **Cached `speed` goes stale silently.** `spend_energy`/`set_cooldown`
  math divides by `entry["speed"]`, cached once at register time
  (`turn_manager.gd:112-118, 148-156`) and only updated by explicit
  `refresh_speed()` calls. Mobs and hero call it on some buff changes
  (`mob.gd:101`, `hero.gd:242`) but any speed-changing buff that forgets the
  paired `refresh_speed()` uses wrong timing with no error. — Have
  `spend_energy` re-query `actor_node.get_speed()` live (SPD recomputes speed
  every action), or assert the refresh contract.
- [P3] **Docstring wrong about buffs.** Header says "hero, mobs, buffs register
  as an actor" (`turn_manager.gd:6`), but `Buff extends Node` and never
  registers; buffs are ticked out-of-band in `game_scene`. Misleading for
  anyone extending the scheduler. (Truncated file → backlog only, no auto-edit.)

## Optimizations
- [P2] **The async mob-pacing layer is dead code.** `MOB_ACTION_DELAY` is
  `const 0.0`, so the only `await` (`turn_manager.gd:321-322`) is unreachable;
  `_process_mobs_async()` runs fully synchronously and `processing_mobs` flips
  `true`→`false` within the same call, so the `game_scene` gate it feeds never
  actually blocks. The coroutine, `_get_game_scene_cached()`, and the delay
  const exist for a disabled feature. — Decide: restore per-mob pacing or delete
  the coroutine/cache/gate to cut misleading complexity. (Not mechanically safe
  to auto-remove; truncated file.)
- [P3] **Per-turn deep time-freeze probe.** `_is_time_frozen_for_nonhero()`
  walks `GameManager → get_primary_hero → belongings → get_equipped_artifact →
  is_time_frozen` for *every* non-hero actor turn (`turn_manager.gd:52-64, 235`),
  even with no hourglass equipped. — Resolve the frozen flag once per hero action
  and cache it for the mob-processing pass.
- [P3] **All lookups are O(n) linear scans.** register dedup, `spend_energy`,
  `set_cooldown`, `get_cooldown`, `refresh_speed`, `has_actor`, `remove_actor`
  each scan `_actors` (`turn_manager.gd:108-178`); several run every action. —
  Add a `node → entry` Dictionary index for O(1) access as mob counts grow.

## Additions
- [P2] **No headless tests for the scheduler.** Cover: cooldown rebasing (min
  subtracted so the next actor hits 0, `:208-211`), speed→cooldown division
  (slow pays more, `:151-155`), `round_completed` fires once per party round
  (`:264-270`), `remove_actor` cleans `_round_hero_ids_pending` (`:122-130`),
  and the freed-actor skip in `process_turn` (`:218-222`).
- [P3] **Silent stuck-schedule handling.** `process_until_hero()` bails after
  500 iterations with no diagnostic (`:343-352`); if no hero is registered it
  quietly burns 500 mob turns on load. — Log a warning on cap-hit to surface a
  hero that never gets scheduled.

## Save/load & coupling notes
- Autoload holding **all** live scheduling state in memory; persists **none** of
  it (relies on `clear_actors` + re-register + `process_until_hero` on load).
- Couples to `GameManager` (primary-hero lookup for time-freeze + async abort),
  `MessageLog` (`current_turn = _round_count` for message grouping,
  `:268-269`), and `SceneTree.current_scene` (`on_mob_action`, `_game_ended`).
- `_turn_count` is incremented in three places (`process_turn`,
  `hero_action_complete`, time-freeze path) — verified no double-count per hero
  action (hero branch of `process_turn` returns before its increment).

## Research notes
- SPD `Actor.java`: fixed-point `time`, a `now` cursor, and an `actPriority`/`id`
  tie-break drive `Actor.process()`; actor `time` is stored in the save bundle.
  This port simplifies to a hero-pause loop with relative cooldowns rebased to 0
  each step — playable, but it drops both the persisted-timing and the
  deterministic priority tie-break (here ties resolve by registration order,
  acceptable under hero-pause).
- Godot 4.5: caching `get_speed()` is a valid micro-opt but only sound with a
  disciplined invalidation contract; live re-query per action is the more
  robust default at this actor count.
