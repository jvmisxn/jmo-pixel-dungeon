# GameManager & run lifecycle — Audit

- Files: `src/autoloads/game_manager.gd` (494 lines)
- Read in full: yes
- Verdict: needs-hardening — run-state model is clean and multiplayer-aware, but the
  canonical navigation (`descend`/`ascend`) and spend (`spend_gold`) APIs are dead: the
  live paths open-code the same mutations minus the safety rails (MAX_DEPTH cap, signal
  emission), and there is no run-state (de)serializer so SaveManager reaches into 11
  fields by hand — a coupling that already silently dropped `quest_flags` from saves.

## Improvements
- [P1] `descend()`/`ascend()` are dead code and the live path lost the MAX_DEPTH cap
  (`game_manager.gd:146,158`). No caller invokes `.descend()`/`.ascend()`; the real
  transition path is `floor_transition_coordinator.gd:23-25,54-56`, which inlines the
  body (`GameManager._cache_current_level()` + `GameManager.depth += 1` + `_on_depth_changed()`)
  **without** the `depth >= ConstantsData.MAX_DEPTH` guard in `descend()`. Result:
  descending past floor 26 is possible (confirms S24-P1) and the cap-enforcing version rots
  unused. Direction: route the coordinator through `descend()`/`ascend()` (restores the cap,
  dedups the mutation) or move the cap into the live path and delete the dead methods.
- [P2] `quest_flags` is not persisted (`save_manager.gd:145-176` omits it). It survives
  neither save nor `_cleanup_previous_run`. Currently latent (only `rotberry.gd:16` writes,
  and `get_quest_flag` has zero callers), but any future flag-gated content (Blacksmith/Imp
  quests) will silently reset on load. Direction: add `quest_flags` to the save dict; becomes
  P1 the moment a flag gates progression.

## Optimizations
- [DONE] Shop gold changes now route through canonical helpers: buys use `GameManager.spend_gold()`
  and sales use `GameManager.add_gold(sell_price, hero)`, so HUD listeners, collected-gold stats,
  and gold-pickup artifact hooks stay in sync. `Shopkeeper.sell_item()` pays `item.value()` to match
  SPD's `new Gold(item.value()).doPickUp(hero)` sale path, and `test_shop_gold_events.gd` locks the
  sale event/stat/hook contract.

## Additions
- [P2] No `serialize_run_state()`/`apply_run_state()` on GameManager despite the "Save / Load"
  section header (`:483`) and the class doc's "provides save/load functionality" claim
  (`:2-5`) — the only method there is `end_game()`. SaveManager hand-copies 11 fields
  (`save_manager.gd:145-176`); adding a field means editing two files in lockstep, which is
  exactly how `quest_flags` was missed. A single GM chokepoint would make save coverage a
  property of GameManager, not of SaveManager's memory.
- [P3] `current_region()`, `current_region_name()`, and `get_quest_flag()` have zero external
  callers — dead wrappers; callers use `ConstantsData.region_for_depth()` directly. Safe to
  drop once confirmed (all three touch nothing else).
- [P3] No unit tests for the lifecycle math: MAX_DEPTH cap, `compute_final_score()`,
  gold add/spend symmetry, and party-focus cycling (`cycle_local_hero_focus`). These are
  pure functions of state and are the natural first tests for a framework-extraction pass.

## Save/load & coupling notes
- Persisted via SaveManager: depth, gold, run_seed, score, hero_class, hero_subclass,
  party_classes, local_hero_index, run_active, stats, and `_level_cache`. NOT persisted:
  `quest_flags`, `current_level` reference (rebuilt), transient hero/mob nodes (rebuilt).
- Signals `depth_changed` + `EventBus.level_changed` DO fire on real transitions — the
  coordinator calls `_on_depth_changed()` directly (`floor_transition_coordinator.gd:25,56`),
  and `game_scene.gd:582-583` invokes it on snapshot depth changes. Listeners (minimap, hud,
  badges) are live. `local_hero_changed` only emits when `heroes.size() == 1` (`:334`);
  party heroes added later never emit (latent co-op gap).
- Autoload deps: ConstantsData, EventBus, ItemAppearance, NetworkManager, TurnManager — all
  guarded with null/`has_method` checks. Clean.

## Research notes
- SPD reference: `Dungeon.java` centralizes depth switching (`Dungeon.switchLevel`) and gold
  mutation, with UI refresh driven off those chokepoints. This port splits the chokepoint
  (canonical methods exist but the coordinator/shop bypass them), which is the root of both
  the missing depth cap and the stale-gold-HUD divergence.
- Cross-refs: S24 (transitions re-implement depth mutation w/o cap — same root),
  S01 (persistence: non-atomic write, no autosave), S21 (quest reward RNG / flag usage).
