# UI components — Audit

- Files: `src/ui/components/{buff_icon,circular_icon_view,health_bar,icon_button,item_slot,toast}.gd`, `src/ui/ui_utils.gd`
- Read in full: yes (all 7). `icon_button.gd` is in `TRUNCATED_FILES.txt` — read-only, never edited.
- Verdict: **fragile** — a 7-piece component library where only `ItemSlot` is wired in. The other six (BuffIcon, HealthBar, Toast, CircularIconView, IconButton, UIUtils) have **zero external references**, and the live buff renderer hand-rolls an inferior copy of the unused `BuffIcon`.

## Improvements
- [P1] **`BuffIcon` (151 lines) is dead; the live buff row is a worse reimplementation.** `status_pane._update_buffs` (`src/ui/status_pane.gd:519`) draws each buff as a flat `ColorRect`, discarding BuffIcon's letter glyph, expiry-flash (`FLASH_THRESHOLD` = 3 turns), and `"<name> (N turns)"` tooltip. Confirms S35's "buff icons are flat ColorRects, `buffs.png` unused." — Direction: instantiate `BuffIcon` in `_update_buffs`, set `buff_ref`, and call `update_flash_state()` on each refresh instead of building bare `ColorRect`s.
- [P1] **`UIUtils` (32 lines) has 0 callers — its whole reason to exist never landed.** Its docstring claims it "eliminates duplicated `_get_autoload` across HUD, StatusPane, Minimap, GameLogDisplay, and window files," but nothing calls `UIUtils.get_autoload/get_hero/get_game_manager/get_event_bus`; UI files still hand-roll autoload access (`wnd_settings.gd:121`, etc.). A dead anti-duplication helper is worse than none (it rots silently). — Direction: adopt it across the UI layer, or delete it.
- [P2] **`HealthBar` (109 lines) is dead.** `status_pane` uses a raw `ProgressBar` for HP/XP (`src/ui/status_pane.gd:277`), forgoing HealthBar's smooth value tween, automatic HP color thresholds (green/yellow/red), and centered `current/max` text. — Adopt in status_pane or delete.
- [P2] **`Toast` (100 lines) notification system is fully unwired.** `Toast.show_toast()` has 0 callers and `Toast` is **not** registered as an autoload (absent from `project.godot`), so `instance` is always `null` and every static call is a silent no-op. — Register as an autoload and emit on pickups/level-ups (SPD-style transient feedback), or delete.
- [P2] **`CircularIconView` (70 lines) is dead.** No references; `status_pane`/`hero_select` build portraits by hand. — Adopt for circular pixel-art portraits, or delete.
- [P3] **`IconButton` (194 lines) has 0 external references** (file is in `TRUNCATED_FILES.txt` — do not edit). Verify `toolbar`/HUD don't reimplement its procedural icons; adopt or backlog for removal.

## Optimizations
- [P3] ~430 lines across BuffIcon/HealthBar/Toast/CircularIconView ship unused — dead parse/class-registration weight. Adopting or removing them both fixes correctness and trims cost.
- [P3] `ItemSlot` static `_sprite_cache`/`_sheet_texture` (`src/ui/components/item_slot.gd:110`) are never invalidated — fine for a fixed `items.png`, but note the shared mutable static state for any future framework extraction.

## Additions
- [P2] No tests for any UI component. `ItemSlot._get_sprite_index`/`_get_category` fallback and the atlas cropping math (`_get_sprite_texture`, `src/ui/components/item_slot.gd:114`) are testable headless. Add coverage.
- [P3] Once wired, `Toast` should subscribe to `EventBus` (item pickups, level-ups) rather than being pushed imperatively, matching SPD's transient-notice pattern.

## Save/load & coupling notes
- All seven components are correctly **transient** — nothing is serialized; they are pure view layer. `ItemSlot` duck-types item properties via safe accessors (`_get_category`, `_is_cursed`, etc.), so it tolerates the S12/S13 item-contract gaps without crashing.
- `UIUtils` is the *intended* decoupling seam for autoload access but is bypassed everywhere; the coupling it was meant to remove is still present.

## Research notes
- SPD's `StatusPane`/`BuffIndicator` render real buff icons with countdown flashing (matches BuffIcon's design, not the ColorRect stand-in). Godot 4.5: custom `Control._draw` components like these are idiomatic; the debt here is wiring, not implementation.
- Reference checks: repo-wide `rg` for each `class_name` — only `ItemSlot` returns external hits (8 window files + `status_pane.gd`); the other six return zero.

## Auto-fixes this run
- Deleted orphaned tracked artifact `src/ui/components/.fuse_hidden0000001c00000009` (self-labeled "safe to delete," non-`.gd`, unreferenced).
- Wrapped one over-length line in `item_slot.gd` (gdlint `max-line-length`) — formatting only, no behavior change.
