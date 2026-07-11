# Item base & Generator — Audit

- Files: `src/items/item.gd` (318), `src/items/generator.gd` (806, TRUNCATED), `src/items/heap.gd` (132)
- Read in full: yes (all three)
- Verdict: **needs-hardening** — factory chokepoint and core item contract are clean, but stack-splitting silently downgrades typed items to base `Item`, and a few persistence/fidelity gaps in Generator.

## Improvements
- [P1] **`Item.split()` loses the subclass on any stackable that doesn't override `duplicate_item()`.** `split()` → `duplicate_item()` (`item.gd:145,154`) and the base impl returns `Item.new()`. Only `potion`, `scroll`, `gold`, `armor` override it. Every *stackable* type WITHOUT an override — `missile_weapon`, `seed_item`, `bomb`, `stone`, `food`, `spell`, `dewdrop`, `torch` — splits into a generic `Item` that has lost its throw/use behavior and subclass state. Reachable in normal play: bandit/thief theft (`bandit.gd:59`, `thief.gd:48`) `split(1)` from a stack, and recycle (`spell.gd:373`, `game_scene.gd:1622`). A stolen-then-dropped throwing knife becomes a dead pickup. **Fix:** make base `duplicate_item()` reconstruct via the factory — `var copy := Generator.create_item(item_id); _copy_base_properties(copy)` — so every subclass round-trips; existing overrides then only need to copy their *extra* fields onto the factory-built instance.
- [P2] **`Item.serialize()` drops `bones` and `kept_though_lost_invent`** (`item.gd:287-301`). `default_action`/`str_requirement`/`icon_color` are also omitted but are restored by the factory on load; `bones` and the ankh "kept through lost inventory" flag are *not* re-derived by the factory, so a mid-run save silently clears them. Add both to serialize/deserialize.
- [P2] **Two sources of truth for identification.** There is a stored `identified` bool *and* a computed `is_identified()` (= `level_known and cursed_known`, `item.gd:184`). They can desync: an item whose level+curse become known without `identify()` being called reads `is_identified()==true` but serializes `identified=false`. Collapse to the computed form (persist `level_known`/`cursed_known` only; treat `identified` as derived).

## Optimizations
- [P2] **`_generated_artifacts` is process-global static state, unsynced with saves** (`generator.gd:183`). Not serialized: a mid-run save/load resets the set, so an already-found artifact can regenerate as a duplicate; and it relies on `reset_artifacts()` being called at new-run start. Persist the set in the save (or key uniqueness off the actual inventory/catalog). (TRUNCATED file — manual.)
- [P3] `_weighted_category()` re-sums `CATEGORY_WEIGHTS.values()` on every call (`generator.gd:399`); the total is constant — precompute once. Same pattern in `_weighted_random_from_table`. Micro; loot rolls aren't hot. (TRUNCATED file.)
- [P3] `random_wand()` keeps a manual `+n`/curse fallback branch (`generator.gd:495-503`) that only runs if `Wand.random()` is missing — it always exists, so the branch is dead. (TRUNCATED file.)

## Additions
- [P2] **Gold is in the random-item category table.** `CATEGORY_WEIGHTS` lists `GOLD:16` — the single highest weight (`generator.gd:16`), so ~30% of `random_item()` results are gold piles. In SPD `Generator.Category` never yields gold; gold is placed separately by level generation. This skews non-gold loot density. Remove `GOLD` (and the fallback-only `MISC`) from the item category table and drive gold from level gen. (TRUNCATED file — manual.)
- [P2] **`Heap` has no type-specific serialized state** (`heap.gd:106`). Fine while heaps are pure item lists, but TOMB (wraith-on-disturb), LOCKED/CRYSTAL chests (key linkage), and SKELETON (crumble damage) will need persisted flags — flag now so the save schema is extended alongside those behaviors, not after.
- [P3] No unit coverage for the item contract's pure paths: `split`/`merge_stack`/`can_stack_with` round-trips and `serialize`→`Generator.create_item`→`deserialize` fidelity. These are the cleanest first framework-extraction test targets in the item system.

## Save/load & coupling notes
- Persistence uses a factory-reconstruct pattern: `heap.deserialize` → `Generator.create_item(item_id)` → `item.deserialize(dict)` (`heap.gd:120-132`), with base `Item` fallback when `item_id==""`. Solid for core fields; subclasses must own their extra state in their own serialize/deserialize.
- `Item` autoload coupling (EventBus, GameManager, ItemCatalog, ItemAppearance) is all truthiness-guarded (`if EventBus:` etc.) — good, no hard crashes if an autoload is absent.
- `Generator.create_item` is the single factory chokepoint for the whole item system (good). Its dispatch uses explicit known-ID sets to avoid false-positive factory matches (good). The one soft spot is the static mutable `_generated_artifacts`, which lives outside the save graph.

## Research notes
- SPD `Generator.java`: the `Category` enum used by `random()` covers potions/scrolls/wands/rings/artifacts/food/weapons/armor/etc. — **not gold**; gold placement is a separate `RegularLevel` concern. Confirms the [P2] gold-in-category finding.
- SPD `Item.split(int)` clones via `Reflection.newInstance(getClass())` then copies fields, so the split half keeps its concrete class. The GDScript port's per-subclass `duplicate_item()` override pattern is the equivalent, but the base default silently downgrades types that forgot to override — hence the [P1] factory-reconstruct recommendation.
