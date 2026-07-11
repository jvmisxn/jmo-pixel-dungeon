# Movement / pathfinding / FOV — Audit

- Files: `src/mechanics/pathfinder.gd`, `src/mechanics/ballistica.gd`, `src/mechanics/shadow_caster.gd`, `src/mechanics/auto_walk_coordinator.gd`
- Read in full: yes (all four). Cross-read `src/levels/level.gd` pathing/FOV wrappers (`_build_astar`, `find_path`, `point_visible`, ShadowCaster call sites).
- Verdict: **needs-hardening** — Ballistica/ShadowCaster faithful and live; the hand-written `Pathfinder` A* is almost entirely dead code (runtime pathing is Godot `AStar2D`), a real duplication/divergence risk.

## Improvements
- [P2] **`Pathfinder`'s entire A* is dead code.** Runtime pathing goes through Godot's `AStar2D` in `level.gd:659` (`find_path`) / `find_step`, built by `_build_astar` (`level.gd:130`). The only live `Pathfinder` symbol anywhere is `get_neighbors` (`level.gd:653`). `Pathfinder.find_path/find_step/build_distance_map/distance/manhattan` and every internal helper (`_heuristic/_reconstruct/_step_cost/_diagonal_passable`) have **zero callers** (verified repo-wide `rg`). Two independent pathfinding implementations that can silently drift — e.g. the A* corner-cutting rule (`pathfinder.gd:194`) is duplicated in `_build_astar` (`level.gd:157`); a fix to one won't reach the other. Direction: either delete the dead A* (keep only `get_neighbors` + the distance helpers if wanted) or make `level.find_path` delegate to it so there's a single source of truth. `pathfinder.gd` is in `TRUNCATED_FILES.txt` → backlog, do not auto-edit.
- [P2] **`Pathfinder.build_distance_map` is a queue-relaxation (SPFA) flood, not the SPD model.** It re-enqueues on every improvement with non-uniform step costs (1.0 / √2). It converges to correct distances but can revisit cells many times; SPD's `PathFinder.buildDistanceMap` is a uniform-cost BFS producing integer step counts. Since it's currently uncalled this is latent, but if ever wired up it diverges from SPD ranged/targeting distance semantics. Backlog (truncated file).
- [P3] **ShadowCaster `origin / width` (`shadow_caster.gd:58`) lacks the `@warning_ignore("integer_division")` annotation** the rest of the codebase uses (cf. `level.gd:136`, `pathfinder.gd:126`). Cosmetic Godot-editor warning only; consistency fix.
- [P3] **`Ballistica.IGNORE_SOFT_SOLID` is effectively inert** — `_is_soft_solid_terrain` only ever returns true for DOOR/WEB *when a terrain array is passed*, and the header comment (`ballistica.gd:113-116`) admits `avoid[]` isn't implemented. Only `wand.gd:129` passes terrain; artifact/hero LOS casts pass none, so soft-solid handling is silently a no-op for them. Low impact today; note for when `avoid[]` lands.

## Optimizations
- [P2] **`Pathfinder.find_path` open set is an O(n) linear-scan min-heap with lazy duplicates** (`pathfinder.gd:36-43,70`) → O(n²) worst case. Moot while dead, but a reason to delete rather than keep-and-maintain.
- [P3] **`auto_walk_coordinator.get_visible_mob_positions` keys the dict by cell position, not mob identity** (`auto_walk_coordinator.gd:73`). A known mob merely *moving* drops its old key and adds a new one, which the "new mob appeared" check (`:34-37`) treats as a fresh threat → auto-walk cancels. Over-cautious but safe (fails toward stopping); fine to leave.
- [P3] **Three separate `if scene._current_level:` guards** in `process_step` (`auto_walk_coordinator.gd:38,43,48`) could collapse into one block. Pure readability; behavioral-neutral but needs judgment → not auto-fixed.

## Additions
- [P2] **No unit tests for the geometry core.** `Pathfinder`, `Ballistica`, and `ShadowCaster` are pure, static, engine-independent (flat-array in → array out) — ideal for GUT tests: known-grid path length, Ballistica collision index vs. wall, FOV circle radius/symmetry, diagonal corner-cut rejection. High value given how much combat/wand/AI logic rides on them.
- [P3] **Framework-extraction hook:** these three files are already dependency-free (only `ConstantsData` in Ballistica). Good candidates to lift into a reusable `jmo`-style grid-geometry module later.

## Save/load & coupling notes
- All four are stateless/static (RefCounted utilities); nothing here is serialized, so no save/load risk. `ShadowCaster` holds a static precomputed `_rounding` table (`shadow_caster.gd:16`) initialized lazily — process-global, fine.
- Coupling: `Ballistica` → `ConstantsData` (Terrain/WIDTH). `AutoWalkCoordinator` is heavily coupled to `game_scene` internals via duck-typed `scene._auto_walk_*` fields and `_submit_hero_action` (`:58`) — acceptable for a coordinator but untestable in isolation. `Pathfinder`/`ShadowCaster` have no autoload deps.
- Live vs. dead: FOV = ShadowCaster (live, `level.gd:280,606`); projectile/LOS = Ballistica (live, wands/artifacts/hero); pathing = `AStar2D` (live) with `Pathfinder` A* dead (only `get_neighbors` live).

## Research notes
- SPD `com.watabou.utils.PathFinder` uses a uniform-cost BFS `buildDistanceMap` producing integer step counts with `Integer.MAX_VALUE` for unreachable cells, and `getStep`/`getStepBack` read that distance array — it is not A*. This port instead delegates runtime pathing to Godot `AStar2D` and left a separate A* `Pathfinder` unused, hence the divergence flag. (SPD AI/pathfinding overview: DeepWiki "AI and Mob Behavior"; PathFinder in `com.watabou.utils`.)
- `Ballistica` DDA + STOP_* flag model (`PROJECTILE`/`MAGIC_BOLT` pass-through) matches SPD `Ballistica.java` intent; `ShadowCaster` recursive 8-octant shadowcasting with the rounding table and 0.499 leak-guard is a faithful port of SPD `ShadowCaster.java`.
