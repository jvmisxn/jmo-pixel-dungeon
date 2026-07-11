# Bags & inventory containers — Audit

- Files: `src/items/bags/bag.gd`, `src/items/keys/key.gd` (integration: `src/actors/hero/hero.gd` `has_key`/`use_key`, `src/actors/hero/belongings.gd` deserialize, `src/items/generator.gd`, `src/levels/features/door.gd`)
- Read in full: yes (both system files; cross-read hero/belongings/generator/door for integration)
- Verdict: **fragile** — the container half of the system is inert (bags store nothing, half the key types unlock nothing); the per-item logic is clean but unwired.

## Improvements
- [P1] **Bags are non-functional containers.** `add_to_bag`/`can_hold`/`remove_from_bag`/`find_item`/`has_space` have **zero callers repo-wide** (`bag.gd:49,36,62,78,74` referenced only inside `bag.gd`). Belongings has no `bags` array and pickup never routes items into a bag. A generated bag (`generator.gd:311`) can be picked up but occupies an ordinary backpack slot and holds nothing. SPD bags auto-collect their category on pickup and expand effective inventory. — Wire pickup to scan belongings for a `Bag` whose `can_hold(item)` is true and divert the item into it; add a `bags` list to belongings.
- [P1] **`Bag.deserialize()` drops all bag contents.** `serialize()` writes `data["items"]` (`bag.gd:112-116`) but `deserialize()` never reads it — the comment "Items are deserialized by the item loading system" (`bag.gd:124`) points at a system that doesn't exist; belongings only reconstructs top-level `backpack`/slot items (`belongings.gd:381-401`), never a bag's inner `items`. Latent **data-loss** (P0-shaped) the moment bags are made live. — Have `deserialize()` rebuild `items` via `Generator.create_item(id)` + per-item `deserialize`, mirroring belongings.
- [P1] **Iron keys are dead.** Guards drop them (`guard.gd:15`), mimics can be them (`mimic.gd:40`), and `has_key("iron")`/`use_key("iron")` even implement the SPD depth-match rule (`hero.gd:727,739`), but **nothing calls them** — `door.gd:25` unlocks LOCKED_DOOR with `"golden"` instead of `"iron"` (also flagged in S11). Iron keys are unusable clutter. — Change the LOCKED_DOOR branch to `has_key("iron")`/`use_key("iron")`.
- [P1] **Skeleton keys are dead.** `has_key("skeleton")`/`use_key("skeleton")` have **zero callers**; the boss seal is opened by death (`unlock_exit`, S09), not by the boss-dropped skeleton key. The key is picked up and does nothing. — Either gate the down-exit on `has_key("skeleton")` or drop the item type.
- [P2] **`magical_holster` under-delivers vs its own description.** It promises "wands and missile weapons" (`bag.gd:160`) but `accepted_category` is only `WAND` and `can_hold` has no missile branch (the inline comment at `bag.gd:163-164` admits it). Missile weapons never qualify. — Add a missile check to `can_hold` (or a secondary predicate), since missiles are `WEAPON`-category subtypes.

## Optimizations
- [P3] `has_key`/`use_key` (`hero.gd:722,734`) duplicate the same backpack scan + iron depth-match. Extract a private `_find_key(type)` returning the item; both call it. Pure refactor, no behavior change.
- [P3] Non-`.gd` cruft: `src/items/bags/.fuse_hidden0000001100000005` (44 B FUSE leftover) sits in the source dir. Harmless, but not tracked/meaningful — safe to delete outside the audit gate.

## Additions
- [P2] **Belongings `bags` container + auto-sort** — the framework hook that makes P1 bags live: a `bags: Array[Bag]`, pickup auto-routing, and quickslot/inventory views that flatten bag contents. SPD parity.
- [P3] **Tests**: `can_hold` category/secondary/capacity matrix, `add_to_bag` stacking path (`bag.gd:53-57`), and key depth-matching (`has_key` iron cross-depth reject).

## Save/load & coupling notes
- Bag serialize contract is half-written: `serialize()` persists `size`/categories/`items`; `deserialize()` restores only `size`/categories, **silently discarding `items`**. Round-trips today only because bags are always empty.
- Keys serialize `depth` correctly (`key.gd:68-76`); `create()` and `on_pickup()` both stamp `depth = GameManager.depth`, and deserialize overrides it from save data — round-trip is sound.
- Coupling: keys depend on `GameManager.depth` (create/pickup/has_key) and `MessageLog`; bags depend on `MessageLog` + `ConstantsData.ItemCategory` + the item factory. Both reconstructed through `Generator.create_item` on load — fine for the items themselves, but bag *contents* fall outside that path.

## Research notes
- SPD reference (domain knowledge, code-corroborated): bags (VelvetPouch/ScrollHolder/PotionBandolier/MagicalHolster) auto-collect their category on pickup and expand inventory; MagicalHolster holds wands **and** missile weapons. Keys are depth-stamped: IronKey opens a locked door on its own floor, GoldenKey/CrystalKey open chests/special doors, SkeletonKey opens the boss-level lock. This port implements the per-item data but leaves bag auto-collect, bag-content persistence, and iron/skeleton unlock wiring unbuilt.
- Auto-fixed this run: removed the redundant `is_stackable()` override in `bag.gd` and `key.gd` (base `Item.is_stackable()` returns `stackable`, which both `_init()`s set to `false` → identical result). `is_upgradeable()` was left in place (base returns `true`, so those overrides are load-bearing).
