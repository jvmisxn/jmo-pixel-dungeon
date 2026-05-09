# Shattered Pixel Dungeon for Godot

A Godot 4.5 port of **Shattered Pixel Dungeon**, built in GDScript.

The project is already **playable** and has broad coverage across dungeon generation, combat, items, mobs, UI, quests, and progression. The current goal for **0.1.1** is to keep closing parity gaps, harden save/load and quest behavior, and make the codebase a safer base for future customization.

## Status

- Current milestone: `0.1.1`
- Engine: `Godot 4.5`
- Language: `GDScript`
- Main scene: `res://src/scenes/main_scene.tscn`
- Project state: playable port, still being hardened

This is not yet a clean reusable framework, but that is the longer-term direction after the port is more stable.

## Project Goals

- Port Shattered Pixel Dungeon gameplay and content into Godot
- Preserve the feel of SPD where practical
- Improve the codebase until it is safe to customize heavily
- Eventually use the dungeon/combat/item framework as a foundation for other games

## Current Feature Coverage

The project already includes substantial working systems, including:

- procedural dungeon generation
- turn-based hero and mob actions
- melee and ranged combat
- inventory, equipment, quickslots, shops, and alchemy
- item identification/discovery systems
- many quests, NPCs, traps, artifacts, wands, and consumables
- journal/catalog and progression tracking
- SPD sprite-sheet integration across much of the game

Some systems are still being hardened or brought closer to original SPD behavior, especially around persistence, special-case AI, and long-tail content interactions.

## Running The Project

1. Install `Godot 4.5`.
2. Open this folder as a project.
3. Run the project with `F5`.

The configured startup scene is `res://src/scenes/main_scene.tscn`.

## Repository Layout

- [src](</E:/GitHub/jmo-pixel-dungeon/src>)  
  Game code: actors, items, levels, UI, scenes, autoloads, rendering
- [assets](</E:/GitHub/jmo-pixel-dungeon/assets>)  
  Art, sprites, audio, and related content
- [docs/memory](</E:/GitHub/jmo-pixel-dungeon/docs/memory>)  
  Lightweight project memory, decisions, backlog, and recent change summaries
- [docs/history](</E:/GitHub/jmo-pixel-dungeon/docs/history>)  
  Archived larger historical notes and audits
- [scripts](</E:/GitHub/jmo-pixel-dungeon/scripts>)  
  Small helper scripts for repo workflows

## Architecture Notes

The project currently uses several autoload singletons for shared state and orchestration, including:

- `Constants`
- `EventBus`
- `GameManager`
- `TurnManager`
- `SaveManager`
- `AudioManager`
- `MessageLog`
- discovery/item catalog systems

That architecture is functional for the port, but still tighter-coupled than the eventual framework target.

## Contribution Notes

The most useful work right now is usually in one of these areas:

- parity fixes against original SPD behavior
- save/load hardening
- quest and NPC edge-case fixes
- special mob and boss behavior
- UI/HUD polish
- asset-fidelity cleanup

If you are working in the codebase, start with:

- [docs/memory/active-context.md](</E:/GitHub/jmo-pixel-dungeon/docs/memory/active-context.md>)
- [docs/memory/change-log.md](</E:/GitHub/jmo-pixel-dungeon/docs/memory/change-log.md>)
- [docs/memory/backlog.md](</E:/GitHub/jmo-pixel-dungeon/docs/memory/backlog.md>)

## Known Rough Edges

The project is playable, but still has active work in areas like:

- full save/load confidence across edge cases
- deeper AI and boss fidelity
- remaining partial artifact/spell behavior
- framework cleanup for long-term reuse

## Versioning

Development is currently focused on **`0.1.1`**.

## License

No license file is currently present in the repository. If this project is going to be shared publicly, that should be clarified explicitly.
