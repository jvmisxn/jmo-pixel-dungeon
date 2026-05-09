# Architecture Map

## Runtime Spine

- `src/autoloads/`
  - Global coordinators: `GameManager`, `TurnManager`, `EventBus`, `SaveManager`, `AudioManager`, `SceneManager`, `MessageLog`, `ConstantsData`.
- `src/scenes/`
  - Flow and presentation orchestration: title, loading, game, death, victory, rankings, camera.
- `src/levels/`
  - Core grid, generation, rooms, traps, painters, builders, region/boss level classes.
- `src/actors/`
  - Actor base, character combat, hero, mobs, buffs, blobs, NPCs.
- `src/items/`
  - Item base plus category-specific implementations and `Generator`.
- `src/ui/`
  - HUD, windows, inventory presentation, minimap, status and toolbar.
- `src/sprites/`, `src/tiles/`, `src/effects/`
  - Rendering and feedback layers.

## Architectural Character

- Gameplay is mostly driven by data + methods on runtime objects rather than ECS.
- The project uses a state/render split, but game logic still emits many UI/audio-facing side effects through globals.
- Turn order is centrally scheduled by `TurnManager`.
- Scene transitions and run state are centrally managed through autoloads.

## Framework Readiness Notes

- Strong enough for continued porting.
- Not yet cleanly modular enough for multi-game reuse without hardening:
  - persistence
  - boundaries between rules and presentation
  - reduction of autoload coupling
