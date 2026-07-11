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
- [P1][audit:S02] Mage starts with placeholder `worn_shortsword` "staff", no wand/spell (`hero.gd:124-137`); SPD Mage starts with a Staff of Magic Missile — core class identity/upgrade target missing.
- [P1][audit:S02] Class passives are empty `pass` stubs while perks advertise them: Warrior faster regen + Rogue stealth (`hero.gd:97-103`). Implement or stop advertising.
- [P2][audit:S02] `earn_xp()` doesn't cap `xp` at `MAX_HERO_LEVEL` (`hero.gd:772-776`); xp grows unbounded past cap and is serialized/shown. Clamp at max level.
- [P2][audit:S02] Champion "second weapon in ring slot" perk (`subclass_abilities.gd:85-92`) is unwired — `Belongings` has no dual-wield slot or attack path.
- [P2][audit:S02] Many talents beyond intuition/meal set are inert "groundwork slot" no-ops (`talent_data.gd`); points spend for zero effect — mark inert ones so picker UI doesn't sell dead upgrades.
- [P2][audit:S02] Add headless round-trip tests for `Belongings` (equip→serialize→deserialize identity, quickslot rebind, stack merge/remove_quantity) — highest data-loss surface in the hero system.
- [P2][audit:S02] `total_armor()` doc claims "armor and rings" but only sums armor (`belongings.gd:205-210`); fix the doc (rings act via buffs in SPD, not flat armor).
- [P3][audit:S02] `_projectile_collision_pos()` allocates a full-map bool array per throw (`hero.gd:486-497`); reuse a scratch `PackedByteArray` to cut per-shot GC churn.
- [P3][audit:S02] Duplicate local-focus-hero expression in `_do_move`/`_on_death` (`hero.gd:348,1077`); extract `_is_local_focus()` helper. (Truncated file.)
- [P3][audit:S02] `belongings.serialize()` writes unused `backpack_count` key (`belongings.gd:350`); dead field. (Truncated file → no auto-edit.)
- [P3][audit:S02] `BattemagePower` class/`buff_id` misspelled "Battemage" (`battlemage_power.gd:1,7`, ref `subclass_abilities.gd:155`); rename needs a save migration since `buff_id` is serialized — not mechanically safe.
- [P3][audit:S02] Backpack items lacking `serialize()` are silently dropped on save (`belongings.gd:354-357`); add an assert to surface silent data loss.
