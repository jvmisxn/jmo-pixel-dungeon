# Shattered Pixel Dungeon 100% Parity Plan

Created: 2026-07-20

Purpose: drive `jmo-pixel-dungeon` toward full parity with the original/current Shattered Pixel Dungeon reference while preserving intentional multiplayer and mobile/desktop control/layout adaptations.

## Definition

100% parity means the Godot port should match upstream Shattered Pixel Dungeon behavior, progression, content, and player-facing information surfaces wherever practical. Intentional divergences must be explicit and documented, especially for multiplayer, web/mobile packaging, and platform-specific controls.

## Current Read

The port is broad and playable. Combat math, regional content, many items, many mobs, wands, rings, bags, traps, save pieces, mobile controls, and headless coverage have improved substantially.

The remaining gap is not one missing item category. The high-value work is concentrated in:

- a unified actor timeline for actors, buffs, blobs, and save/load scheduling
- progression systems, especially talents and class armor
- examine/info UX and other learnability surfaces
- meta run options such as challenges, exposed seeds, keybindings, and localization
- remaining parity content such as exotic items, deeper alchemy, missing mobs/foods/artifacts, and full Blacksmith behavior

## Operating Rules

- Use Fable subagents for substantive source comparison, implementation planning, coding, and final review.
- Codex/main orchestration should inspect git state first, preserve unrelated dirty files, integrate/review patches, run local checks, commit/push narrow changes, and watch CI/Pages before announcing completion.
- Prefer one coherent behavior or parity gap per commit.
- Compare against upstream `00-Evan/shattered-pixel-dungeon` source where possible.
- Do not chase stale backlog items without verifying current source first.
- If a Jamison-reported active regression exists, fix it before roadmap work.
- Treat Cleric parity as a scope decision: required for current-upstream parity, optional if the project explicitly targets a pre-Cleric SPD baseline.

## Phase 0 - Safety And Source Of Truth

1. Keep this file as the top-level parity roadmap.
2. Reconcile stale `docs/memory/backlog.md` items as work completes.
3. Keep `docs/memory/change-log.md` updated for each shipped slice.
4. Avoid broad edits to historically fragile large files unless closely reviewed.

## Phase 1 - Core Timeline And Persistence

1. Persist `TurnManager` scheduling state.
   - Serialize and restore actor cooldowns, turn count, round count, and current input actor state as needed.
   - Restore scheduler state before `process_until_hero()` after load.
   - Add headless tests proving a just-acted/slowed/hasted actor does not reset to zero cooldown on reload.

2. Move buffs onto the scheduled actor timeline.
   - Buff duration should be based on game timeline, not the owner's personal action rate.
   - Stop burning/poison/bleed/other timed effects from expiring faster on Hasted actors or slower on Slowed actors.
   - Preserve existing buff serialization and source tracking.

3. Move blobs/gases onto the scheduled actor timeline.
   - Drive blobs per timeline turn rather than per hero round.
   - Preserve multi-hero/co-op correctness.

4. Port SPD-style conserved blob volume.
   - Replace copy-outward density spreading with volume-conserving diffusion.
   - Add tests for spread shape, decay, persistence, and non-exploding volume.

## Phase 2 - Environment, Chasms, Traps, Level Generation

1. Complete blob seeders and missing blob classes.
   - Add or wire ConfusionGas, WaterOfHealth, Caustic/Stench gas, StormCloud, Regrowth, SmokeScreen, and related classes where upstream uses them.

2. Route plants and traps through blobs.
   - Firebloom, Sorrowmoss, Stormvine, Icecap, and gas/fire/frost traps should seed the relevant lasting blob instead of only applying one-shot local effects.

3. Finish chasm and pitfall parity.
   - PitfallTrap should force a depth drop rather than same-level teleport.
   - Falls should land in appropriate pit-room/depth contexts where upstream does.

4. Add level-builder variety and weighted trap pools.
   - Move beyond always using the loop builder.
   - Match upstream regional builder/trap weighting where practical.

## Phase 3 - Progression Systems

1. Build the real talent system.
   - Replace the current mostly-metadata talent layer with functional tiered class/subclass talent trees.
   - Implement real effects, picker constraints, serialization, and tests.

2. Add class armor and armor abilities.
   - Implement Warrior, Mage, Rogue, Huntress, and Duelist class armor equivalents and active abilities.
   - Wire to Blacksmith/talent progression as upstream expects.

3. Decide Cleric scope.
   - If targeting current upstream SPD, add Cleric, Priest, Paladin, holy tome/spells, talents, unlocks, and UI.
   - If not, document the target upstream baseline explicitly.

## Phase 4 - Learnability And UX Parity

1. Add examine mode and info windows.
   - Implement cell, mob, trap, plant, heap/item, and buff info surfaces.
   - Make buff icons tappable on touch devices.

2. Add localization scaffolding.
   - Start wrapping user-facing strings in `tr()`.
   - Add Godot translation resources, even if only English exists initially.

3. Add input action map and keybindings UI.
   - Move hardcoded key handling into project input actions.
   - Add remapping and prepare for controller support.

4. Expand settings and journal/catalog depth.
   - Add display/UI/language settings, toolbar/quickslot options, alchemy guide, document/story reader, and clickable catalog detail.

## Phase 5 - Meta Runs And Content Completion

1. Add challenge toggles.
2. Expose custom seed entry and daily-run style paths if in scope.
3. Complete badges/rankings parity.
4. Add story/floor-intro windows.
5. Add exotic potions and scrolls plus alchemy recipes.
6. Add Lloyd's Beacon.
7. Add missing mobs and variants such as Ghoul/Gnoll Geomancer/crystal mimic behavior where upstream requires them.
8. Add missing foods and Blandfruit/cooking chain.
9. Add armor curse glyphs.
10. Complete Blacksmith parity: pickaxe/mining, quest variants, boss/encounter paths, favor system, and reward choices.

## Suggested Immediate Queue

Verified shipped (2026-07-24 source check): TurnManager schedule persistence,
scheduled buff timeline, scheduled conserved blobs, plant/trap/blob routing,
and pitfall/chasm landing parity including fallen-item heap drops
(`test_pitfall_heap_drop.gd`) and `Level.drop_item` CHASM routing
(`test_chasm_drop_item.gd`, 2026-07-24), and full upstream PitRoom contents
(crystal door, empty well, skeleton loot/key, `test_pit_room_contents.gd`,
2026-07-24).

1. Talent system foundation — 2026-07-27 audit: all registered
   class/subclass talent ids in `talent_data.gd` are wired into live
   gameplay except the `_make_inert` slots (Duelist
   aggressive_barrier/weapon_recharging, Champion, Monk), which are blocked
   on the unported Duelist weapon-ability/charge system. 2026-07-27: the
   charge pool shipped (`WeaponCharger` buff + live
   duelist_weapon_recharging, `test_weapon_charger.gd`). 2026-07-28: the
   ability execution path + sword-family Cleave shipped and
   duelist_aggressive_barrier is live (`test_weapon_ability_cleave.gd`).
   2026-07-28: heavy-blow family shipped (Cudgel/HandAxe/Mace/BattleAxe/
   WarHammer, `test_weapon_ability_heavy_blow.gd`; Greataxe has a distinct
   upstream ability, still unported). 2026-07-28: sneak family shipped
   (Dagger/Dirk/AssassinsBlade blink + invisibility,
   `test_weapon_ability_sneak.gd`). 2026-07-28: spike family shipped
   (Spear/Glaive reach-only strike + one-cell knockback,
   `test_weapon_ability_spike.gd`). 2026-07-28: Rapier Lunge shipped
   (dash + boosted strike at reach+1, out-of-FOV waste case,
   `test_weapon_ability_lunge.gd`). 2026-07-28: Guard family shipped
   (RoundShield/Greatshield GuardTracker stance,
   `test_weapon_ability_guard.gd`). 2026-07-28: Combo Strike family
   shipped (Gloves/Sai, ComboStrikeTracker fed by every Duelist hit,
   `test_weapon_ability_combo.gd`; Gauntlet not in roster). 2026-07-28:
   Sword Dance shipped (Scimitar instant stance, 1.5x accuracy + 0.6
   attack-speed bonus, `test_weapon_ability_dance.gd`). 2026-07-28:
   Defensive Stance shipped (Quarterstaff instant stance, 3x evasion,
   `test_weapon_ability_defensive_stance.gd`). 2026-07-28: Runic Slash
   shipped (Runic Blade guaranteed hit, +3+0.5*lvl enchant proc-chance
   multiplier via consumed RunicSlashTracker,
   `test_weapon_ability_runic_slash.gd`). 2026-07-29: Flail Spin shipped
   (stacking 3-spin tracker, free re-spins, guaranteed-hit release with
   +spins*(8+2*lvl), `test_weapon_ability_spin.gd`; flail
   no-surprise-attack gap logged in backlog). 2026-07-29: Greataxe
   Retribution shipped (below-half-HP-only guaranteed hit, +15+2*lvl,
   instant on kill, `test_weapon_ability_retribution.gd`) — every melee
   weapon in the roster now has its Duelist ability. 2026-07-29:
   Champion talent set reshaped to upstream (varied_charge live with
   `test_varied_charge.gd`; twin_upgrades + combined_lethality registered
   inert, blocked on dual-wield secondary-weapon parity). 2026-07-29:
   MonkEnergy pool shipped (kill-driven energy gain, regen gate, cap,
   serialization, `test_monk_energy.gd`); Monk talents reshaped to
   upstream ids with unencumbered_spirit LIVE, monastic_vigor +
   combined_energy inert pending monk abilities. 2026-07-29: Flurry
   shipped (`_do_monk_ability` + UnarmedAbilityTracker weapon bypass +
   cap deferral, `test_monk_flurry_ability.gd`) but not yet
   player-reachable. 2026-07-29: Focus shipped (FocusBuff parry stance,
   infinite-evasion-beats-surprise Char.hit ordering fix,
   `test_monk_focus_ability.gd`). 2026-07-29: Dash shipped (3-energy
   instant blink to an empty cell in range 4/8, projectile-line gated,
   `test_monk_dash_ability.gd`). 2026-07-29: Dragon Kick shipped
   (4-energy 6x/9x guaranteed unarmed strike, 6-cell knockback +
   min(6,dist) paralysis, empowered adjacent sweep,
   `test_monk_dragon_kick_ability.gd`). 2026-07-29: Meditate shipped
   (5 energy + 5 turns, debuff cleanse, post-meditation Recharging 8,
   empowered heal-over-time via new generic Healing buff + 20% damage
   MeditateResistance, `test_monk_meditate_ability.gd`) — all five monk
   abilities are ported. 2026-07-29: monk ability picker UI shipped
   (`wnd_monk_abilities.gd` per upstream WndMonkAbilities, opened by
   tapping the Monk Energy buff icon as the ActionIndicator stand-in,
   `test_wnd_monk_abilities.gd`) — all five abilities are now
   player-reachable, pending Monk playtest. 2026-07-29: Monastic Vigor +
   Combined Energy wired live (`CombinedEnergyAbilityTracker`,
   `test_combined_energy.gd`) — the Monk talent set is complete. Next
   talent milestone = Champion dual-wield parity
   (twin_upgrades/combined_lethality). 2026-07-29: dual-wield foundation
   shipped (`Belongings.second_wep` slot + serialization, SAVE_VERSION 7,
   `test_belongings_second_wep.gd`); remaining: Champion equip prompt,
   attacking-weapon/combat path + swap action, legacy `ChampionDualWield`
   buff replacement, then twin_upgrades/combined_lethality go live. 2026-07-30: equip path + legacy buff retirement
   shipped (Equip 2nd button, Off-hand inventory slot, second_wep
   equip/unequip routing, migration shim moves old-save buff weapons into
   the slot, primary-only attacks per upstream,
   `test_champion_dual_wield_migration.gd`). 2026-07-30: Twin Upgrades LIVE
   (buffed_lvl borrow with tier-gap-by-points gate + re-entrancy guard,
   `test_twin_upgrades.gd`). 2026-07-30: off-hand abilityWeapon path
   shipped (transient `Belongings.ability_weapon` override routing attack
   math through the off-hand during its ability strike,
   `test_weapon_ability_offhand.gd`); remaining: swap ActionIndicator,
   then combined_lethality (last inert Champion talent). 2026-07-30:
   Combined Lethality LIVE (differing-weapon execute at 0.4*points/3 HP,
   `test_combined_lethality.gd`) — zero inert talents remain. 2026-07-30:
   instant swap shipped (`Belongings.swap_weapons` free action + tappable
   Champion WeaponCharger icon as the ActionIndicator stand-in,
   `test_champion_weapon_swap.gd`) — Champion dual-wield parity is
   COMPLETE and this talent-foundation item is closed.
2. Examine/info windows — DONE 2026-07-27 (foundation + desc content +
   toolbar/X entry + region tile overrides + heap multi-item chooser +
   tappable buff icons shipped 2026-07-24; styled WndInfoTrap/WndInfoPlant +
   chooser INFO icon shipped 2026-07-27 — see backlog examine item).

## Done Criteria For Each Slice

- Source comparison is recorded in the implementation notes or final summary.
- Focused headless tests cover the behavior where feasible.
- `git diff --check` passes.
- Godot import and headless test suite pass when Godot is available.
- Changes are committed and pushed to `main` after verification.
- CI and Pages are checked for user-visible/browser-visible changes.
