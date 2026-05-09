# Framework Readiness

## Current Position

- The project is already a playable port with broad feature coverage.
- It is not yet a clean multi-game framework.

## Main Barriers

- heavy autoload coupling
- rules logic mixed with UI/audio/log side effects
- persistence contracts still worth hardening
- broad content surface with uneven verification depth

## What "Framework Ready" Should Mean Here

- Core rules can evolve without rewriting presentation.
- Reusing the dungeon/combat/item loop for a different game does not require dragging along Shattered-PD-specific assumptions everywhere.
- State is easier to test, save, load, and potentially sync.

## Near-Term Strategy

1. Harden core contracts first.
2. Reduce hidden cross-system coupling where practical.
3. Separate stable engine-like logic from game-specific content patterns.
4. Avoid adding more breadth when the same effort should go into structural clarity.

## Signs A Change Helps Frameworkization

- It reduces direct autoload dependencies.
- It makes data/state easier to serialize.
- It removes UI-specific assumptions from gameplay code.
- It turns special-case logic into reusable interfaces or factories.
