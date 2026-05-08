class_name Balance
extends RefCounted
## Centralized balance reference for Shattered Pixel Dungeon (Godot).
##
## This file documents all scaling constants, formulas, and tuning parameters
## in one place. It does NOT replace the values defined in their respective
## source files — it mirrors them so a designer can see the full picture and
## tweak numbers without hunting through dozens of scripts.
##
## When you change a value here, also update it in the authoritative source
## file listed in the comment. A future pass could make all systems read from
## this file directly.

# =============================================================================
# 1. EXPERIENCE & LEVELING
# =============================================================================

## XP needed to reach the next hero level:
##   xp_for_level(hero_lvl) = 5 + hero_lvl * 5
## Source: constants.gd :: xp_for_level()
## Level 1->2: 10 XP,  Level 10->11: 55 XP,  Level 20->21: 105 XP
const XP_BASE: int = 5
const XP_PER_LEVEL: int = 5
const MAX_HERO_LEVEL: int = 30

## Mob XP values by region (approximate ranges):
##   Sewers (depth 1-5):   1-3 XP   (rat=1, gnoll=2, crab=3, snake=2, slime=2)
##   Prison (depth 6-10):  5-6 XP   (skeleton=5, thief=5, guard=6, necromancer=6)
##   Caves  (depth 11-15): 7-8 XP   (bat=7, brute=8, shaman=7, spinner=7, dm200=8)
##   City   (depth 16-20): 10-11 XP (warlock=10, monk=10, golem=11, elemental=10)
##   Halls  (depth 21-26): 12-14 XP (succubus=12, eye=14, scorpio=13, ripper=12)
## Source: individual mob .gd files

## Mob max_level (hero level at which mob gives 0 XP):
##   rat=5, skeleton=12, bat=17, warlock=22, succubus=27
## Pattern: roughly boss_depth_of_region * 2 + small offset

# =============================================================================
# 2. MOB STAT SCALING
# =============================================================================

## Mob stats follow a consistent curve across regions.
## setup(hp, atk, def, dmg_min, dmg_max, armor, speed)
##
## Reference table (base stats at +0, no buffs):
##
## MOB             | HP  | ATK | DEF | DMG     | ARM | SPD | REGION
## --------------- | --- | --- | --- | ------- | --- | --- | ------
## Rat             |   8 |   8 |   2 | 1-4     |   0 | 1.0 | Sewer
## Gnoll           |  12 |  10 |   3 | 1-6     |   1 | 1.0 | Sewer
## Sewer Crab      |  15 |  12 |   8 | 1-6     |   5 | 1.0 | Sewer
## Snake           |  10 |  10 |   3 | 1-5     |   0 | 1.2 | Sewer
## Slime           |  20 |   8 |   3 | 2-5     |   2 | 0.8 | Sewer
## Skeleton        |  25 |  14 |   7 | 2-10    |   5 | 1.0 | Prison
## Thief           |  18 |  12 |   5 | 1-8     |   3 | 1.5 | Prison
## Guard           |  40 |  16 |   8 | 4-12    |   7 | 1.0 | Prison
## Necromancer     |  22 |  12 |   5 | 3-8     |   3 | 1.0 | Prison
## Bat             |  30 |  18 |  14 | 5-16    |   4 | 1.5 | Caves
## Brute           |  50 |  20 |  10 | 8-20    |   8 | 1.0 | Caves
## Shaman          |  28 |  14 |   8 | 4-10    |   4 | 1.0 | Caves
## Spinner         |  25 |  14 |   8 | 4-12    |   5 | 1.0 | Caves
## DM-200          |  60 |  18 |  12 | 6-18    |  10 | 0.8 | Caves
## Warlock         |  50 |  18 |  10 | 6-14    |   8 | 1.0 | City
## Monk            |  45 |  22 |  14 | 6-14    |   6 | 1.5 | City
## Golem           |  80 |  20 |  10 | 8-18    |  15 | 0.8 | City
## Elemental       |  50 |  18 |  12 | 8-16    |   8 | 1.0 | City
## Succubus        |  60 |  24 |  16 | 12-22   |  10 | 1.3 | Halls
## Evil Eye        |  70 |  28 |  18 | 15-25   |  12 | 1.0 | Halls
## Scorpio         |  55 |  22 |  14 | 10-20   |  10 | 1.0 | Halls
## Ripper Demon    |  50 |  24 |  12 | 12-24   |   8 | 1.5 | Halls
##
## Rough scaling guidelines per region jump:
##   HP:  +50-100%   ATK: +30-50%   DEF: +50-80%
##   DMG: +60-100%   ARM: +40-80%
## Source: src/actors/mobs/<region>/<mob>.gd

# =============================================================================
# 3. HERO STARTING STATS
# =============================================================================

## All heroes start with HP=20, STR=10. Differences are in attack/defense/damage.
##
## CLASS     | HP | STR | ATK | DEF | DMG
## --------- | -- | --- | --- | --- | -------
## Warrior   | 20 |  10 |  11 |   5 | 1-8
## Mage      | 20 |  10 |  10 |   4 | 1-6
## Rogue     | 20 |  10 |  12 |   6 | 1-6
## Huntress  | 20 |  10 |  11 |   5 | 1-6
## Duelist   | 20 |  10 |  12 |   5 | 1-7
##
## Source: src/actors/hero/hero_class_data.gd

# =============================================================================
# 4. WEAPON FORMULAS
# =============================================================================

## Weapon damage (melee):
##   min_damage = tier + level
##   max_damage = (tier^2 - tier + 10) / 2 + tier * level
##
## Strength requirement: 10 + tier * 2 - level
##
## Tier | STR Req | Damage @ +0    | Damage @ +3     | Damage @ +6
## ---- | ------- | -------------- | --------------- | ---------------
##   1  |   12    | 1 to 5         | 4 to 8          | 7 to 11
##   2  |   14    | 2 to 9         | 5 to 15         | 8 to 21
##   3  |   16    | 3 to 14        | 6 to 23         | 9 to 32
##   4  |   18    | 4 to 21        | 7 to 33         | 10 to 45
##   5  |   20    | 5 to 30        | 8 to 45         | 11 to 60
##
## Augment multipliers:
##   SPEED:  delay * 0.67, damage * 0.67
##   DAMAGE: delay * 1.50, damage * 1.33
## Source: src/items/weapons/weapon.gd

# =============================================================================
# 5. ARMOR FORMULAS
# =============================================================================

## Armor damage reduction:
##   base_DR = tier * (2 + level)
##   Actual reduction = random(0..base_DR) per hit
##
## Strength requirement: 10 + tier * 2 - level
##
## Tier | STR Req | DR @ +0 | DR @ +3 | DR @ +6
## ---- | ------- | ------- | ------- | -------
##   1  |   12    |    2    |    5    |    8
##   2  |   14    |    4    |   10    |   16
##   3  |   16    |    6    |   15    |   24
##   4  |   18    |    8    |   20    |   32
##   5  |   20    |   10    |   25    |   40
##
## Augment factors:
##   DEFENSE: armor * 1.33
##   EVASION: armor * 0.67, evasion * 1.33
## Source: src/items/armor/armor.gd

# =============================================================================
# 6. COMBAT FORMULAS
# =============================================================================

## Hit chance: BASE_HIT_CHANCE * (accuracy / evasion) ^ ACC_EVA_EXPONENT
##   BASE_HIT_CHANCE  = 0.5
##   ACC_EVA_EXPONENT = 0.5
##   MIN_HIT_CHANCE   = 0.1 (floor)
##   MAX_HIT_CHANCE   = 1.0 (ceiling)
##
## Damage calculation:
##   1. Roll damage in weapon [min, max] range
##   2. Roll armor reduction in [0, defender_armor] range
##   3. Final damage = max(0, raw_damage - armor_roll)
##
## Surprise attack multiplier: 1.5x
## Critical strike multiplier: 1.5x (Gladiator combo finisher)
## Source: src/autoloads/constants.gd

const COMBAT_BASE_HIT: float = 0.5
const COMBAT_ACC_EVA_EXP: float = 0.5
const COMBAT_MIN_HIT: float = 0.1
const COMBAT_SURPRISE_MULTI: float = 1.5
const COMBAT_CRIT_MULTI: float = 1.5

# =============================================================================
# 7. HUNGER & FOOD
# =============================================================================

## Hunger drains at HUNGER_STEP (10) per normal-speed turn.
## MAX_HUNGER = 450, so a full stomach lasts ~45 turns.
## At hunger = 0, hero takes STARVING_DAMAGE (1) per turn.
##
## Food values (hunger restored):
##   Food Ration:      hunger fully restored (450)
##   Pasty:            hunger fully restored (450)
##   Small Ration:     hunger partially restored (~225)
##   Overpriced Ration: hunger fully restored (450), costs more gold
##   Mystery Meat:     hunger partially restored (~150), random side effect
##   Frozen Carpaccio: hunger partially restored (~150), random positive buff
##   Meat Pie:         hunger fully restored (450), bonus healing
##
## Average food ration spawn rate: ~1 per 4-5 floors via loot tables
## Source: src/autoloads/constants.gd, src/items/food/food.gd

const HUNGER_MAX: float = 450.0
const HUNGER_PER_TURN: float = 10.0
const STARVING_DAMAGE: int = 1
const FOOD_RATION_VALUE: float = 450.0

# =============================================================================
# 8. GOLD & ITEM PRICES
# =============================================================================

## Gold drop amounts scale with depth:
##   Approximate gold per drop = randi_range(depth * 2, depth * 5)
##   (Actual implementation via Gold item quantity on generation)
##
## Item sale values (base, before level/enchant modifiers):
##   Weapons: 20 * tier * (1 + level), enchanted * 1.5
##   Armor:   10 * tier * (1 + level), glyphed * 1.5
##   Potions: ~30 gold
##   Scrolls: ~30 gold
##   Rings:   ~75 gold
##   Wands:   ~75 gold
##   Artifacts: ~100 gold
##
## Shop buy price = item.value()
## Shop sell price = item.value() / 2  (player sells at half)
## Source: src/items/weapons/weapon.gd, src/items/armor/armor.gd

const SHOP_SELL_FRACTION: float = 0.5

# =============================================================================
# 9. STRENGTH REQUIREMENT SCALING
# =============================================================================

## Both weapons and armor use the same formula:
##   str_req = 10 + tier * 2 - level
##   Minimum str_req for weapons: 10
##   Minimum str_req for armor:   1
##
## Potions of Strength grant +1 STR each.
## There are 2 guaranteed strength potions per region (10 total for a full run).
## Hero starts at STR 10, can reach ~20 STR by depth 25.
##
## Tier | Base STR | After +3 upgrade | After +6 upgrade
## ---- | -------- | ---------------- | ----------------
##   1  |   12     |        9         |        6
##   2  |   14     |       11         |        8
##   3  |   16     |       13         |       10
##   4  |   18     |       15         |       12
##   5  |   20     |       17         |       14

# =============================================================================
# 10. HEALING & REGENERATION
# =============================================================================

## Natural regeneration: ~1 HP per 10 turns (handled by Regeneration buff)
## Potion of Healing: restores 30% of max HP + 1 per hero level
## Dewdrop: heals 1-3 HP on pickup (from trampled high grass)
## Sungrass seed: heals ~1 HP/turn for 20 turns when planted
## Blessed Ankh: full HP restore on death (one-time)
## Unblessed Ankh: revive at 1 HP, lose all items
##
## Healing potion spawn rate: ~1 per 3-4 floors on average

const REGEN_RATE_TURNS: int = 10  # 1 HP per this many turns
const HEALING_POTION_PCT: float = 0.30  # fraction of max HP restored

# =============================================================================
# 11. BUFF/DEBUFF DURATIONS
# =============================================================================

## Standard durations (in turns) for common buffs/debuffs:
##   Burning:      8 turns,  1-3 damage/turn
##   Poison:       varies,   1 damage/turn (stacks via duration extension)
##   Paralysis:    5 turns
##   Invisibility: 15 turns  (or until attack)
##   Blindness:    10 turns
##   Weakness:     10 turns  (-2 STR)
##   Cripple:      10 turns  (halved move speed)
##   Bleeding:     5 turns,  1 damage/turn (decreasing)
##   Haste:        20 turns  (2x move speed)
##   Levitation:   20 turns  (ignore terrain hazards)
##   Mind Vision:  20 turns  (see all characters)
##   Fury:         permanent while HP < 50% (Warrior)
##   Charm:        5 turns   (cannot attack source)
##   Terror:       10 turns  (forced flee from source)
##   Amok:         5 turns   (attack nearest)

# =============================================================================
# 12. BOSS PARAMETERS
# =============================================================================

## Boss depths: 5, 10, 15, 20, 25
##
## GOO (depth 5):
##   HP=100, ATK=12, DEF=4, DMG=3-12, ARM=2
##   Pump-up: charges for 1 turn, then deals 2x damage next hit
##   Heals 3 HP/turn while standing in water
##
## TENGU (depth 10):
##   HP=120, ATK=14, DEF=6, DMG=4-10, ARM=5
##   Phase 1: teleports + throws shuriken (4-8 dmg)
##   Phase 2 (below 50% HP): faster teleport, more shuriken
##
## DM-300 (depth 15):
##   HP=200, ATK=20, DEF=10, DMG=10-24, ARM=12
##   Toxic gas vent, charge attack, pylon heal mechanic
##
## DWARF KING (depth 20):
##   HP=250, ATK=22, DEF=12, DMG=12-28, ARM=14
##   3 phases, summons undead waves between phases
##
## YOG-DZEWA (depth 25):
##   HP=300, ATK=0, DEF=20, DMG=0-0, ARM=20
##   Stationary, spawns Rotting Fist + Burning Fist
##   Laser beam attack in line of sight

# =============================================================================
# 13. LOOT GENERATION WEIGHTS
# =============================================================================

## Category weights for random loot drops (higher = more common):
##   Gold:     16    Potion:   12    Scroll:   12
##   Weapon:    8    Food:      6    Armor:     6
##   Stone:     6    Seed:      4    Ring:      2
##   Wand:      2    Artifact:  1    Misc:      1
##
## Total weight: 76
## Gold chance:     ~21%
## Potion chance:   ~16%
## Scroll chance:   ~16%
## Equipment:       ~18% (weapon + armor)
## Consumable misc: ~21% (food + stone + seed)
## Rare:            ~8%  (ring + wand + artifact + misc)
## Source: src/items/generator.gd

# =============================================================================
# 14. DEPTH & REGION MAPPING
# =============================================================================

## Depths 1-5:   Sewers       (T1 gear, weakest mobs)
## Depths 6-10:  Prison       (T2 gear, moderate mobs)
## Depths 11-15: Caves        (T3 gear, tough mobs)
## Depths 16-20: Dwarf City   (T4 gear, strong mobs)
## Depths 21-26: Demon Halls  (T5 gear, deadliest mobs)
## MAX_DEPTH = 26
##
## Weapon/armor tier matches region number (1-indexed).
## Gear generated is typically current region tier, with small chance of +/-1 tier.
