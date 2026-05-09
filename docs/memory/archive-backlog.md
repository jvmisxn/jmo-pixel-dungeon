# Archive Backlog

This file condenses unresolved work from `docs/history/` into a smaller working list.

## Highest Value System Gaps

- Item identification system is still a major missing SPD-defining mechanic.
- Talent system is still missing and affects long-term build variety.
- Curse system still needs deeper fidelity and stronger interactions.
- Persistence/save-load hardening remains a structural priority despite historical fixes.
- Framework readiness still requires cleaner boundaries between rules, presentation, and globals.

## Gameplay Fidelity Gaps

- Attack speed variation should remain verified across weapon categories and all turn-consuming actions.
- Some cursed wand/ring behaviors are still simplified.
- Some advanced mob targeting logic from SPD is still missing:
  - complex choose-enemy behavior
  - richer ally/charm/amok interactions
  - more nuanced boss/special-case behavior

## Content / Feature Gaps

- Full NPC dialogue trees remain shallow.
- Tutorial/guidebook content is still placeholder-level.
- Localization framework is still absent despite message assets existing in the repo.
- Accessibility support is still minimal.

## Item / Generator Backlog

- Deck-based potion/scroll drop logic remains unimplemented.
- Wand use-based identification is still deferred.
- Exotic potions/scrolls remain deferred.
- Seed-to-potion alchemy remains deferred.
- Some wand cursed-zap effect behavior remains deferred.

## UI / UX Backlog

- Some examine/info workflows remain thinner than original SPD.
- Dead-simple duplication patterns remain in UI helper access and window plumbing.
- Future multiplayer UI remains a separate track, not current framework readiness work.

## Audio / Art Backlog

- Real asset usage and pipeline consistency should be re-verified against current code, because historical notes disagree in places.
- A cleaner asset pipeline for sprite sheets / atlases is still desirable if the project moves beyond procedural visuals.

## How To Use This File

- Treat this as the short list derived from the large archive.
- If a bullet becomes actively worked, move the precise implementation notes into `change-log.md` and `active-context.md`.
- If a bullet needs source-level rationale, search `docs/history/`.
