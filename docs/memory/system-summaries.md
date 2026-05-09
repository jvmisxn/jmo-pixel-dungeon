# System Summaries

## Core Runtime

- `GameManager`, `TurnManager`, `EventBus`, `SaveManager`, and scene flow are the runtime spine.
- The port already has a functional turn-based loop and level lifecycle.
- Main architectural risk is not absence of systems; it is state integrity and coupling.

## Generation

- Historical logs show generation was one of the most fragile subsystems early on.
- The current project has extensive generation coverage, but generation changes should still be treated carefully because earlier failures caused blank maps, isolated rooms, and traversal problems.

## Combat / AI

- Combat and AI received heavy SPD-fidelity passes.
- Many high-priority formula and behavior bugs were already fixed historically.
- Remaining work is mostly deeper fidelity, missing systems, or special-case behavior rather than basic playability.

## Items

- The item surface area is broad and one of the repo's largest content domains.
- Generator, equipment progression, and value/recharge formulas received major historical fixes.
- Remaining high-value work is identification, curses, deck systems, and deferred exotic content.

## UI

- UI is functionally broad and supports actual play.
- Most remaining UI work is quality, depth, and workflow polish rather than total absence.

## Persistence

- Persistence has a long history of fixes and should still be treated as suspect until fully re-verified against current code.
- When touching runtime state, always consider save/load implications immediately.

## Frameworkization

- The codebase is already a viable game port.
- It is not yet a clean reusable framework.
- The most important path forward is hardening contracts and boundaries, not adding even more breadth first.
