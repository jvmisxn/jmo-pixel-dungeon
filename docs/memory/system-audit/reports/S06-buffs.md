# Buffs — Audit

- Files: `src/actors/buffs/` (base `buff.gd` + ~55 effect buffs + `subclass/` passives). Driven by `Char` (`src/actors/char.gd`): `add_buff`/`remove_buff`/`process_buffs`/`_serialize_buffs`/`_deserialize_buffs`.
- Read in full: base `buff.gd`, `char.gd` buff/combat/speed sections, and every stateful buff (poison, burning, bleeding, regeneration, hunger, barrier, corrosion, invisibility, frozen, paralysis, combo, fury, weakness, berserker_rage, monk_flurry, soul_mark, fire_imbue). Remaining ~37 flavour/marker buffs read via a full-file scan pass. No file skipped.
- Verdict: **needs-hardening** — base lifecycle + save/relink graph is solid, but the modifier-dispatch layer is inconsistent (polymorphic hooks for accuracy/evasion/damage/armor, hard-coded name lists for speed and part of damage). That split causes a live damage double-count, a set of dead `modify_speed` hooks, and several SPD-fidelity divergences.

## Improvements
- [P1] **Fury 1.5× is applied twice → effective 2.25× melee.** `Char.damage_roll()` iterates every buff's `modify_damage()` (char.gd:71-73), and `Fury.modify_damage` returns `dmg*1.5` (fury.gd:11). Then `Char.attack()` *also* multiplies by 1.5 by name (char.gd:107-108). Both fire on the same swing. Weakness (0.67×) and BerserkerRage are single-applied (Weakness has no `modify_damage`; BerserkerRage's `attack()` path looks for a non-existent `damage_factor()`). Fix: drive damage-mod from one path only.
- [P1] **`get_speed()` ignores the polymorphic `modify_speed()` hook** (char.gd:531-543) — it hard-codes only Cripple/Stamina/Adrenaline/Haste by name. So `Sleep`(returns 0.0), `Dread`, `MonkFlurry`, `FreerunnerMomentum` speed effects are **dead**, and Adrenaline/Haste carry redundant no-op `modify_speed` overrides. (This also neutralizes the Sleep `modify_speed()==0.0` divide-by-zero risk — the value is never consumed.) Fix: iterate `modify_speed()` like the other stats, then remove the now-redundant name checks.
- [P1] **Doom is invented, not SPD.** `doom.gd:16-23` is a 30-turn countdown that then kills via `take_damage(target.hp)`. SPD Doom is a *permanent* debuff that amplifies all damage taken by ~50% and never timer-kills. The +50% amplifier is not implemented (no damage hook). Fix: replace the timer with a damage-taken multiplier.
- [P1] **Gladiator Combo mechanic is fully inert.** `combo.gd` `add_hit()`/`finisher_multiplier()` are never called outside the buffs dir (grep-confirmed), so the buff accumulates nothing and no finisher fires. Matches the S02 "subclass identity stubbed" theme.
- [P1] **Frozen freeze-potion loop is mis-scoped** (frozen.gd:36-45): the `if freezable.size() > 0` block sits *inside* the `for item …` loop, so once one potion is found it freezes a random freezable on every remaining iteration — removing multiple potions and mutating the backpack mid-iteration. SPD freezes exactly one potion/mystery-meat. Fix: dedent the freeze block out of the loop; also handle mystery meat.
- [P2] **charm.gd / terror.gd lose `source_id` on save/load.** Both `serialize()` write `source_id` (charmer/terror actor id) but neither overrides `deserialize()`, so base deserialize drops it and it reverts to -1 (charm.gd:23, terror.gd:23). Charm/Terror redirection breaks across a reload.
- [P2] **Barkskin & ArcaneArmor ignore their `interval`** (barkskin.gd:31-40, arcane_armor.gd:36): `level -= 1` every turn regardless of `interval`, so Warden/high-interval variants decay far too fast. `interval` is read only in `set_level`'s comparison, never to gate decay.
- [P2] **Barrier shielding coupling is fragile** (barrier.gd:36-47): it writes directly into `target.shielding` and `on_turn` *overwrites* it (`target.shielding = shield_amount`), clobbering other shielding sources; it also exposes `shielding()` while `Char.total_shielding()` (char.gd:496-501) looks for `get_shielding()`, so Barrier is never summed there. Double-count / clobber risk when multiple shield sources coexist.
- [P2] **HerbalArmor is a double mechanic** (herbal_armor.gd:18-24): grants flat `+5` via `modify_armor` AND drains a 15-pt absorb pool by post-armor damage. SPD Earthroot Armor is absorb-only.
- [P2] **`ht` vs `hp_max` duality** (char.gd:20-21): regen/fury/well_fed use `ht`; berserker_rage/soul_mark use `hp_max`. Currently kept equal in `hero.gd`, but any effective-max-HP modifier would silently desync the two. Consolidate to one max-HP concept (SPD has only `HT`).
- [P2] **vertigo.gd:26-32** random-neighbor offsets do raw `±1`/diagonal index math with no row-edge check, so a char on a column edge can be shoved to a wrapped cell on the adjacent row; `is_passable` won't catch horizontal wrap.
- [P2] **Weakness applies no effect from within the buff** (weakness.gd): declares `STR_PENALTY` and documents STR/accuracy penalties but implements no `modify_*` hooks (unlike Hex/Daze). Inert unless an external system reads the const.
- [P3] **Poison damage off-by-one vs SPD** (poison.gd:33): base `act()` decrements `time_left` *before* `on_turn()` reads it (buff.gd:63-65), so the tick uses `left-1`. SPD damages with `left` then decrements.
- [P3] **MonkFlurry.description()** builds a `parts[]` list then returns a fixed generic string ignoring it (monk_flurry.gd:64-72).
- [P3] **fire_imbue/frost_imbue document immunities they don't implement** (fire_imbue.gd:6, frost_imbue.gd:6): "grants immunity to Burning/Chill" — no immunity hook exists.

## Optimizations
- [P2] `has_buff`/`get_buff`/`remove_buff_by_id` are O(n) linear string scans over `_buffs` (char.gd:424-435), and combat calls many per swing (accuracy/evasion/damage/armor loops + ~8 named `has_buff` checks in `attack`/`hit`/`get_speed`). SPD keeps a typed buff map. A `Dictionary[buff_id → buff]` cache alongside `_buffs` would cut per-swing overhead.
- [P3] `Burning.burn_increment` is declared and serialized but never read anywhere (burning.gd:10,82,89) — dead state carried through every Burning save.

## Additions
- [P2] **No `ParalysisResist` buff.** paralysis.gd comments reference an accumulating-resist buff that decays slowly (SPD behavior); the port instead breaks paralysis via inline `randi_range` per hit (paralysis.gd:27-33). Adding the resist buff restores SPD's "enough total damage breaks it" feel.
- [P3] **Imbue procs are unwired.** `FireImbue.proc()` / `FrostImbue.proc()` are never called (no `.proc(` on imbue buffs), so both imbues are inert. `FireImbue.proc` also calls a non-existent `Burning.reignite()` (fire_imbue.gd:27) — a latent crash the moment procs get wired.
- [P3] Buff unit tests: none exist for the stateful buffs (poison/bleed/corrosion decay curves, barrier depletion, hunger thresholds, serialize round-trips). These are pure-logic and cheap to cover.

## Save/load & coupling notes
- Round-trip is script-path based (`_script_path` in `Buff.serialize`), reconstructed in `Char._deserialize_buffs` which re-`attach()`es each buff. Counter-style buffs (Invisibility/Frozen/Paralysis increment `target.invisible`/`paralysed` in `on_attach`) restore correctly because Char does **not** serialize those counters — verified no double-increment.
- Stateful buffs mostly override `serialize`/`deserialize` correctly (chill/ooze/dread/adrenaline_surge/well_fed/corrosion/burning/bleeding/combo/berserker_rage/monk_flurry/hunger/regeneration/barrier verified). Exceptions: **charm** and **terror** serialize `source_id` with no matching deserialize (P2 above).
- Autoload coupling: buffs reach `GameManager` (depth/locked floor), `MessageLog`, `EventBus`, `ConstantsData`. All null-guarded. Depth is read live each tick (burning/corrosion) rather than captured — acceptable.

## Research notes
- SPD references: `Buff.java` (act/postpone/detach), `Fury.java` (single 1.5× via `damageFactor`), `Doom.java` (permanent +50% damage-taken, no timer), `Frost.java` (freezes one random potion/mystery meat), `Barkskin.java`/`ArcaneArmor.java` (interval-gated level decay), `Corrosion.java` (damage +1 below `scalingDepth/2+2`, +0.5 above — port matches), `Regeneration.java` (HT/10 base, partialRegen accumulator — port matches).
- Godot 4.5: iterating a typed-buff map beats repeated linear `has_buff` scans; the polymorphic-hook vs named-check split is the root cause of both the Fury double-count and the dead speed hooks.
</content>
</invoke>
