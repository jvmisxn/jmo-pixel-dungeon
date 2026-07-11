# Potions & Scrolls — Audit (S15)

- Files: `src/items/potions/potion.gd` (840 lines), `src/items/scrolls/scroll.gd` (911 lines, TRUNCATED)
- Read in full: yes (both)
- Verdict: **needs-hardening** — drink/read paths are faithful and clean, but the entire *thrown-potion* feature is unwired (all 13 `shatter()` overrides are dead), `split()` downgrades stacks to inert base items, and offensive gas potions apply one-shot 3×3 buffs instead of spreading Blobs.

## Improvements
- [P1] **Thrown potions never shatter — all 13 `shatter()` overrides are dead code.** `hero._do_throw_item()` (`hero.gd:414`) special-cases `Bomb`, `SeedItem`, `MissileWeapon`, `SpiritBow`, then falls through to a generic ranged-attack/miss path. A `Potion` matches none of these, so `Potion.shatter()` is never invoked — repo-wide, `.shatter(` only appears as internal `super.shatter()` calls (`potion.gd`). Throwing a Potion of Toxic Gas / Liquid Flame / Frost / Paralytic Gas at enemies does nothing tactical. — Add a `Potion`/thrown-shatterable branch in `_do_throw_item` that calls `shatter(collision_pos, level)` and consumes one, then identifies on visible effect.
- [P1] **`duplicate_item()` returns a base `Potion`/`Scroll`, so `split()` produces inert items.** `Item.split()` (`item.gd:145`) calls `duplicate_item()`; both overrides (`potion.gd:69`, `scroll.gd:89`) do `Potion.new()` / `Scroll.new()` — the base class, whose `drink()`/`read_scroll()` are `pass`. Splitting a stack (partial throw, transfer, bones) yields a potion/scroll that copies the name/id but has **no effect** when used. Same family as S12's split finding, but here the *override meant to fix it is itself broken*. — Route through `Potion.create(item_id)` / `Scroll.create(item_id)` then copy fields (scroll.gd is TRUNCATED → backlog only).
- [P1] **Offensive potions apply a one-shot 3×3 buff instead of a spreading, persistent Blob.** ToxicGas/ParalyticGas/LiquidFlame/Frost iterate `DIRS_8` once and stamp a fixed-duration buff / terrain change (`potion.gd:444,487,541,629`). SPD seeds a `ToxicGas`/`ParalyticGas`/`Fire` Blob that spreads across cells and ticks damage each turn to anything standing in it. Current behavior is weaker, non-persistent, and ignores gas diffusion. Couples to pending **S20 Blobs** — build the Blob layer, then have these potions seed Blobs. — Backlog; behavioral.
- [P2] **`ScrollLullaby` fakes Sleep with a relabeled `Paralysis`.** `scroll.gd:519` news up a `Paralysis`, then overwrites `buff_id="Sleep"`/`buff_name="Sleeping"`, despite a real `SleepBuff` class existing (`buffs/sleep_buff.gd`, used by `drowsy.gd`). Paralysis semantics (no wake-on-approach / different tick) differ from Magical Sleep. — Use `SleepBuff` (scroll.gd TRUNCATED → backlog).
- [P2] **`ScrollTransmutation` fallback merely identifies the item.** When no HUD/`WndTransmute` is available, `_transmutation_fallback` (`scroll.gd:760`) picks the first eligible item and just calls `identify()` + a "transforms!" message — it never produces a *different* item. Misleading no-op. — Backlog.
- [P2] **`PotionMastery` auto-selects `subclasses[0]`** (`potion.gd:837`) with a "UI will present choice later" TODO — hero silently loses the class-choice decision. — Backlog (couples to S02 subclass gaps).

## Optimizations
- [P3] `PotionExperience.drink` computes `xp_to_next - xp` (`potion.gd:712`); SPD grants a fixed level-scaled amount. Minor fidelity, not perf-critical.
- [P3] The four AoE helpers (`_apply_gas/_fire/_frost/_paralysis_to_area`) duplicate the same "build DIRS_8 positions, find_char_at each" loop — extract a shared `_chars_in_3x3(spos, lvl)` helper once the Blob rework lands.

## Additions
- [P2] No test coverage for the drink/read effect matrix; a headless harness asserting each `create(id)` yields the right subclass and that split/duplicate preserves effect would have caught the `duplicate_item` bug.
- [P3] Stray `src/items/potions/potion_ending_fix.txt` (contents: `placeholder`) — unreferenced repo-wide, a leftover scratch artifact. **Auto-fixed this run.**

## Save/load & coupling notes
- Serialization is sound: `potion_type`/`scroll_type` = `item_id` drives factory reconstruction; `known`/`appearance_name`/`rune_symbol`/`potion_color` persist. Run-global identification is wired correctly through `ItemCatalog` (`item_catalog.gd:28,51` set `.known`) and per-run appearance via `ItemAppearance` — no gap there.
- `ScrollMagicMapping` correctly hits `level.reveal_all()` (`level.gd:705`) — not dead, despite defensive duck-typing.
- Autoload coupling: `MessageLog`, `EventBus`, `GameManager`, `ItemAppearance`, `NetworkManager`, `WndItemSelect`, `WndTransmute`. Scroll multiplayer routing (`_notify_hero`, `send_ui_event_to_peer`) is thorough.

## Research notes
- Verified against repo APIs: `hero.gd:414` throw pipeline, `item.gd:145` split/duplicate, `item_catalog.gd`, `sleep_buff.gd`, `level.gd:705`.
- SPD reference: shattering potions (Shattpixel `PotionOfToxicGas`/`LiquidFlame`) seed spreading Blobs; Magical Sleep (`MagicalSleep`) wakes on damage/proximity — distinct from Paralysis.
</content>
</invoke>
