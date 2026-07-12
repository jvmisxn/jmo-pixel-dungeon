# Windows — Audit

- Files: `src/ui/windows/` — wnd_base, wnd_inventory, wnd_item, wnd_shop, wnd_item_select,
  wnd_alchemy, wnd_transmute, wnd_reforge, wnd_badges, wnd_hero_info, wnd_journal,
  wnd_settings, wnd_talents, wnd_map, wnd_game, wnd_quest_reward, wnd_profile_icon_picker,
  wnd_quickslot_select, wnd_augment_select (19 files, ~4488 lines)
- Read in full: yes (all 19)
- Verdict: needs-hardening — chrome/layout is clean and consistent (`WndBase` shell +
  `open_sub_window` signal avoid `get_parent()` walks; nice pattern). But the *action* half
  leaks: a real crash dropping equipped rings, offline paths open-code game-state mutation in
  the view layer (diverging from the clean online `request_hero_action` path), and several
  hardcoded ID/content lists that will silently drift from the item source of truth.

## Improvements
- [P1] **Dropping an equipped ring crashes.** `wnd_item.gd:284` — `_action_drop` tests
  `_hero.belongings.ring == _item`, but `Belongings` has no `ring` field (only `ring_left` /
  `ring_right`, `belongings.gd:23-25`). At runtime this raises `Invalid get index 'ring'` when
  an equipped ring is dropped. `_action_unequip` was updated to handle both ring hands
  (`wnd_item.gd:211-214`) but `_action_drop` was not. Fix: mirror the ring_left/ring_right
  branches. (File is TRUNCATED → backlog, do not auto-edit.)
- [P1] **Offline action paths mutate authoritative state inside the view layer.** The online
  branch of every action window correctly routes through `EventBus.request_hero_action`, but
  the offline branch open-codes model mutation in the window: `wnd_transmute.gd:326-359`
  (unequip / remove_item / add_item / consume scroll), `wnd_alchemy.gd:199-202` (add_item +
  `toolkit.on_craft`), `wnd_shop.gd:197-202,242-247` (`GameManager.gold -= price`,
  `belongings.add_item`, `_shop_items.remove_at`). This couples UI to model, runs outside the
  turn pipeline, and forces two divergent code paths per action (a recurring port theme). Route
  offline through the same `request_hero_action` handlers.
- [P1] **Hardcoded ID lists drift from the item catalog.** `wnd_transmute._transmute_ring`
  (`:464-469`, 11 ids) and `_transmute_wand` (`:481-487`, 13 ids) hardcode ID arrays, while the
  sibling transmuters use `Potion.all_ids()` / `Scroll.all_ids()` / `Armor.all_armor_ids()` /
  `Artifact.all_ids()`. Root cause: **`Ring` and `Wand` expose no `all_ids()`** (confirmed — no
  enumeration const/method in `src/items/rings/` or `src/items/wands/`). Add `Ring.all_ids()` /
  `Wand.all_ids()` and consume them, so new rings/wands become transmutable automatically.
- [P2] **`wnd_transmute._transmute_armor` ignores tier despite its comment.** `:431` says "Try
  to stay same tier" but `:425-433` picks a random armor of *any* tier from `Armor.all_armor_ids()`,
  then the caller transfers the original upgrade level (`:319-320`) onto a possibly different-tier
  armor. Decide intended behavior and align comment/code.
- [P2] **`wnd_reforge` offline path silently no-ops.** `_on_reforge_pressed:286-291` — if
  `_blacksmith` is null or lacks `reforge()`, `success` stays false and the button does nothing
  with no user feedback. Add a fallback reforge or an info message.
- [P2] **"Drag here to sell" is a dead affordance.** `wnd_shop.gd:81,90` advertise dropping items
  onto `_sell_area`, but no window implements `_get_drag_data` / `_can_drop_data` / `_drop_data`
  (grep-confirmed: none in `src/ui/windows/`). Only the "Sell from Inventory" button works. Either
  wire drag-drop or drop the misleading copy.
- [P3] **`wnd_badges` hardcodes 26 badge IDs** (`:207-227`) that can diverge from the Badges
  catalog — ties into S29's `get_total_badge_count()` mismatch. Drive the grid from the catalog.

## Optimizations
- [P2] Grids rebuild wholesale on every interaction: `refresh_content()` frees and re-`_build_content()`s
  all children, and `_refresh_grid()` (`wnd_inventory:127`, `wnd_transmute:165`, `wnd_reforge:145`)
  `queue_free()`s and reallocates every `ItemSlot` per filter click / selection. For 20-slot grids
  this churns nodes each keystroke; pool/reuse slots or diff.
- [P3] `wnd_hero_info` / `wnd_talents` do a full `refresh_content()` (whole-window rebuild) on every
  `hero_stats_changed` emit (`wnd_hero_info:198`, `wnd_talents:128`). Fine at current cadence; would
  matter if stats churn per-turn.
- [P3] `wnd_transmute._on_transmute_pressed` computes a dead `var cat` (`:307`) — removed this run.

## Additions
- [P1] **No tests** for window pure-logic that is easy to unit-test and easy to break: transmute
  category→id mapping and tier bucketing (`_get_weapon_ids_for_tier` assumes exactly 5 weapons/tier,
  `:516`), inventory category filtering, reforge result-level math (`maxi(l1,l2)+1`, `:253`).
- [P2] Keyboard navigation / auto-select is absent; windows only respond to ESC (via `WndBase`).
  Number-key quickslot picks and arrow nav would match SPD desktop feel.
- [P3] Framework-extraction hook: `WndBase` + `open_sub_window` + `create_spd_button` is a clean,
  game-agnostic modal-window kit worth lifting into a reusable UI module.

## Save/load & coupling notes
- Windows are correctly transient — none are serialized; all read live from `GameManager` /
  `_hero.belongings` / autoloads and rebuild on open. No persistence contract to protect. ✔
- Autoload coupling is broad but guarded (`GameManager`, `EventBus`, `NetworkManager`, `MessageLog`,
  `SaveManager`, `AudioManager`, `PlayerProfile`, `ItemCatalog`, `DiscoveryCatalog`, `Generator`),
  mostly behind `has_method` / `has_signal` null-checks. The `open_sub_window` signal instead of
  `get_parent()` is the right decoupling choice and is used consistently.
- Divergence risk (not data-loss): the offline-vs-online action split means shop/alchemy/transmute
  economy logic lives in two places; the view copy can desync from the model (e.g. `_shop_items` is
  the window's own array).

## Research notes
- SPD reference: item action windows (WndItem/WndBag) route use/equip/drop/throw through the actor's
  action queue, never mutating belongings from the UI — matches the recommendation to unify on
  `request_hero_action`.
- Verified against source: `belongings.gd` has `ring_left`/`ring_right`, no `ring`; `Ring`/`Wand`
  expose no `all_ids()`; no `_drop_data` anywhere under `src/ui/windows/`. `gdparse` clean on
  wnd_item.gd and wnd_transmute.gd (parser doesn't resolve the `.ring` member access, so the crash
  is runtime-only).
