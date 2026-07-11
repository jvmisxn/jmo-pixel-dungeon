# Level Features — Audit

- Files: `src/levels/features/chasm.gd`, `src/levels/features/door.gd`
- Read in full: yes (both; 53 + 101 lines). Cross-referenced callers in `hero.gd`, `mob.gd`, `level.gd`, `input_coordinator.gd`.
- Verdict: **needs-hardening** — `door.gd` is live but has a locked-door key bug + duplicated open logic; `chasm.gd` is entirely dead while the live inline chasm path is instant-death (major SPD divergence).

## Improvements
- [P1] **Chasms are instant-death instead of fall-to-next-floor.** `chasm.gd` (`fall`/`can_cross`/`find_safe_landing`) is *never referenced* anywhere. The real chasm interaction is inlined in `hero.gd:662-666` as `take_damage(hp_max, null)` → guaranteed death. In SPD a chasm drops the hero to the *next depth* into a pit room, dealing HP-scaled fall damage + bleed (`maxHP / (6 + 6*(HP/maxHP))`), and levitation lets you cross safely. This is reachable (S09 noted boss-arena knockback can eject the hero into a chasm ring). Direction: replace the inline lethal branch with a real fall — check `Levitation` buff first, then trigger a floor descent + scaled fall damage; either revive `chasm.gd` as the single source of truth or delete it. `hero.gd` is truncated → backlog for gated fix.
- [P1] **Locked doors require the wrong key (`golden`, not `iron`).** `door.gd:25` opens `LOCKED_DOOR` only if `opener.has_key("golden")`, consuming a golden key. SPD locked (iron) doors open with **iron** keys; golden keys are for golden chests/heaps. The game hands out iron keys and `hero.has_key()` even has special iron-key depth-matching logic (`hero.gd:730`) — but nothing ever asks for `"iron"`, so that path is dead and iron keys can't open the doors they're minted for. Direction: `LOCKED_DOOR` → `has_key("iron")`/`use_key("iron")`; reserve golden for chests. `door.gd` truncated → backlog.
- [P2] **`chasm.gd.can_cross` buff-id case mismatch.** Checks `has_buff("levitation")` (lowercase) but the buff is registered `buff_id = "Levitation"` (`levitation.gd:8`). Even if `chasm.gd` were wired in, levitating heroes would still "fall." Fold into the P1 chasm rework.
- [P2] **`door.gd.open` SECRET_DOOR reveal returns false but costs the turn ambiguously.** Revealing a secret door via `open` (`door.gd:60-65`) mutates terrain to `DOOR` and returns `false`; the interact caller (`hero.gd:630`) ignores the return, so the reveal is silent about whether a turn was consumed. Minor UX/turn-accounting nit — align with `_do_search` semantics.

## Optimizations
- [P2] **Door-open logic is triplicated.** The "set OPEN_DOOR + emit `door_opened` + `record_stat('doors_opened')`" sequence exists in three places: `door.gd.open` (interact path), `hero.gd:337-342` (auto-open on walk-into), and `mob.gd:401-404` (mob steps on door). The auto-open and mob copies bypass `DoorFeature`, so any future door rule (e.g. crystal/locked handling, sfx) must be changed in three spots. Direction: route all three through `DoorFeature.open` / a shared `Door.force_open(level,pos)` helper.
- [P3] **`door.gd.close` is dead code.** No caller (`rg` finds only unrelated `file.close`). SPD has no manual door-closing for the hero; either wire it to a mechanic or drop it. (Truncated file → backlog, don't auto-delete.)

## Additions
- [P2] **No `PitRoom` landing on chasm descent.** Tied to the P1 chasm fix: SPD lands the faller at a random point of the next level (often a pit room). `find_safe_landing` in the dead `chasm.gd` gestures at this but is unused and only scans 8-adjacent then falls back to a fully random cell. A proper implementation should hand off to the floor-transition coordinator with a "fell" flag.
- [P3] **No unit coverage for door key gating / chasm fall.** Both are pure-ish logic (given a level + opener) and would be cheap to test once corrected — good first framework-extraction test targets.

## Save/load & coupling notes
- Neither feature holds state; both are stateless static/`RefCounted` helpers, so no persistence contract. Door/chasm *terrain* is serialized by `Level` (the `map` array), and `SECRET_DOOR→DOOR` reveals persist through terrain. No save/load risk here.
- Coupling: `door.gd` reaches into `EventBus`, `GameManager`, `MessageLog`, and `opener.has_key/use_key` (duck-typed). `chasm.gd` references `Level`, `ConstantsData`, `MessageLog` but, being dead, couples to nothing at runtime. `hero.gd` preloads `door.gd` as `DoorFeature`; `chasm.gd` has no `preload`/`class_name` consumer.

## Research notes
- SPD chasm behavior confirmed: fall descends to the next floor (into a pit room), damage is HP-scaled (`maxHP / (6 + 6*(HP/maxHP))`) with bleed inversely scaled to current HP; you land at a random point; levitation crosses safely. Pixel Dungeon Wiki — Chasm.
- SPD key semantics: iron keys → locked (iron) doors; golden keys → golden chests/heaps; crystal keys → crystal chests/doors. Confirms the `door.gd` LOCKED_DOOR→golden mapping is inverted.
- Sources: https://pixeldungeon.fandom.com/wiki/Chasm , https://pixeldungeon.fandom.com/wiki/Shattered_Pixel_Dungeon/Special_Rooms
