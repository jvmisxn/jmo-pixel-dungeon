# HUD / toolbar / status — Audit

- Files: `src/ui/hud.gd`, `src/ui/toolbar.gd`, `src/ui/status_pane.gd`, `src/ui/minimap.gd`, `src/ui/boss_hp_bar.gd`
- Read in full: yes (all five)
- Verdict: **needs-hardening** — HUD wiring, status pane, toolbar and minimap render cleanly and are correctly transient (nothing serialized), but the entire boss HP bar is dead (no `boss_fight_started` emitter anywhere), the minimap's per-move FOV refresh reads a non-existent level property so live visibility never updates, and buff icons/portrait sheets are stubbed to flat color rects.

## Improvements
- [P1] **Boss HP bar is fully dead code.** `hud.gd:249-251` subscribes `boss_fight_started/damaged/defeated`, and `boss_hp_bar.gd` (175 lines) implements the whole panel + tweens, but a repo-wide grep finds **no emitter** for any of the three signals outside their `event_bus.gd` declarations. Every boss fight (Goo, Tengu, DM-300, King, Yog) runs with no HP bar. SPD shows a `BossHealthBar` for all bosses. — Fix: emit `boss_fight_started` when a boss (or its arena) activates, `boss_damaged` from the boss's `take_damage`, `boss_defeated` on death. Couples with S09 (boss levels) and S27 (event-bus dead half-connections).
- [P2] **Minimap never refreshes live visibility on move.** `minimap.gd:244-245` guards on `level.get("visible_cells")` and assigns `level.visible_cells`, but the level's property is `visible` (`level.gd:22`; there is no `visible_cells`). The branch is dead, so after level entry `_visible_cells` is frozen: currently-lit dimming and the visible-gated mob dots (`minimap.gd:155-160`) go stale as the hero moves. `map`/`visited` update correctly, so exploration still fills in. — Fix: read `level.get("visible")` / `level.visible`.
- [P2] **level_changed double-drives the minimap with an order-dependent clear.** Both `hud._on_level_changed` (`hud.gd:378-391`, calls `_minimap.update_map(...)` with real data) and `minimap._on_level_changed` (`minimap.gd:274-282`, blanks the image + clears all arrays) connect to the same `EventBus.level_changed`. Whichever fires last wins; if the minimap's clear runs after the HUD's populate, the fresh map is wiped until the next move. — Fix: pick one owner. Let the minimap self-populate from GameManager on `level_changed` (like its `_on_hero_moved` path) and drop the HUD's manual `update_map`, or have the HUD stop clearing.
- [P2] **BossHPBar hard-codes 1280 for centering and never re-centers.** `boss_hp_bar.gd:42` computes `position.x = (1280 - BAR_WIDTH - 40)/2`; there is no `size_changed` listener, so on any non-1280 viewport the bar is off-center (and stays wrong after resize). — Fix: center off `get_viewport().get_visible_rect().size` and subscribe to `size_changed` (HUD already has a resize hook to delegate through).

## Optimizations
- [P2] **StatusPane `_process` runs every frame unconditionally.** `status_pane.gd:67-94` fetches the hero and re-sets `_portrait_fallback.modulate` every frame even when healthy (the `else` branch writes `Color.WHITE` each tick). Cheap but constant. — Fix: early-out when HP ratio ≥ 0.334 and already reset; only run the flash interpolation while actually low.
- [P3] **StatusPane `_update_buffs` frees + recreates every icon on each `update_all()`** (`status_pane.gd:510-528`), which fires on every `hero_stats_changed`. For a hero with several buffs this churns nodes each turn. — Fix: diff against the current buff set and reuse ColorRects, or pool them.
- [P3] **HUD `_on_hero_moved` is a connected no-op.** `hud.gd:398-400` is `pass` (comment says the minimap handles it) yet `hud.gd:246` still connects it to `hero_moved`. Harmless but a wasted subscription. — Fix: drop the connection.

## Additions
- [P2] **Buff icons render as flat colored squares; `buffs.png` is declared but unused.** `status_pane.gd:41` defines `BUFFS_PATH` but `_update_buffs` builds `ColorRect`s tinted by `icon_color`/positivity only. SPD renders real 16×16 buff sprites from `buffs.png` indexed per buff. — Fix: atlas-slice `buffs.png` by each buff's icon index (mirrors the toolbar's `_get_item_texture` pattern in `toolbar.gd:225-246`).
- [P3] **Dead status-pane asset consts.** `STATUS_PANE_PATH` and `HERO_ICONS_PATH` (`status_pane.gd:39-40`) are each referenced only at their declaration — breadcrumbs for SPD status-frame / hero-icon art that was never wired. — Either wire them into the panel background/level pips or delete. (Left in place this run to avoid pre-empting the buff-icon/portrait art work above.)
- [P3] **No smoke tests for HUD state math.** Party-row focus/marker formatting (`hud.gd:471-495`), online-state text (`_refresh_online_state`), and minimap `_terrain_to_color` are pure and testable without a viewport. — Fix: add a headless test harness for these string/color mappings.

## Save/load & coupling notes
- All five files are pure view: nothing here is serialized (correct — SPD rebuilds HUD from hero/level state), so there is no persistence risk in this system.
- Coupling is heavy on autoloads: `GameManager` (hero/level/depth/gold/party), `EventBus` (stats/level/gold/move/boss/window/equip signals), `NetworkManager` (online gating), `TurnManager` (input-actor + rest gating), `MessageLog`. The `has_method`/`get_prop` guards throughout keep it defensive and MP-safe.
- The boss-bar and per-move minimap FOV are the two wiring gaps; both are one-directional (a missing emitter / a wrong property name), not structural.

## Research notes
- SPD (`StatusPane.java`, `BossHealthBar`): status pane shows portrait + HP/XP + buff icon strip from `buffs.png`, and bosses always display a top health bar — confirms the two P1/P2 fidelity gaps (dead boss bar, flat buff squares).
- Godot 4.5: `TextureRect` + `AtlasTexture` with `TEXTURE_FILTER_NEAREST` is the idiomatic pixel-sheet slice (already used by toolbar quickslots and the portrait); the buff-icon addition should reuse that path rather than ColorRects.
- Signal fan-out to two autonomous subscribers of the same EventBus signal (HUD + minimap on `level_changed`) has no defined ordering in Godot — the order-dependent clear is a real hazard, not theoretical.

## Auto-fix applied this run
- Removed two dead, never-connected HUD stubs `_on_wait_pressed` / `_on_search_pressed` (`hud.gd`) — wait/search are owned by GameScene (`game_scene.gd:969-974` connects the toolbar signals to `_on_toolbar_wait`/`_on_toolbar_search`); the HUD copies were `pass` no-ops referenced nowhere. Pure deletion, no behavioral change. Verified with `gdparse`.
