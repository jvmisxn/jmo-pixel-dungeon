# Shattered Pixel Dungeon — Godot Clone

## Project Overview
A recreation of Shattered Pixel Dungeon in Godot 4.5 using GDScript. The project uses procedural sprite generation with SPD sprite sheet fallbacks, autoloaded singletons for game state, and a turn-based architecture.

## CRITICAL: File Integrity Rules

**DO NOT TRUNCATE FILES.** This project has suffered repeated breakage from AI agents writing partial files. Follow these rules absolutely:

1. **Always read the ENTIRE file before editing it.** If a file is longer than your read window, read it in chunks until you reach the end. Never assume the file ends where your read stopped.

2. **Never use Write to replace a file unless you include ALL of its content.** Prefer the Edit tool for targeted changes. The Edit tool only modifies the specific string you target and leaves everything else intact.

3. **Never leave `pass # truncated` or similar placeholders.** Every function must have a complete, working implementation. If you cannot finish a function, do not create it at all.

4. **After editing, verify the file is complete.** Read the last 20 lines of any file you modified to confirm it ends properly (not mid-function, not with a truncation marker).

5. **Do not rewrite files that are working.** If a file has no errors, do not touch it. Focus changes only on the specific code that needs modification.

6. **When adding a new function, use Edit to append it** — do not rewrite the entire file.

## Architecture

- `src/autoloads/` — Singletons (ConstantsData, GameManager, TurnManager, EventBus, AudioManager, MessageLog, QuestHandler)
- `src/scenes/` — Scene scripts (MainScene, GameScene, TitleScene, LoadingScene, DeathScene, VictoryScene, GameCamera)
- `src/sprites/` — CharSprite (base), HeroSprite, MobSprite, ItemSprite
- `src/tiles/` — TileMapManager, FogOfWar, TerrainVisuals
- `src/effects/` — EffectManager, DamageNumber, ParticleBurst, LightningEffect, ProjectileEffect
- `src/levels/` — Level (base), RegularLevel, room types, painters, level factory
- `src/actors/` — Hero, Mob subclasses, buffs
- `src/items/` — Weapons, armor, wands, potions, scrolls, etc.
- `src/ui/` — HUD, inventory windows, toolbar

## Key Conventions

- All GDScript uses static typing (e.g., `var x: int = 0`, `func foo() -> void:`)
- Classes use `class_name` for global registration
- Terrain textures: use `TerrainVisuals.get_texture(terrain, region)` — NOT `get_terrain_texture`
- Cell position conversion: `ConstantsData.pos_to_x(pos)`, `ConstantsData.pos_to_y(pos)`, `ConstantsData.xy_to_pos(x, y)`
- Direction constants: `ConstantsData.DIRS_4`, `ConstantsData.DIRS_8`, `ConstantsData.DIR_N/S/E/W/NE/NW/SE/SW`
- Map dimensions: `ConstantsData.WIDTH`, `ConstantsData.HEIGHT`, `ConstantsData.LENGTH`

## Testing

To verify the game launches: Open in Godot 4.5, press F5 (or Run). The main scene is `res://src/scenes/main_scene.gd`. If you see "Could not parse global class X", it means file X or one of its dependencies has a syntax error — check the dependency chain.
