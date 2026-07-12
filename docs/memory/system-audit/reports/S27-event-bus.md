# EventBus — Audit

- Files: `src/autoloads/event_bus.gd` (41 signals, declarations only) + repo-wide emit/connect wiring
- Read in full: yes. Cross-referenced all 286 `EventBus.` call sites across `src/`.
- Verdict: **needs-hardening** — the bus itself is clean and well-documented, but the wiring around it has several dead half-connected signals: the entire boss HP-bar feature is subscribed-but-never-emitted, and five signals are emitted-but-never-consumed. Plus pervasive always-true `has_signal()` guards.

`event_bus.gd` is in `TRUNCATED_FILES.txt` — read-only, no edits this run.

## Signal wiring map (the real finding)

Every signal was classified by emit sites vs. connect sites repo-wide:

- **Live (both ends wired):** hero_moved(+_detailed), hero_damaged(+_detailed), hero_died(+_detailed), hero_stats_changed, mob_defeated, mob_moved_detailed, mob_damaged, hero_attack_missed, mob_revealed, enchantment_proc, glyph_proc, item_picked_up/used/equipped/unequipped, level_changed, door_opened, trap_triggered, gold_collected, game_event, badge_unlocked, hero_trampled_grass, seed_planted, plant_activated, status_effect_applied, enter_targeting, request_hero_action, npc_interacted. (28 signals)
- **Emitted, NEVER consumed (dead broadcast):** `mob_died`, `quest_updated`, `game_saved`, `game_loaded`, `npc_face_hero`.
- **Connected, NEVER emitted (dead subscriber):** `boss_fight_started`, `boss_damaged`, `boss_defeated`, `cancel_targeting`.

## Improvements

- **[P1] Boss HP-bar feature is fully dead — the three boss signals are subscribed but never emitted.** `hud.gd` instantiates `boss_hp_bar.gd`, connects all three (`hud.gd:249-251`), and has working handlers (`hud.gd:403-415` → `show_boss`/`update_hp`/`hide_boss`). But a repo-wide grep finds **zero** emitters of `boss_fight_started`/`boss_damaged`/`boss_defeated` (declared `event_bus.gd:137,140,143`). Net effect: the boss HP bar never appears, never updates, never hides — SPD shows a boss bar the moment a boss becomes alerted, tracks damage, and drops it on death. → Emit `boss_fight_started(name, hp)` from the boss mob's alert/notice transition, `boss_damaged(hp, max)` in the boss `take_damage` path, and `boss_defeated` in its death path. (Ties to S35 HUD + S09 boss levels.)
- **[P2] `cancel_targeting` is connected but never emitted → the cancel handler is dead code.** `game_scene.gd:927` connects `_on_cancel_targeting`, but nothing emits `cancel_targeting` (declared `event_bus.gd:129`). Targeting cancel today only works via the direct ESC branch found in S23; the intended decoupled cancel path is inert. → Either emit it from the ESC/right-click cancel site or remove the dead subscriber. (Ties to S23 input/targeting.)
- **[P2] `quest_updated` is broadcast 11× but nothing listens.** Emitted from every NPC/quest (`ghost.gd:219/236/329`, `blacksmith.gd:88/194`, `imp.gd:152/245`, `wandmaker.gd:137/220`, `rotberry.gd:26`, `wnd_quest_reward.gd:164`) but has no connect anywhere. SPD surfaces quest state in the journal/hero-info; here the signal is a no-op. → Add a consumer (quest journal / badge hook / message-log toast) or the emissions are pure overhead. (Ties to S21 NPCs & quests.)
- **[P2] `mob_died(mob)` is emitted 5× but has no consumer; loot/effects actually run off `mob_defeated`.** `mob.gd:439`, `piranha.gd:114`, `mimic.gd:123`, `bee.gd:93`, `animated_statue.gd:130` all emit `mob_died.emit(self)` (declared "for loot/effects", `event_bus.gd:38`), yet nothing connects to it — the six real consumers (`game_scene`, `ghost`, `quest_handler`, `discovery_catalog`, `player_profile`, `badges`) all listen to `mob_defeated(pos,name,id)`. Two parallel death signals, one of them dead. → Either wire `mob_died` where an object handle is genuinely needed (drops/on-death FX) or drop it and stop emitting.

## Optimizations

- **[P2] Pervasive always-true `has_signal()` guards before emit.** `shopkeeper.gd:54/166`, `blacksmith.gd:144`, `ghost.gd:317`, `imp.gd:233`, `wandmaker.gd:204`, `game_scene.gd:926`, `online_event_codec.gd:527` all wrap emits in `if EventBus and EventBus.has_signal("...")`. EventBus is a statically-declared autoload — these branches are always true, adding a dictionary lookup per emit and implying a fragility that doesn't exist. → Emit directly; the signal is compile-time guaranteed.
- **[P3] Redundant `X` + `X_detailed` double-dispatch on every hero move/damage/death.** Each site fires both the object-carrying `_detailed` variant and the legacy single-hero plain variant (e.g. `hero.gd:347-350`, guarded so plain only fires for the primary hero). Both have live consumers (hud/minimap/game_scene), so neither is dead, but it's two emissions + two connect fan-outs per event. → As the port goes MP-aware, prefer the `_detailed` variant and let single-hero consumers filter; retire the plain trio later.

## Additions

- **[P3] `game_saved`/`game_loaded` are emitted (`save_manager.gd:54/125`) but unconsumed** — free hooks for a "Game saved" toast, autosave indicator, or post-load UI refresh. Cheap parity win with SPD's save feedback.
- **[P3] No test coverage of the bus contract.** A tiny headless test that asserts every declared signal has ≥1 emitter AND ≥1 consumer would have caught all four dead-boss/cancel signals mechanically. High leverage as a framework-extraction hook.
- **[P3] Signal payload typing is all `Variant` for actors/items/windows** (circular-dep avoidance). Acceptable in Godot, but a short doc note or typed wrapper structs would harden the MP codec path in `online_event_codec.gd`, which already special-cases several of these by name.

## Save/load & coupling notes

- EventBus holds no state — pure signal declarations, nothing to serialize. Correct for an autoload bus.
- Coupling is healthy in intent (decoupled pub/sub) but leaky in practice: `online_event_codec.gd` and `game_scene.gd` re-mirror specific signals into the network layer by string name, so signal renames must be tracked in two places.
- No central emission log/replay; MP sync is hand-wired per signal. Not a bug, but a fragility to note for the networking system (S31).

## Research notes

- SPD (`ui/BossHealthBar.java`): the boss bar is shown when the boss first becomes aware/alerted, updated each time boss HP changes, and hidden on the boss's death — exactly the `started/damaged/defeated` triple this bus declares but never fires. Confirms the P1 wiring gap is a real feature regression, not a design choice.
- Godot 4.5 best practice: prefer direct `signal.emit()` on autoload singletons over `has_signal()` guards; the guard pattern is a holdover from dynamic `connect(String)` days and costs a lookup for no safety on statically-declared signals.
- Method: classified all 41 signals by cross-referencing `EventBus.<sig>.emit` / `emit_signal("<sig>")` against `.<sig>.connect` (both `EventBus.` and local `event_bus.` forms) repo-wide; the four dead-subscriber / five dead-broadcast signals were each confirmed by an explicit empty-result grep for the missing half.
