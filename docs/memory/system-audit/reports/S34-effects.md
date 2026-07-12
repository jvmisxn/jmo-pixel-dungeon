# Effects — Audit

- Files: `src/effects/effect_manager.gd`, `damage_number.gd`, `lightning_effect.gd`,
  `particle_burst.gd`, `projectile_effect.gd`
- Read in full: yes (all 5). `lightning_effect.gd` is in `TRUNCATED_FILES.txt` (flagged, not edited).
- Verdict: **healthy** — clean, correctly transient view layer; only coupling/consistency polish.

## Improvements
- [P2] `EffectManager._cell_to_world` (`effect_manager.gd:135`) is a **third hand-rolled copy**
  of cell→pixel-center, hardcoding the literal `16` tile size — duplicating
  `TileMapManager.cell_to_world` (`tile_map_manager.gd:114`, uses `TILE_SIZE`) and
  `CharSprite._cell_to_world` (`char_sprite.gd:524`). Formulas are identical today so there is no
  live misalignment, but a tile-size change would silently drift effects off sprites. — Route all
  three through one source of truth (a shared `TileMapManager.TILE_SIZE` const, or delegate to
  `tile_map.cell_to_world`).
- [P2] `EffectManager.screen_flash` (`effect_manager.gd:118`) bypasses the pool discipline every
  other spawn method honors: it neither checks `MAX_EFFECTS` nor increments `_active_effects`.
  Only one caller today (retribution, `game_scene.gd:2286`), so low live risk, but a rapid
  retribution loop can stack unbounded full-viewport `ColorRect`s. — Count it like the others, or
  reuse a single persistent flash rect.
- [P3] `LightningEffect._toggle_flash` (`lightning_effect.gd:57`) calls `_generate_segments()` on
  every visible flash (2×/bolt), re-randomizing the whole bolt each toggle. Cosmetic/negligible at
  the 50-effect cap, but redundant allocation. File is truncated — backlog only, do not edit.

## Optimizations
- [P3] `ParticleBurst`/`ProjectileEffect` drive per-frame `_process` + `queue_redraw`. Fine under
  the `MAX_EFFECTS=50` cap; no change needed. Note for the record that `DamageNumber`/ring/lightning
  already moved to Tween-driven animation — the two remaining `_process` effects are the outliers if
  a future pass wants uniform Tween-based motion.

## Additions
- [P3] No SPD-parity emitters: SPD fires `Splash`/blood on melee hit, `Wound`, `Speck` variants, and
  `MagicMissile` typed bolts; this port has a generic projectile/particle/lightning set. Functionally
  adequate; a future polish pass could add hit-splash + typed wand bolts. (SPD ref:
  `com.watabou.pixeldungeon` `Emitter`/`Splash`/`MagicMissile`.)
- [P3] No tests over the geometry helpers (`_cell_to_world`, `_generate_segments`,
  projectile `t` clamping). A tiny pure-function test would lock the cell→world contract shared with
  sprites/tilemap.

## Save/load & coupling notes
- View-only and correctly transient: no effect class is ever serialized; `EffectManager` is
  instantiated per-`GameScene` (`game_scene.gd:857`) and rebuilt each run. Good separation.
- All spawns originate from the view/coordinator layer (`game_scene.gd`, `scene_visual_coordinator`,
  `scene_feedback_coordinator`, `environment_feedback_coordinator`, `online_event_codec`), never from
  game-logic actors — the correct direction. Only coupling debt is the duplicated `_cell_to_world`.

## Research notes
- SPD effect layer (`Emitter`, `Splash`, `MagicMissile`, `Lightning`, `FloatingText`) is a
  sprite/particle-sheet system; this port reimplements equivalents procedurally via
  `draw_line`/`draw_circle`/Tween — a reasonable, self-contained choice.
- Auto-fixed this run: 2 gdlint `max-line-length` violations (signature wraps), behavior-neutral.
