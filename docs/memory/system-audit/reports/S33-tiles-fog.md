# Tiles & fog — Audit

- Files: `src/tiles/fog_of_war.gd`, `src/tiles/fog_of_war.gdshader`, `src/tiles/spd_tileset.gd`, `src/tiles/terrain_visuals.gd`, `src/tiles/tile_map_manager.gd`
- Read in full: yes (all four .gd + the shader). `terrain_visuals.gd` and `tile_map_manager.gd` are in `TRUNCATED_FILES.txt` → read-only, no auto-fix.
- Verdict: **needs-hardening** — the render path itself (TileMapLayer batching + GPU fog shader) is clean, correct and SPD-faithful, but `terrain_visuals.gd` is ~70% dead code and `TileMapManager` reaches into a private dict inside it. No correctness/data-loss bugs (view layer, never serialized).

## Improvements
- [P2] `TileMapManager` couples to `TerrainVisuals._terrain_to_tile` — a private-by-convention dict — as its only live use of that class (`tile_map_manager.gd:242`). The class's entire *public* API is dead (see below) while the one thing actually needed is underscore-private. Direction: expose a public `TerrainVisuals.terrain_tile_index(terrain)` accessor, or move the terrain→tile-index map onto `SPDTileset`/`TileMapManager` and retire the rest of `TerrainVisuals`.
- [P3] `FogOfWar` writes a 1-cell UNSEEN (black, α=1) border into the data image but never mirrors real edge cells into it; with `TEXTURE_FILTER_LINEAR` + `repeat_disable`, visible cells on the map boundary bilinear-fade toward that black border → a faint dark halo at level edges (`fog_of_war.gd:124-127,145-147`). Cosmetic; clamp/replicate edge state into the border if it ever shows.
- [P3] `FogOfWar.set_dark()` runtime setter is dead — DARK feeling is only ever applied once via `setup(is_dark)` (`game_scene.gd:439-440`). Fine while feeling is fixed at level creation; note if feeling ever mutates mid-level.

## Optimizations
- [P2] **~180 of 265 lines of `terrain_visuals.gd` are dead.** Repo-wide grep shows *no* external caller of `TerrainVisuals.*` at all; `TileMapManager` uses only `_terrain_to_tile` (field) and `clear_cache()`. Orphaned: `get_texture`, `_load_tile`, `_create_fallback`, `get_palette`, `get_stitched_water_tile`, `get_water_bg_texture`, plus the `_palettes`, `_water_region_file`, `_water_cache` tables. The live renderer builds its tileset straight from the SPD sheet (`tile_map_manager.gd:135-162`), so this whole texture-loading/fallback/palette apparatus never runs. Truncated file → backlog only, no auto-fix.
- [P2] The water-background path table + center-crop logic is duplicated: `TileMapManager._get_water_bg_image_texture` (`tile_map_manager.gd:166-187`) re-declares the same region→PNG dict and 32→16 crop that dead `TerrainVisuals.get_water_bg_texture` / `_water_region_file` already hold. Collapse to one source when the dead half is removed.
- [P3] `FogOfWar.reveal_all()` (`fog_of_war.gd:103-109`) is a dead duplicate — magic mapping runs through `Level.reveal_all()` (scroll.gd:439, artifact reveal_all_secrets); grep finds zero callers of the fog method.
- [P3] `render_changed()` enqueues water neighbors via `DIRS_4` without a row-wrap guard (`tile_map_manager.gd:76-80`): DIR_E/DIR_W at column 0/31 pull the wrapped cell from the adjacent row, and a shared neighbor can be appended twice → redundant `_update_tile` calls. Harmless (recompute is correct) but pure waste; guard the row edge and dedup.

## Additions
- [P2] No unit tests for the two pure, deterministic functions in this system — `_compute_water_edge_mask` (`tile_map_manager.gd:259-280`) and the fog state-selection in `_set_fog_pixel` (`fog_of_war.gd:157-171`). Both are cheap, allocation-free, and ideal regression anchors before any tile-index refactor.
- [P3] Fog is a hard 3-state (unseen/visited/visible) with shader distance fade; SPD additionally runs a per-tile discover reveal animation. Optional polish, not parity-critical.

## Save/load & coupling notes
- Correctly transient: nothing in `src/tiles/` is serialized. Fog reads `level.visible/visited/mapped`; tiles read `level.map`. State of record lives on `Level`; the tile/fog layer is a pure view rebuilt on `setup`. This is the right boundary.
- Autoload deps: `ConstantsData` (geometry/enums), `GameManager` (local-hero lookup, MP-aware via `get_local_hero`). No hard singleton coupling beyond that.
- Coupling smell: the only cross-file link between `TileMapManager` and `TerrainVisuals` is the private `_terrain_to_tile` field; the intended public surface is entirely unused (see P2).

## Research notes
- SPD water stitching (`DungeonTileSheet`): a 16-variant water block indexed by a 4-bit mask, bit set per side where the neighbor is **non-water** (a shore edge). `_compute_water_edge_mask` matches this exactly (N=1/E=2/S=4/W=8 when the neighbor is not WATER) and `tile_index = SPDTileset.WATER(32) + mask`, with slots 32–47 reserved before `FLAT_WALL=48` — 16 variants, consistent. Judged faithful, not a bug. Web search for the exact `stitchWaterTile` source was inconclusive; conclusion rests on the tilesheet layout + code reasoning.
- Fog architecture (GDScript writes a 1px/cell R8 data texture, shader does torch-light distance falloff on the GPU) is a sound Godot 4.5 pattern and keeps per-turn CPU work to two `Array` diffs + changed-cell pixel writes.
