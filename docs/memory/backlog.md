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
- [P1][audit:S03] `Char` has no combat-state serializer — `Actor.serialize()` saves only actor_id/pos/active (`actor.gd:53-70`); hp/hp_max/ht/str/shielding/stats/flags rely on each subclass remembering them. Add `serialize_char()`/`deserialize_char()` (buffs already handled) and super-call it.
- [P1][audit:S03] `damage_roll()` uses uniform `randi_range` (`char.gd:70`); SPD `Char.damageRoll()` is `Random.NormalIntRange` (bell). Port damage is too swingy — apply the two-roll average already used by `dr_roll()`.
- [P1][audit:S03] Guaranteed hits fire only for invisible attackers (`char.gd:153`); SPD makes any attack a can't-miss surprise when the target doesn't see the attacker (sleeping/unaware/stealth) + Assassin +50%. Thread a `surprise` flag into `attack()`/`hit()`.
- [P2][audit:S03] Non-`Buff` nodes attach via `add_buff` script-path key (`char.gd:378`) but `has_buff`/`get_buff`/`remove_buff_by_id` only match `Buff` (`char.gd:418-435`) — such buffs become un-findable/un-removable. Require `Buff` or handle the path key in lookups.
- [P2][audit:S03] `_innate_immunities()` allocates a new Array every `is_immune()` call in the hot attack/take_damage path (`char.gd:551-558`); return a cached/`const` array.
- [P2][audit:S03] Buff lookups are O(n) string scans, ~12 per hit; add a `buff_id -> Array[Buff]` index updated in add/remove for O(1) `has_buff`/`get_buff`.
- [P2][audit:S03] No headless combat tests — add coverage for damage roll, `hit()` 1e6 eva/acc bounds (`char.gd:157-160`), armor averaging, shield→HP ordering, Doom×1.67/Vulnerable×1.33 order.
- [P2][audit:S03] Resistances/immunities skipped for `Char`-sourced attack damage (`char.gd:273-275`); SPD applies `resist(src.getClass())` to attacks too — confirm no physically-typed attackers need it or route attack damage through `resist()`.
- [P3][audit:S03] `die()` prevention (`char.gd:347`) can leave `is_alive=true` at `hp<=0` if a subclass prevents without restoring HP → re-enters `die()` on next hit; add a guard/assert.
- [P3][audit:S03] `distance_to`/`is_adjacent` duplicated verbatim in `Actor` (`actor.gd:77-96`) and `Char` (`char.gd:585-594`); Blob uses the base copies so keep them, but Char's could `super()`-delegate to cut drift.
- [P2][audit:S04] TurnManager persists no scheduling state — `clear_actors()` wipes cooldowns on save and actors re-register at 0 on load (`turn_manager.gd:331`, `save_manager.gd:86`); slowed/hasted/just-acted mobs reset timing. Serialize `{actor_id: cooldown}` and restore before `process_until_hero()`.
- [P2][audit:S04] Cached `speed` goes stale silently — cooldown math divides by `entry["speed"]` set at register time, refreshed only via manual `refresh_speed()` (`turn_manager.gd:112-156`); a speed buff without the paired refresh uses wrong timing with no error. Re-query `get_speed()` live in `spend_energy` (SPD recomputes per action).
- [P2][audit:S04] Dead async mob-pacing layer — `MOB_ACTION_DELAY` is `const 0.0` so the only `await` (`turn_manager.gd:321`) is unreachable; `_process_mobs_async` runs synchronously and `processing_mobs` never blocks. Restore per-mob pacing or delete the coroutine/cache/gate.
- [P2][audit:S04] Add headless scheduler tests: cooldown rebasing (`:208`), speed→cooldown division (`:151`), `round_completed` once per party round (`:264`), `remove_actor` cleans `_round_hero_ids_pending` (`:122`), freed-actor skip (`:218`).
- [P3][audit:S04] `_is_time_frozen_for_nonhero()` walks GameManager→hero→belongings→artifact every non-hero turn even with no hourglass (`turn_manager.gd:52-64, 235`); resolve the frozen flag once per hero action and cache it.
- [P3][audit:S04] All TurnManager lookups are O(n) scans over `_actors` (`:108-178`), several per action; add a `node → entry` Dictionary index for O(1).
- [P3][audit:S04] `process_until_hero()` bails silently after 500 iterations (`:343`); with no hero registered it burns 500 mob turns on load — log a warning on cap-hit.
- [P3][audit:S04] Header docstring claims buffs register as actors (`turn_manager.gd:6`) but `Buff extends Node` and never registers; fix the comment (truncated file → no auto-edit).
- [P1][audit:S05] Swarm split duplicates HP instead of halving — `_split()` sets `child.hp = hp` (full copy) leaving parent HP unchanged (`sewer/swarm.gd:43-45`); SPD divides current HP between the two flies, so total swarm HP ~doubles per split and over-grants XP. Split HP: `child.hp = hp/2; hp -= child.hp` (guard hp>=2), sync child ht/hp_max.
- [P2][audit:S05] `_find_visible_heroes()` returns unsorted and callers always take `heroes[0]` (`mob.gd:139,154,461`); on multi-hero levels the target isn't the nearest. Route wake/notice through the existing distance-based `_find_nearest_char()` (`mob.gd:268`).
- [P2][audit:S05] Spinner's `_act_hunting` override drops shared AI guards — never consults `should_flee()`/Amok/Terror from base (`caves/spinner.gd`, base `mob.gd:170`); an amok/terrified spinner still hunts. Delegate the move/attack tail to `super._act_hunting()`.
- [P2][audit:S05] `create_boss` fallback returns a statless bare `Mob.new()` for unknown depth (`mob_factory.gd:170`); return `null` to match `create_mob`'s warn+null contract (`:137-138`).
- [P2][audit:S05] Halls spawn table ignores depth — `_halls_table(_depth)` is flat, unlike every other region (`mob_factory.gd:79`); add a depth ramp for parity.
- [P3][audit:S05] `first_summon` is inert in Necromancer — tracked/serialized/set but never read; docstring promises a faster first summon that never happens (`prison/necromancer.gd:16,127,162,171`). Wire it into summon timing or drop the field (serialized → needs judgment, not auto-fixed).
- [P3][audit:S05] Goo `damage_roll()` mutates state (`pumped_up = 0`) as a side effect and the ranged branch re-zeroes it (`bosses/goo.gd`); move pump consumption to the attack path so the roll is pure/testable.
- [P3][audit:S05] `did_visible_action`/`last_visible_action` bookkeeping is hand-duplicated across many subclasses; centralize via the base `on_move`/`on_attack_hit` hooks (`mob.gd:391,406`).
- [P3][audit:S05] No tests for the AI state machine or `MobFactory` weighted selection (`mob_factory.gd:141`) / detection rolls (`mob.gd:142,157`) — all pure functions, seed the RNG.
- [P1][audit:S06] Fury 1.5× applied twice → effective 2.25× melee — `Char.damage_roll()` iterates `modify_damage()` (`char.gd:71-73`, `fury.gd:11`) AND `Char.attack()` re-multiplies by name (`char.gd:107-108`). Drive damage-mod from one path only.
- [P1][audit:S06] `get_speed()` never calls polymorphic `modify_speed()` — hard-codes Cripple/Stamina/Adrenaline/Haste by name (`char.gd:531-543`), so Sleep(0.0)/Dread/MonkFlurry/FreerunnerMomentum speed effects are dead and Adrenaline/Haste carry redundant no-op hooks. Iterate the hook, then drop the name checks.
- [P1][audit:S06] Doom is invented — 30-turn countdown that kills via `take_damage(target.hp)` (`doom.gd:16-23`); SPD Doom is a permanent +50% damage-taken amplifier that never timer-kills. Replace timer with a damage-taken multiplier hook.
- [P1][audit:S06] Gladiator Combo fully inert — `add_hit()`/`finisher_multiplier()` never called outside buffs dir (`combo.gd`); buff accumulates nothing, no finisher fires. Wire into the Gladiator attack path.
- [P1][audit:S06] Frozen freeze-potion loop mis-scoped — `if freezable.size() > 0` block sits inside the `for item` loop (`frozen.gd:36-45`), freezing multiple potions and mutating the backpack mid-iteration; SPD freezes one potion/mystery-meat. Dedent the block out of the loop.
- [P2][audit:S06] charm.gd/terror.gd lose `source_id` on save/load — both `serialize()` write it but neither overrides `deserialize()` (`charm.gd:23`, `terror.gd:23`); charmer/terror source reverts to -1 on reload. Add matching deserialize.
- [P2][audit:S06] Barkskin & ArcaneArmor ignore `interval` — `level -= 1` every turn regardless (`barkskin.gd:31-40`, `arcane_armor.gd:36`); Warden/high-interval variants decay too fast. Gate decay on interval.
- [P2][audit:S06] Barrier shielding coupling fragile — writes directly into `target.shielding` and `on_turn` overwrites it (`barrier.gd:36-47`), clobbering other shield sources; exposes `shielding()` but `Char.total_shielding()` looks for `get_shielding()` (`char.gd:496-501`) so Barrier isn't summed. Unify shield API.
- [P2][audit:S06] HerbalArmor double mechanic — flat +5 via `modify_armor` AND a 15-pt absorb pool (`herbal_armor.gd:18-24`); SPD Earthroot Armor is absorb-only.
- [P2][audit:S06] `ht` vs `hp_max` duality (`char.gd:20-21`) — regen/fury/well_fed use `ht`, berserker_rage/soul_mark use `hp_max`; kept equal in hero.gd but desyncs if any effective-max-HP modifier is added. Consolidate to one max-HP concept.
- [P2][audit:S06] vertigo.gd:26-32 random-neighbor offsets do raw ±1/diagonal index math with no row-edge check → column-edge char can be shoved to a wrapped adjacent-row cell. Add row-boundary guard.
- [P2][audit:S06] Weakness carries `STR_PENALTY` + doc'd STR/accuracy penalty but implements no `modify_*` hooks (`weakness.gd`) — inert unless external code reads the const. Wire the penalty or document the external owner.
- [P2][audit:S06] Buff lookups are O(n) string scans (`has_buff`/`get_buff`/`remove_buff_by_id`, `char.gd:424-435`), many per swing; add a `Dictionary[buff_id → buff]` cache like SPD's typed map.
- [P2][audit:S06] No `ParalysisResist` buff — paralysis break uses inline `randi_range` per hit (`paralysis.gd:27-33`) instead of SPD's accumulating slow-decay resist. Add the resist buff.
- [P3][audit:S06] Poison damage off-by-one vs SPD — base `act()` decrements `time_left` before `on_turn()` reads it (`poison.gd:33`, `buff.gd:63-65`); tick uses `left-1`.
- [P3][audit:S06] MonkFlurry.description() builds `parts[]` then returns a fixed generic string ignoring it (`monk_flurry.gd:64-72`).
- [P3][audit:S06] fire_imbue/frost_imbue document Burning/Chill immunity that is not implemented (`fire_imbue.gd:6`, `frost_imbue.gd:6`).
- [P3][audit:S06] Imbue procs unwired — `FireImbue.proc()`/`FrostImbue.proc()` never called; `FireImbue.proc` also calls non-existent `Burning.reignite()` (`fire_imbue.gd:27`) → latent crash if wired. Fix the reignite call and wire procs into the attack path.
- [P3][audit:S06] `Burning.burn_increment` declared+serialized but never read (`burning.gd:10,82,89`) — dead state carried in every save. (Persistence-adjacent; left for approval rather than auto-fixed.)
- [P3][audit:S06] barkskin/arcane_armor `delay()` is a no-op `pass` stub whose docstring promises a cooldown adjustment.
- [P3][audit:S06] Dead no-op `MonkFlurry.on_turn()` override — AUTO-FIXED this run (removed on `audit/autofix`, PR #1).
- [P3][audit:S06] No buff unit tests (poison/bleed/corrosion decay curves, barrier depletion, hunger thresholds, serialize round-trips) — pure logic, cheap to cover.
- [P1][audit:S07] `mob_spawn_positions` under-spawns mobs — `remaining` decremented on failed placements too (`regular_level.gd:411`, no-op `pass` :410); empty-`std_rooms` fallback returns one pos not `count` (:378-382); "25% second mob same room" (:359) never implemented. Loop on successful placements.
- [P1][audit:S07] No periodic mob respawn (SPD `RegularLevel.respawner`) — mobs spawn once in `_build`; killed mobs never replaced → floors deplete, diverges from SPD balance. Add a rooms-weighted respawn timer.
- [P2][audit:S07] Mimic spawn discards its item — `regular_level.gd:115-122` throws away the rolled `item` instead of giving it to the mimic (also no `scale_to_depth`) → silent item loss, mimic drops nothing.
- [P2][audit:S07] `rooms` not serialized (`level.gd:717/777`) — empty after load; blocks respawn/room-based post-load features; SPD persists room bounds/types.
- [P2][audit:S07] `is_visible_from`/`has_los` (`level.gd:591-609`) allocate a full LEN `Array[bool]` via `ShadowCaster.cast_fov` per point LOS query (5 sites incl. mob targeting); route through existing `Ballistica` (O(distance)).
- [P2][audit:S07] O(n) linear scans on hot paths — `mob_at`/`find_char_at`/`heaps_at`/`pickup_item` (`level.gd:478-516`) scan all mobs/heaps per call; add a `pos->mob`/`pos->heap` index.
- [P3][audit:S07] `update_fov` runs 3–4 full-grid (LEN) passes per hero move (`level.gd:355-369`) — fusable if FOV ever profiles hot.
- [P3][audit:S07] `unlock_exit` (`level.gd:624-631`) opens every LOCKED_DOOR on the level rather than the exit-gating door.
- [P3][audit:S07] `static var _recent_specials` (`regular_level.gd:505`) is process-global, not per-run/not reset on new game → special-room-variety tracking bleeds across games; move to per-dungeon state.
- [P3][audit:S07] Grid constants duplicated: `level.gd:10-12` hardcodes `W/H/LEN` vs `ConstantsData.WIDTH/LENGTH` in `regular_level.gd` (equal today) — derive from ConstantsData.
- [P3][audit:S07] DARK feeling is visual-only (fog dim, `game_scene.gd:439`) — never reduces view distance; low-confidence fidelity note, verify vs SPD before acting.
- [P3][audit:S07] Several `pos / W` int divisions lack `@warning_ignore("integer_division")` (`level.gd:298-299,381-382,405-406`) — cosmetic warnings.
