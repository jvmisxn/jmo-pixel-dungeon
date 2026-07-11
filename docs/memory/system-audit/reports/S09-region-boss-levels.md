# Region & boss levels — Audit

- Files: `src/levels/{sewer,prison,caves,city,halls}_level.gd`, `src/levels/{sewer,prison,caves,city,halls}_boss_level.gd`, `src/levels/last_level.gd`, `src/levels/level_factory.gd` (RegularLevel/Level base read as context, owned by S07)
- Read in full: yes (all 11 subclass files + level_factory.gd; cross-referenced level.gd base contract, boss `_on_death` hooks, constants passability)
- Verdict: **needs-hardening** — depth→class routing and the boss seal/unlock loop are correct and faithful, but the final region (Halls) silently loses its whole trap tier, boss arenas have zero traversability validation, and two boss arenas can eject the hero mid-fight via chasm knockback.

## How the system fits together (verified)
- `LevelFactory.instantiate_for_depth()` maps boss depths 5/10/15/20/25 → the five `*BossLevel` arenas, 26 → `LastLevel`, everything else → region level by `region_for_depth()`. Correct SPD `Dungeon.newLevel()` shape.
- Region levels extend `RegularLevel`; its `_build()` runs feeling → rooms → painting → **traversability check (`find_path(entrance, exit_pos)`, `regular_level.gd:75`)** → mob/item population (`:79-109`). The factory retries generation up to 6× on failure (`level_factory.gd:11`).
- Boss/Last levels extend `Level` **directly** and hand-author `_build()`. They therefore skip RegularLevel's mob/item population — arenas contain only the boss (correct; SPD boss floors don't spawn ambient mobs/items, the reward is the boss drop).
- Seal/unlock is real and wired: each boss's `_on_death` calls `level.unlock_exit()` (`goo/tengu/dm300/king/yog.gd`), which flips every `LOCKED_DOOR`→`OPEN_DOOR` (`level.gd:624`). The pre-kill `LOCKED_DOOR` in the exit corridor is the seal (impassable per `constants.gd:106`). This half works correctly.

## Improvements
- [P1] **HallsLevel has no `_create_random_trap()` override** (`halls_level.gd` ends at line 47 with no trap fn) → depth 21–24 falls back to `RegularLevel._create_random_trap()` (`regular_level.gd:327`), which returns only tier-1 traps: WornDart/Poison/Fire/Alarm/Teleport. The final region should use its lethal pool (GrimTrap, DisintegrationTrap, RockfallTrap, PitfallTrap, DistortionTrap, StormTrap). Every other region (sewer/prison/caves/city) overrides this; Halls is the lone omission — a real difficulty/fidelity regression. *Fix: add a Halls trap override (blocked from auto-fix: `halls_level.gd` is in TRUNCATED_FILES.txt).*
- [P2] **Boss/Last `_build()` never validates traversability and always `return true`.** RegularLevel guards entrance→exit reachability and the factory retries; boss arenas get neither. A magic-number slip (arena bounds, corridor offset) would silently ship an unreachable boss or entrance and softlock the run with no fallback. *Add an `assert`/path check on entrance→boss-pos before returning.*
- [P2] **HallsBossLevel & LastLevel ring the walkable arena with CHASM adjacent to floor** (`halls_boss_level.gd:24,36`, `last_level.gd:31`). CHASM drops the stepper to the next depth. Yog/Yog-fists and other Halls knockback can shove the hero (or a mob) off the edge mid-fight, breaking the encounter — the hero can fall to depth 26 without killing Yog. SPD's Yog arena is not a chasm-ring you can be knocked into. *Either move the seal below the chasm or make the ring non-fall décor.*
- [P2] **HallsLevel view-distance reduction is an unimplemented TODO** (`halls_level.gd:9-10`). SPD Halls does `viewDistance = min(26-depth, viewDistance)` (darker, tenser floors). Needs a per-level `view_distance` field on `Level`. Tracked but inert.

## Optimizations
- [P3] `unlock_exit()` scans all `LEN` cells (`level.gd:627`) on every boss death. Trivial one-shot cost, but it also opens *any* other LOCKED_DOOR on the floor (vault/armory) — harmless on boss floors (none exist) but a latent coupling if arenas ever gain locked vaults. Prefer unlocking a tracked `sealed_doors` list.
- [P3] Region `_roll_feeling()` mutates `num_standard_rooms += 2` in place for LARGE (`caves_level.gd:17`, `city_level.gd:15`, `halls_level.gd:21`). Safe today (factory builds a fresh instance per attempt), but the in-place mutation is a footgun if an instance is ever regenerated.

## Additions
- [P2] **Framework extraction: a shared `BossArenaLevel` base.** All five boss `_build()`s repeat the same scaffold (init arrays → carve arena → entrance corridor → exit corridor → `LOCKED_DOOR` seal → `build_flag_maps()` → `MobFactory.create_boss(depth)` → `add_mob`). Extract `_carve_arena()`, `_place_entrance_exit()`, `_seal_exit()`, `_spawn_boss()` helpers to kill ~5× duplication and give the traversability-validation fix a single home.
- [P3] No tests for `LevelFactory.create_for_depth()` depth→class mapping or the boss-death→`unlock_exit` flow — both are pure/near-pure and cheap to cover.
- [P3] Boss arenas hardcode bounds (4..27, radii 11/5) assuming a 32-wide map; nothing ties them to `ConstantsData.WIDTH/HEIGHT`. Derive/assert against constants so a map-size change can't silently write out of bounds.

## Save/load & coupling notes
- Boss levels carry no extra persisted state beyond the base `Level` map/entrance/exit — the seal is encoded purely in terrain (`LOCKED_DOOR` vs `OPEN_DOOR`), so save/load after a boss dies correctly preserves the opened exit. Good.
- `goo.gd` has a `floor_sealed` field (`:12`) that is **written nowhere and read nowhere** — dead groundwork. The actual seal relies entirely on terrain, and nothing prevents the hero from *ascending* back up the entrance to escape a live boss (SPD seals both directions). Flagging as a coupling gap, not auto-fixing (goo.gd not in scope S09 / is a boss file).
- Coupling: bosses reach into `level.unlock_exit()` via `has_method` duck-typing (fine, decoupled). Region levels depend on many Room subclasses + Trap subclasses by direct `new()` — acceptable.

## Research notes
- SPD trap tiers confirmed via Pixel Dungeon Wiki / SPD "Better Traps" devblog: Grim/Disintegration/Rockfall/Pitfall/Distortion are the high-tier destructive traps that belong in Caves/City/Halls; Halls is the lethal end. City already wires Grim/Guardian/Warping/Summoning/Flashing correctly — Halls is the gap.
- Boss floor sealing in SPD (`Level.seal()/unseal()`) blocks both stairs until the boss dies; our port only blocks the *down* exit via terrain, leaving ascent open. Noted as a fidelity gap for a later pass.
- Sources: Pixel Dungeon Wiki — Shattered Pixel Dungeon/Traps; shatteredpixel.com "Coming Soon to Shattered: Better Traps".
