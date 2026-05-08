# Critical Fixes — Shattered Pixel Dungeon Godot Recreation

These issues cause the game to feel fundamentally different from the original or create significant balance problems.

## Priority 1 — Game Balance Breaking

### ~~1. Full Heal on Level Up (hero.gd:539)~~ — FIXED (2026-05-07, Gameplay Mechanics 2nd pass)
Level-up now uses `hp += max(new_ht - old_ht, 0); hp = min(hp, hp_max)` matching original `updateHT(true)`.

### ~~2. Combat Hit Formula is Wrong (char.gd)~~ — FIXED (2026-05-07, Gameplay Mechanics 2nd pass)
Replaced with `static func hit()` using dual-roll system with Bless/Hex/Daze modifiers on both sides.

### ~~3. Hunger Warning Triggers 75 Turns Too Early (hunger.gd)~~ — FIXED (2026-05-07, Gameplay Mechanics earlier pass)
Now uses `const HUNGRY_THRESHOLD: float = 300.0` and `const STARVING_THRESHOLD: float = 450.0` directly.

## Priority 2 — Missing Core Systems

### 4. No Item Identification
Without identification, the strategic layer of "should I drink this unknown potion?" is entirely missing. This is arguably the #1 roguelike mechanic that defines SPD's gameplay.

### 5. No Talent System
Talents affect literally every aspect of gameplay from combat to exploration. Without them, subclass choice is meaningless and builds are non-existent.

### 6. No Curse System
Cursed items create critical risk/reward decisions around equipping unidentified gear. Without curses, there's no downside to equipping everything immediately.

## Priority 3 — Combat Feel

### ~~7. Armor Uses Uniform Roll Instead of NormalInt (char.gd)~~ — FIXED (2026-05-07, Gameplay Mechanics 2nd pass)
Replaced with triangular distribution `(randi_range(0,armor) + randi_range(0,armor)) / 2` in new `dr_roll()` method.

### 8. No Attack Speed Variation
All weapons take the same turn time regardless of type. A dagger should attack ~1.5x per turn while a greatsword attacks ~0.67x.

### ~~9. Furrowed Grass Vision~~— NOT A BUG (corrected in FOV audit)
Original Terrain.java: `flags[FURROWED_GRASS] = flags[HIGH_GRASS]` which includes LOS_BLOCKING. Furrowed grass DOES block vision in the original. Godot behavior is correct.

## Priority 1 — AI & Mob Behavior (added 2026-05-07)

### ~~10. Wandering Mobs Have No Stealth Detection Roll (mob.gd)~~ — FIXED (2026-05-07, AI & Mob Behavior 2nd pass)
Both `_act_sleeping()` and `_act_wandering()` now use distance+stealth detection rolls matching original. Sleeping: `1/(dist + stealth)`. Wandering: `1/(dist/2 + stealth)`.

### ~~11. ALL Mobs Flee at 25% HP (mob.gd)~~ — FIXED (2026-05-07, AI & Mob Behavior 2nd pass)
Base `should_flee()` now returns `false`. Only specific mob subclasses (Spinner, Succubus, Thief, Bandit, Wraith, Great Crab, Gnoll Trickster) override with custom flee conditions.

### ~~12. Brute Enrages at Wrong Time (brute.gd)~~ — FIXED (2026-05-07, AI & Mob Behavior 2nd pass)
Rewrote Brute to use `_try_prevent_death()` death-prevention mechanic. Now grants HT/2+4 shielding at HP=0 instead of stat boost at 25% HP. Damage changes to NormalIntRange(15,40) while enraged.

### 13. XP Never Caps Based on Hero Level (mob.gd:369-370) — ALREADY FIXED
XP cap was already implemented in `_on_death()`: `if hero_lvl > max_level: pass` skips XP grant. Was logged as unfixed but code was correct.

### ~~14. Mob Turn Cost is Always 1.0 (mob.gd)~~ — FIXED (2026-05-07, AI & Mob Behavior 2nd pass)
Added `attack_delay()`, `spend_move()`, `spend_attack()` methods. Each AI state handler now spends appropriate time: attacks cost `attack_delay()`, movement costs `1/speed()`. Thief.gd updated with `attack_delay() * 0.5` override. Terror/Dread now force FLEEING state before state machine runs.

## Priority 1 — Level Generation (added 2026-05-07)

### ~~15. Mob Count Scales Linearly With Depth (regular_level.gd)~~ — FIXED (2026-05-07, Level Generation 1st pass)
`mob_count()` now uses `3 + (depth % 5) + randi_range(0, 2)` with floor 1 hard-coded to 8.

### ~~16. Floor 1 Only Spawns 3 Mobs Instead of 8 (regular_level.gd)~~ — FIXED (2026-05-07, Level Generation 1st pass)
Floor 1 now returns 8 mobs via `if depth <= 1: return 8`.

### ~~17. CHASM Feeling Can Create Unpassable Levels (caves_level.gd)~~ — FIXED (2026-05-07, Level Generation 1st pass)
CHASM removed from CavesLevel._roll_feeling(). Dead code in standard_painter.gd remains but is unreachable.

### 22. Entrance Mob Safety Zone Used Chebyshev Distance (regular_level.gd) [FIXED]
**Was:** `_near_entrance()` used Chebyshev distance (`max(|dx|,|dy|) < 8`) which doesn't account for walls.
**Fix applied:** Replaced with BFS walkable distance map from entrance (max 8 steps), matching original `PathFinder.buildDistanceMap()` approach.

### 23. Sewer/Prison/Halls Trap Distributions Wrong [FIXED]
**Was:** Each region had only 5 trap types with equal probability. Original has 11-18 weighted types per region.
**Fix applied:** All three regions rewritten to match original weighted trap distributions using available trap classes.

## Priority 2 — UI & HUD (added 2026-05-07)

### 18. WndGame._return_to_title() Missing — Runtime Crash (wnd_game.gd) [FIXED]
**Current:** _on_save_quit() and _on_quit_no_save() both call _return_to_title() which did not exist.
**Impact:** Clicking "Save & Quit" or "Quit Without Saving" in the game menu crashes the game with a method-not-found error. The player cannot gracefully exit a run.
**Fix applied:** Added _return_to_title() that closes the window, loads title_scene.gd, frees GameScene, and adds title scene to root.

### 19. Boss HP Bar Completely Non-Functional (hud.gd) [FIXED]
**Current:** All three boss signal handlers (_on_boss_fight_started, _on_boss_damaged, _on_boss_defeated) were pass.
**Impact:** Boss fights (Goo, Tengu, DM-300, King, Yog) show no HP bar at all. Players have no way to gauge boss health, making these encounters feel broken.
**Fix applied:** Connected handlers to BossHPBar.show_boss(), update_hp(), hide_boss().

## Priority 1 — Audio & Music (added 2026-05-07)

### 20. All Audio is Procedurally Generated — Real SPD Assets Ignored (audio_manager.gd) [FIXED]
**Current:** 14 sounds were procedurally generated via sine/noise/sweep synthesis. 67 real MP3 sound effects and 31 real OGG music tracks in `res://assets/spd/sounds/` and `res://assets/spd/music/` were completely unused.
**Impact:** Every sound in the game is a synthesized approximation instead of the actual SPD audio. Music was limited to a 2-second procedural loop for boss fights. No ambient music anywhere.
**Fix applied:** Rewrote AudioManager to load all real MP3/OGG assets from disk. Procedural generation kept as fallback only. Added SFX_ALIASES for backward compatibility with existing play_sfx() calls.

### 21. No Per-Region Music System (audio_manager.gd, game_scene.gd) [FIXED]
**Current:** Only played procedural "boss_music" on boss depths. All other floors had silence.
**Original:** Each region (sewers/prison/caves/city/halls) has 3 ambient tracks with weighted random selection, a tense track for quest floors, and boss/boss_finale tracks.
**Impact:** The game is silent on all non-boss floors. Music is one of the most atmosphere-defining elements of SPD.
**Fix applied:** Added REGION_TRACKS dictionary, play_region_music() with weighted random pick, crossfade between tracks, and auto-rotation when tracks finish. Updated game_scene.gd to call region music on every level entry.

## Priority 1 — Critical Formula Bugs (added 2026-05-07, Gameplay Mechanics 3rd pass)

### ~~24. Armor DR Computed as Level 99 (armor.gd)~~ — FIXED
**Was:** `dr_roll(hero_str: int = 99)` passed 99 to `dr_min(lvl)` / `dr_max(lvl)`. A tier-1 cloth armor at +0 returned DR max of `1*(2+99)=101` instead of `1*(2+0)=2`. ALL armor was absurdly overpowered — every hit did 0 damage.
**Fix:** Renamed parameter to `lvl_override: int = -1` which falls through to `buffed_lvl()`.

### ~~25. Weapon Damage Formula From Wrong Game (weapon.gd)~~ — FIXED
**Was:** Used old Pixel Dungeon formula `max = (tier²-tier+10)/2 + tier*level`. Current SPD formula is `max = 5*(tier+1) + level*(tier+1)`. At tier 1 +0: Godot=5, SPD=10. At tier 5 +0: Godot=15, SPD=30. **All weapons did ~50% of intended damage.**
**Fix:** Updated formula to match MeleeWeapon.java. Also added proper `damage_roll(owner)` method with NormalIntRange approximation, augment scaling, and excess STR bonus.

**Note:** Bugs 24 and 25 partially cancelled each other out during gameplay — weapons were too weak (50% damage) while armor was too strong (level 99 DR). But they didn't cancel perfectly: armor was far more broken (101 DR on cloth vs 5 max damage), meaning most attacks did 0 damage regardless. The net effect was that combat was nearly non-functional.

## Priority 1 — Items & Equipment (added 2026-05-07)

### ~~26. Generated Items Had No Random Upgrades or Curses (generator.gd)~~ — FIXED
**Was:** Generator called `create_item()` which returned base +0 items with no curse or enchantment. Every weapon/armor/ring in the dungeon was pristine +0.
**Original:** All generated items go through `.random()`: 75% +0, 20% +1, 5% +2. Weapons/armor: 30% cursed (with curse enchant), 10-15% good enchant. Rings: 30% cursed (level set to -1).
**Impact:** The entire strategic layer of finding pre-upgraded or cursed equipment was missing. No risk equipping unidentified gear, no excitement finding a +2 weapon. Fundamental to the roguelike loop.
**Fix:** Added `random()` to Weapon, Armor, Ring classes. Wired Generator to call `.random()` on all generated equipment.

### ~~27. Generator Tier Distribution Was Flat Instead of Weighted (generator.gd)~~ — FIXED
**Was:** Simple `depth/5` with flat 20%/10% adjacent tier chances.
**Original:** `floorSetTierProbs` with specific weighted distributions. E.g., sewers: 75% T1, 20% T2, 4% T3, 1% T4. Allows rare exciting early finds and late-game lower-tier drops.
**Fix:** Added `FLOOR_SET_TIER_PROBS` constant and `_roll_tier_for_depth()` using weighted random selection.

### ~~28. Ring of Might HP Was Flat +5/Level Instead of Multiplicative (ring.gd)~~ — FIXED
**Was:** `MightBuff` added flat `+bonus * 5` HP. At level 1 hero, +1 ring = +5 HP (25% increase!).
**Original:** `HTMultiplier = pow(1.035, bonus)`. At +1: 3.5% HP increase. Scales proportionally with hero level.
**Fix:** Changed to multiplicative `pow(1.035, bonus)` on target's base HT.

### ~~29. Ring of Force Used Flat +2/Level Instead of STR-Based System (ring.gd)~~ — FIXED
**Was:** `ForceBuff.modify_damage()` added flat `+bonus * 2` to weapon damage.
**Original:** Full unarmed combat system. Tier from STR: `max(1, (STR-8)/2)`, damage uses melee weapon formula: `min = tier + lvl`, `max = 5*(tier+1) + lvl*(tier+1)`. At 18 STR +3: damage 8-33.
**Fix:** Rewrote ForceBuff with `_force_tier()`, `_force_min()`, `_force_max()`, `force_damage_roll()`. Armed bonus changed to flat `+bonus`.

### ~~30. Potions/Scrolls Cost 5 Gold Instead of 30 (potion.gd, scroll.gd)~~ — FIXED (2026-05-07, Items 2nd pass)
**Was:** Both classes inherited base Item `value()` returning `5 * (level + 1) = 5`. Shop prices were 6x too low.
**Original:** Both `Potion.value()` and `Scroll.value()` return `30 * quantity`.
**Fix:** Added `value()` override returning `30 * quantity` in both classes.

### ~~31. Potions and Scrolls Were Free Actions (potion.gd, scroll.gd)~~ — FIXED (2026-05-07, Items 2nd pass)
**Was:** No `hero.spend()` call in execute(). Drinking potions and reading scrolls cost zero turns.
**Original:** `TIME_TO_DRINK = 1f` / `TIME_TO_READ = 1f` with `hero.spend()` calls. Using consumables costs 1 full turn.
**Impact:** Players could use unlimited consumables per turn — healing, buffing, teleporting, all as free actions. This is arguably the most exploitable bug in the codebase.
**Fix:** Added time constants and `hero.spend()` calls in both classes' execute() methods.

### ~~32. Strength/Experience Potions and Upgrade Scrolls in Random Drops (generator.gd)~~ — FIXED (2026-05-07, Items 2nd pass)
**Was:** All three special progression items appeared in the random loot tables.
**Original:** `defaultProbs` for strength, experience, and upgrade are all 0. These items are exclusively placed by levelgen.
**Impact:** Random Strength potions break STR progression. Random Upgrade scrolls break item economy (designed for ~15/run). Random Experience potions break leveling curve. All three undermine the carefully balanced progression system.
**Fix:** Removed all three from their respective random tables.

### ~~33. Wand Recharge Was Flat Instead of Scaling (wand.gd)~~ — FIXED (2026-05-07, Items 2nd pass)
**Was:** Flat `recharge_rate = 10.0` turns per charge regardless of current charges.
**Original:** Scaling formula: `turnsToCharge = 10 + 40 * 0.875^missingCharges`. Empty wands recharge fast (~10t), nearly full wands recharge slowly (~50t for last charge).
**Fix:** Implemented full scaling recharge with `BASE_CHARGE_DELAY`, `SCALING_CHARGE_ADDITION`, `NORMAL_SCALE_FACTOR` constants.

### ~~34. Wand/Ring random() Distribution Wrong (wand.gd, ring.gd)~~ — FIXED (2026-05-07, Items 2nd pass)
**Was:** Both used `randi() % 4` (25% chance of first upgrade) instead of `randi() % 3` (33.33%).
**Original:** `Random.Int(3)` — distribution: +0: 66.67%, +1: 26.67%, +2: 5.33%.
**Fix:** Changed both to `randi() % 3`.

## Priority 2 — UI & HUD (added 2026-05-07, UI 2nd pass)

### ~~35. Signal Parameter Mismatch Crashes on Equip (status_pane.gd)~~ — FIXED
**Was:** EventBus emits `item_equipped(item_name: String, slot: String)` but StatusPane handler was `_on_item_equipped(_item: Variant)` — wrong parameter count causes runtime crash when any item is equipped or unequipped.
**Fix:** Updated handler signatures to `_on_item_equipped(_item_name: String, _slot: String)` and `_on_item_unequipped(_item_name: String, _slot: String)`.

### ~~36. No Rest System — Must Press Wait Every Turn to Heal (hero.gd)~~ — FIXED
**Was:** Only single-turn wait existed. No way to continuously rest until healed like in original.
**Original:** Hero.java has `rest(boolean)`: `rest(false)` = single wait, `rest(true)` = continuous rest until full HP or interrupted by enemy/damage.
**Fix:** Added `resting: bool`, `rest(full_rest)`, `interrupt()`. Auto-continues wait while resting. Interrupted by damage, new visible enemies, or any non-wait action. 'R' key binding added to HUD.
