# Plants — Audit

- Files: `src/plants/plant.gd`, `src/plants/seed.gd`, and 12 plant subclasses
  (`blindweed, dreamfoil, earthroot, fadeleaf, firebloom, icecap, rotberry,
  sorrowmoss, starflower, stormvine, sungrass, swiftthistle`)
- Read in full: yes (all 14 `.gd` files)
- Verdict: **needs-hardening** — per-plant effects are clean and save/load is solid,
  but the system carries a fully-dead duplicate `Seed` class, applies one-shot buffs
  instead of SPD's spreading gases/Blobs, uses the wrong buff types for freeze/sleep,
  and has a grid edge-wrap bug in its two AoE plants.

## Improvements
- [P2] **`src/plants/seed.gd` (class `Seed`, 146 lines) is dead duplicate code.** The live
  seed is `SeedItem` (`src/items/seeds/seed_item.gd`), which has its own `PLANT_NAMES`,
  `_create_plant()`, `throw_at`-equivalent and the *correct* messages. `Seed` is referenced
  nowhere — repo-wide grep for the class name, its uid (`uid://dkcy06klubpej`) and its path
  all return zero external hits. It also carries a latent bug (see next) that never runs.
  → **delete** (auto-fixed this run). The Plant *subclasses* it lists are still live via `SeedItem`.
- [P2] **Broken format string in the (dead) `seed.gd:111-113`.** `MessageLog.add("The %s grows and " + "activates instantly!" % plant.plant_name)` — `%` binds tighter than `+`, so
  the format applies to the *second* literal (no placeholder) → runtime "not all arguments
  converted" and the `%s` is never filled. Moot because the file is dead (deleted); noted so
  the pattern isn't reintroduced. The live `SeedItem` has the correct one-line form.
- [P1] **Wrong buff types vs SPD.** `icecap.gd:36` and `dreamfoil.gd:35` apply `Paralysis`
  where dedicated buffs exist: `Frozen` (`src/actors/buffs/frozen.gd`) for freeze and
  `SleepBuff` (`src/actors/buffs/sleep_buff.gd`) for magical sleep. `Frozen` carries SPD
  mechanics (shatters frozen potions, breaks on damage) that generic `Paralysis` loses. Same
  family already flagged in S17 (Frost-bomb/Deepened-Sleep). → swap to `Frozen`/`SleepBuff`.
- [P2] **Grid edge-wrap in the two AoE plants.** `firebloom.gd:23-28` and `icecap.gd:23-26`
  iterate `ConstantsData.DIRS_8` as `pos + dir`, guarded only by `0 <= adj < Level.LEN`. At
  column 0 or WIDTH-1 the E/W/diagonal offsets (`±1`, `±WIDTH±1`) wrap onto the opposite edge
  row, so a freeze/burn near a wall can hit a cell across the map. `level.adjacent(pos, adj)`
  (`level.gd:634`, column-safe) already exists — gate each `adj` with it.
- [P2] **Dreamfoil cure IDs unverified.** `dreamfoil.gd:6-26` cures by string IDs
  (`"Blindness","Terror","Charm","Amok","Vertigo"`) via `has_buff(id)`/`remove_buff_by_id(id)`.
  If those don't exactly match each buff's runtime `id`, the cure silently no-ops. Verify
  against the S06 buff registry.

## Optimizations
- [P3] `icecap`/`firebloom` rebuild their adjacency list inline on every activation (tiny,
  8 iterations) — fine as-is; would fold into a shared `level.neighbours8(pos)` helper if one
  is extracted for S22.
- [P3] Deleting the dead `Seed` class removes a redundant global `class_name` and its 146-line
  parse cost at load.

## Additions
- [P1] **No Blob/gas spread.** SPD plants seed persistent Blobs: Firebloom→Fire, Sorrowmoss→
  ToxicGas, Stormvine→StormCloud, Icecap→Freezing. The Blob system exists
  (`src/actors/blobs/fire_blob.gd`, `toxic_gas.gd`, …) but plants apply a one-shot buff +
  terrain paint only, so effects don't linger or spread. Couples to S20 (Blobs); wire plant
  activation into blob seeding once S20 is evaluated.
- [P3] Missing SPD plant features: Rotberry bush regrowth/Wandmaker loop is stubbed to a quest
  flag (`rotberry.gd`), no `trample`/`wither` states, Blindweed lacks SPD's short root.
- [P3] No tests around the seed→plant factory (`SeedItem._create_plant`) or `_do_effect` buff
  application; a table-driven test would lock the 12 mappings + buff types.

## Save/load & coupling notes
- `Plant.serialize` writes `_script_path`/`type`/`pos`; `save_manager.gd:402/422` round-trips
  the `level.plants` dict by script path, and `_init` restores `plant_name`/`plant_id`. Solid.
- Coupling: `EventBus` (`plant_activated`, `seed_planted`, `quest_updated`, `hero_moved*`),
  `MessageLog`, `GameManager` (quest flags / focused hero), `Level` (terrain, `find_char_at`,
  `random_passable_cell`). All accessed defensively via `has_method`/`get`.
- The dead `Seed.serialize`/`deserialize` were never wired into save_manager — no migration risk
  from deletion.

## Research notes
- SPD reference: `Plant.java` / `Plant.Seed` — seeds grow on throw, activate instantly if a Char
  stands on target; Firebloom/Icecap/Sorrowmoss/Stormvine spawn Blobs (Fire/Freezing/ToxicGas/
  StormCloud); Dreamfoil = MagicalSleep on mobs + clears mind debuffs on hero; Swiftthistle =
  time-bubble/haste; Starflower = XP. Port matches the *what*, diverges on the *how* (buffs vs Blobs).
- Verified in-repo: `Frozen`/`SleepBuff` classes exist; Blob subclasses exist; `level.adjacent`
  is column-safe; `Seed` class + uid unreferenced (grep). No web search needed.
