# Sprites — Audit

- Files: `src/sprites/char_sprite.gd` (528), `hero_sprite.gd` (329), `mob_sprite.gd` (364), `item_sprite.gd` (382), `plant_sprite.gd` (121)
- Read in full: yes (all 5)
- Verdict: **needs-hardening** — the view layer is clean, correctly transient (never serialized), and SPD-faithful in structure, but a whole designed subsystem (`VisualState` buff feedback) plus several SPD animation hooks (`die`/`fall`/`jump`/`zap`/`turn_to`/`read`) are wired to **no caller** → buffs and special moves produce no sprite feedback.

## Improvements
- [P1] **`VisualState` system is entirely dead.** `CharSprite.add_visual_state()` / `remove_visual_state()` / `has_visual_state()` and the enum (`BURNING, FROZEN, INVISIBLE, PARALYSED, CHILLED, MARKED, HEALING, SHIELDED, …`) + `_process_state_addition/removal` (char_sprite.gd:280-334) have **zero callers** in the repo (`rg add_visual_state` outside sprites = 0). SPD drives these every turn via `Char.updateSpriteState()`. Result: Frozen shows no ice tint, Invisible no fade, Burning no fire tint, etc. — ~55 lines of built-but-unplugged feedback. Direction: add a `Char.update_sprite_state()` (see Additions) called on buff add/remove + per turn.
- [P2] **`MobSprite.die()` and `MobSprite.fall()` overrides are dead.** Mob death is driven through `SceneVisualCoordinator` calling the generic `play_death()` (0.5s), never `die()` (`FADE_TIME` 3.0s) or `fall()` (pit spin+shrink) (mob_sprite.gd:237-252). So SPD's slow mob dissolve and pitfall/chasm fall animation never play — dead mobs pop out in 0.5s and chasm-ejected mobs just `queue_free`.
- [P2] **Animation hooks unwired.** `jump()` (Heroic Leap / Pitfall landing / teleport arc, char_sprite.gd:233), `play_zap()` (wand use, :226), `turn_to()` (:268), `HeroSprite.read()` (scroll, :108) and `sprint()` (pure `pass` stub, :102) have no gameplay callers — wands/scrolls/leaps fall back to the generic attack/operate lunge or no animation at all. `blood_burst_a()` is an intentional hero no-op but there is no blood system for mobs either (only `flash`).

## Optimizations
- [P2] **No procedural-texture cache in Char/MobSprite.** `ItemSprite` caches generated 16×16 textures by `category:color` (item_sprite.gd:19,143-149), but every mob spawn rebuilds its `Image`+`ImageTexture` from scratch in `_generate_sprite()` even though `MOB_VISUALS`/shape drawing is deterministic per `mob_id`. A `mob_id`-keyed static cache (mirroring ItemSprite) removes per-spawn allocation. (Only hit when a sheet fails to load, so low real-world impact while all SPD sheets are present.)
- [P3] **`_process(delta)` polls every frame on every CharSprite** for sleep/emote bob even when not sleeping and no emote active (char_sprite.gd:98-108). Could be `set_process(false)` unless sleeping/emoting — O(mobs) per frame saved.

## Additions
- [P2] **Sprite-state driver hook.** Add `Char.update_sprite_state()` (call sites: buff `attach`/`detach`, turn tick) that maps active buffs → `add/remove_visual_state`. This is the missing plug for the P1 finding and a clean framework-extraction seam (view stays passive; model pushes state).
- [P3] **Unit tests for pure mapping math** — `_cell_to_world()`, `place_at()` cell→pixel, and `sprite_index → (col,row)` region math (item_sprite.gd:132-136, plant_sprite.gd:109-115) are pure and trivially testable; would guard the 16px grid contract.
- [P3] Removed orphaned tracked `.fuse_hidden0000000700000002` artifact in `src/sprites/` (see auto-fix).

## Save/load & coupling notes
- Sprites are **pure view**: not serialized (correct). Re-created from the model each load via `game_scene._spawn_hero/mob/item_sprites()`; `hero.sprite` / `mob.sprite` are transient runtime refs. No persistence risk. Good separation.
- Coupling: sprites depend only on `ConstantsData` (grid math, categories, hero classes) and `res://assets/spd/sprites/*` — no autoload state. `HeroSprite.update_armor(tier)` **is** correctly wired to equipped-armor tier via `game_scene._apply_hero_equipment_visuals()` (game_scene.gd:742-753), matching SPD's tiered hero sheets.

## Research notes
- SPD `CharSprite.State` (BURNING/FROZEN/INVISIBLE/PARALYSED/CHILLED/MARKED/…) is synced by `Char.updateSpriteState()` every act — this port ported the *enum and handlers* but not the *driver*, which is the root of the P1 gap.
- SPD `MobSprite.die()` uses a multi-second alpha fade and `fall()` a pit spin; the port faithfully reproduced both but routes death through the generic `CharSprite.play_death()` instead.
- `game_scene.gd`, `char_sprite.gd`, `item_sprite.gd`, `mob_sprite.gd` are in `TRUNCATED_FILES.txt` → all behavioral fixes above are backlog-only; only the non-code fuse artifact was auto-removed.
