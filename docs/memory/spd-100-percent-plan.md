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
(`test_pitfall_heap_drop.gd`); PitRoom contents/locks remain open.

1. Talent system foundation.
2. Examine/info windows.
3. Full upstream PitRoom contents (crystal door, empty well, skeleton loot/key).
4. `Level.drop_item` onto CHASM terrain routing thrown/placed items below.

## Done Criteria For Each Slice

- Source comparison is recorded in the implementation notes or final summary.
- Focused headless tests cover the behavior where feasible.
- `git diff --check` passes.
- Godot import and headless test suite pass when Godot is available.
- Changes are committed and pushed to `main` after verification.
- CI and Pages are checked for user-visible/browser-visible changes.
