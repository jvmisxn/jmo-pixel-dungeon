# Backlog

## High Priority

- Harden save/load contracts for `Hero`, `Level`, `Mob`, and related runtime state.
- Identify which systems should be moved toward cleaner core-vs-presentation boundaries.

## Medium Priority

- Decide whether to split framework-level code from Shattered-PD-specific content into separate top-level modules or folders.
- Add a small smoke-test workflow for launch, floor transition, combat, and save/load.

## Low Priority

- Consolidate overlapping large logs if they stop providing distinct value.
- Add a compact “recent sessions” index if the change log grows too large.

## System Audit Findings

Filed by the system-audit loop (`docs/memory/system-audit/`). Tag `[audit:<id>]`.

- [P1][audit:S01] Autosave on floor transition + app-close/pause; today a crash/kill/tab-close loses the whole run (save only fires from manual Save & Quit).
- [P1][audit:S01] Atomic save write + `.bak` rotation; current write does `store_var` straight over the sole file — mid-write crash corrupts it unrecoverably.
- [P2][audit:S01] Delete ~200 lines of dead, out-of-sync duplicate serialization in `save_manager.gd:309-537` (encodes a wrong contract; corruption trap if ever wired up).
- [P2][audit:S01] Add save migration path (`_migrate(save, from_version)`); `SAVE_VERSION` currently only rejects newer saves, older ones silently default changed fields.
- [P3][audit:S01] Verify `RegularLevel.serialize()` drop of room list is intentional (room-scoped spawns/shop detection) or persist it.
