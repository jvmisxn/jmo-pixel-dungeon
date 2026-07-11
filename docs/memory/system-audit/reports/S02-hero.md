# Hero & belongings — Audit

- Files: `src/actors/hero/hero.gd` (1203L), `belongings.gd` (414L), `hero_class_data.gd` (135L), `subclass_abilities.gd` (191L), `talent_data.gd` (129L)
- Read in full: yes
- Verdict: **needs-hardening / thin** — the command-pattern turn loop, leveling, talent-gated procs and save graph are solid, but class/subclass identity is largely stubbed (Mage has no staff, Warrior/Rogue passives are `pass`, Champion dual-wield unwired) and several talents are groundwork-only no-ops. `hero.gd` + `belongings.gd` are both in `TRUNCATED_FILES.txt` — flag-only, no auto-edit.

## Improvements
- [P1] Mage starting kit is a placeholder `worn_shortsword` "staff" with no wand/spell (`hero.gd:124-137`) — in SPD the Mage starts with a **Staff of Magic Missile** (the class's core identity + upgrade target). Give a real staff/wand so Mage is playable as intended.
- [P1] Class passives promised by descriptions/perks are empty stubs: `_apply_class_buffs()` Warrior "regenerates faster" and Rogue stealth are literal `pass` (`hero.gd:97-103`), while `HeroClassData.get_perks()` advertises them. Either implement (Warrior regen multiplier via the `Regeneration` buff; Rogue stealth) or stop advertising. SPD parity gap.
- [P2] `earn_xp()` stops leveling at `MAX_HERO_LEVEL` but still adds raw `xp` with no cap (`hero.gd:772-776`) — at max level `xp` grows unbounded and is serialized/shown that way. SPD caps XP at max level. Clamp `xp` to `xp_to_next` (or 0) once capped.
- [P2] `Belongings.total_armor()` doc says "from equipped armor **and rings**" but only sums `armor` (`belongings.gd:205-210`). In SPD rings act via buffs, not flat armor — fix the doc (rings don't belong here) rather than the code, to avoid a false contract.
- [P3] Quickslot restore binds by `item_id` via `find_item_by_id()` which returns the **first** match (`belongings.gd:406-414`); with two distinct instances sharing an id the quickslot can bind to the wrong one. Low impact today (ids are unique per stack) — note for when instance identity matters.

## Optimizations
- [P3] `_projectile_collision_pos()` allocates a fresh full-map `occupied` bool array (size `level.passable.size()`) on every throw/shot (`hero.gd:486-497`). Reuse a scratch buffer or a `PackedByteArray` on the level to cut per-shot GC churn.
- [P3] The "is this the locally-focused hero?" expression is duplicated verbatim in `_do_move` (`hero.gd:348`) and `_on_death` (`hero.gd:1077`). Extract a `_is_local_focus() -> bool` helper.
- [P3] `belongings.serialize()` writes a `backpack_count` key that `deserialize()` never reads (`belongings.gd:350`) — dead field; drop it. (Truncated file → backlog, no auto-edit.)

## Additions
- [P2] Champion subclass perk "equip a second melee weapon in the ring slot" (`subclass_abilities.gd:85-92`) has no support in `Belongings` — there is no second-weapon slot or dual-wield attack path. Wire a slot or repurpose `ring_left/right` explicitly.
- [P2] Most talents beyond the intuition/meal set are "groundwork slot" no-ops (`talent_data.gd`) — points can be spent (`upgrade_talent`) with zero gameplay effect. Track which are inert so the picker UI doesn't sell dead upgrades.
- [P2] No round-trip tests for `Belongings` (equip → serialize → deserialize identity, quickslot rebind, stack merge/remove_quantity). This is the highest data-loss-risk surface in the system and is easy to unit test headless.
- [P3] `BattemagePower` class/`buff_id` is misspelled ("Battemage", `battlemage_power.gd:1,7` + ref `subclass_abilities.gd:155`). Because `buff_id` is serialized, a rename must ship a save-migration — not mechanically safe. Backlog only.

## Save/load & coupling notes
- Persistence graph is sound: `Belongings.deserialize()` rebuilds items via `Generator.create_item(id)` then `item.deserialize(data)`, equips via `set(slot_name, item)` (bypassing on-equip side effects — correct for load), and `Hero.deserialize()` calls `artifact.resolve_post_load()` for graph fixups (`hero.gd:1035-1038`). Buffs round-trip via `_serialize_buffs`/`_deserialize_buffs`.
- Coupling: `Hero` hard-depends on autoloads `GameManager`, `EventBus`, `MessageLog`, `TurnManager`, `AudioManager`, `Generator`, `ConstantsData`. `has_key/use_key` read `GameManager.depth` directly (`hero.gd:722-744`). Acceptable for now; a framework extraction would want these injected.
- Any backpack item lacking `serialize()` is silently dropped on save (`belongings.gd:354-357`) — currently all items have it, but it's a silent-data-loss path worth an assert.

## Research notes
- SPD reference: Mage → Staff of Magic Missile start; Warrior → faster natural regen + broken seal; Champion → second weapon in the off-hand ("ring") slot; hero XP is capped at max level. These confirm the P1/P2 fidelity gaps above.
- Godot 4.5: reusing a persistent scratch `PackedByteArray` over per-call `Array[bool].resize()+fill()` is the idiomatic way to kill per-turn allocations in hot paths like Ballistica casts.
