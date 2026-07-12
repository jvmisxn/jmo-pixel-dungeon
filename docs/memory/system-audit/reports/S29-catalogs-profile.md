# Catalogs & profile — Audit

- Files: `src/autoloads/badges.gd`, `src/autoloads/discovery_catalog.gd`, `src/autoloads/item_catalog.gd`, `src/autoloads/item_appearance.gd`, `src/autoloads/player_profile.gd`, `src/autoloads/constants.gd`
- Read in full: yes (all six)
- Verdict: **needs-hardening** — persistence and event wiring are solid, but the badge total is wrong (denominator omits 3 unlockable badges), one catalog skips the key-coercion its siblings use on load, and there's redundant/heuristic badge logic + eager-save churn.

## Improvements
- [P1] **`get_total_badge_count()` undercounts by 3 — count can read `26/23`.** `_ALL_BADGE_IDS` (`badges.gd:413-441`, 23 entries) omits `strength_15`, `first_death`, and `death_by_goo`, all of which are unlockable via `unlock()` (`badges.gd:343,301,306`). `get_unlocked_count()` returns `_unlocked.size()` (`badges.gd:112`), so once any of those three fire, unlocked exceeds total in both the badges window (`wnd_badges.gd:196-197`) and the profile summary (`player_profile.gd:228`). Note `wnd_badges.gd:222` even lists `strength_15` in its display grid. Fix: add the three IDs to `_ALL_BADGE_IDS` (or derive the total from the union of unlockable IDs). Behavioral (changes denominator) → backlog, not auto-fixed.
- [P2] **`ItemCatalog._load` assigns an untyped Dictionary into a typed field.** `item_catalog.gd:110` does `_identified_items = data.get("identified_items", {})` straight from `get_var()`, unlike `discovery_catalog.gd:126-131` and `badges.gd:381-387` which coerce keys/values into their `Dictionary[String, …]` fields. On Godot 4.4+ assigning an untyped dict to a statically-typed `Dictionary[String, bool]` can raise a runtime error (or silently drop typing), which on the load path would wipe global identification. Fix: add a `_coerce_string_bool_dict` mirroring the sibling catalogs.
- [P2] **`champion_win` is redundant with `all_classes_won`.** Both are unlocked under the identical "all five classes won" condition (`badges.gd:258-260`) with near-identical descriptions (`badges.gd:182-193` vs `227-228`). Two badges for one achievement inflates the catalog and diverges from SPD, where "Champion" is a distinct win-condition badge. Fix: repurpose or remove one.
- [P2] **`death_by_goo` false-positives on any depth-5 death.** `_on_hero_died` unlocks it whenever the hero dies at `GameManager.depth == 5` regardless of killer (`badges.gd:303-306`; the comment admits the heuristic). Should key off the actual damage source / boss identity.

## Optimizations
- [P2] **DiscoveryCatalog writes the whole catalog to disk on every record.** `_record` calls `_save()` unconditionally (`discovery_catalog.gd:87`), and `_on_mob_revealed` (`:59-61`) fires per revealed mob as FOV updates — several `store_var` writes of six dictionaries per turn. Add a dirty flag + save on run-save/quit (or debounce). Badges (`_save` per unlock) and ItemCatalog (`_save` per identify) share the eager pattern but fire far less often.
- [P3] **PlayerProfile double-saves per kill.** `_on_mob_defeated` calls `_refresh_unlocks()` (which itself calls `_save_profile()` when anything changed) then unconditionally `_save_profile()` again (`player_profile.gd:372-373`) → up to two `ConfigFile` writes per mob kill.
- [P3] **Per-proc object allocation for a name lookup.** `discovery_catalog.gd:72-80` builds a fresh `WeaponEnchantment`/`ArmorGlyph` on every enchantment/glyph proc solely to read its display name. A static id→name map avoids the allocation.

## Additions
- [P3] **Appearance pools silently truncate if content outgrows them.** `item_appearance.gd` guards with `mini()` (`:55,62,69`); pools are currently balanced (14 potions/14, 14 scrolls/14, 11 rings/11) but a 15th potion/ring would get an empty appearance with no warning. Add a `push_warning` when `ids.size() > pool.size()`.
- [P3] **Unreferenced public catalog getters.** `Badges.get_unlock_info` (`:103`), `Badges.get_all_unlocked` (`:96`), and `ItemCatalog.is_item_known` (`:58`) have zero repo-wide callers. Likely intended journal/extension API — confirm intent, then wire into the Journal window or drop. Left in backlog (not auto-deleted) since they read as intended framework hooks.
- [P2] **No round-trip tests.** Nothing exercises badge-count invariants (unlocked ≤ total), catalog serialize/deserialize, or appearance determinism-per-seed. A small headless test would have caught the denominator bug.

## Save/load & coupling notes
- Four distinct persistence stores: `badges.dat`, `discovery_catalog.dat`, `item_catalog.dat` (all `store_var`), plus `player_profile.cfg` (`ConfigFile`). `item_appearance` is per-run and round-trips through SaveManager via `serialize()`/`deserialize()` (`item_appearance.gd:102-115`). Two of three `store_var` loaders coerce keys; ItemCatalog does not (see P2 above).
- Heavy autoload coupling: these nodes reach directly into `EventBus`, `GameManager`, `Badges`, `MessageLog`, `Generator`, `NetworkManager`, `SaveManager`, and item classes (`Potion`/`Scroll`/`Ring`/`WeaponEnchantment`/`ArmorGlyph`). Mostly guarded with `has_signal`/null checks, which is defensive but adds noise.
- `constants.gd` is a pure data/static-helper module (no persistence); it's in `TRUNCATED_FILES.txt`, so read-only here regardless.

## Research notes
- SPD `Badges.java` derives totals from the `Badge` enum, so the count can't drift from the unlockable set — the port's hand-maintained `_ALL_BADGE_IDS` list is exactly the drift-prone pattern SPD avoids. SPD's "Champion" badge is a subclass/challenge win, distinct from "all classes won", confirming the P2 redundancy.
- Verified counts against source: `Potion.all_ids()` = 14 and `Scroll.all_ids()` = 14 (match `TOTAL_POTION_TYPES`/`TOTAL_SCROLL_TYPES`, so those two collection badges are reachable), `Generator.RINGS` = 11 (matches `RING_APPEARANCES`).
