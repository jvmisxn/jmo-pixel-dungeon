class_name ConstantsData
extends Node
## Game-wide constants mirroring Shattered Pixel Dungeon's core definitions.

# --- Level Dimensions ---
const WIDTH: int = 32
const HEIGHT: int = 32
const LENGTH: int = WIDTH * HEIGHT  # 1024 cells per level

# --- Depth Limits ---
const MAX_DEPTH: int = 26
const BOSS_DEPTHS: Array[int] = [5, 10, 15, 20, 25]

# --- Game Regions ---
enum Region {
	SEWERS,
	PRISON,
	CAVES,
	CITY,
	HALLS,
}

## Returns which region a given depth belongs to.
static func region_for_depth(depth: int) -> Region:
	if depth <= 5:
		return Region.SEWERS
	elif depth <= 10:
		return Region.PRISON
	elif depth <= 15:
		return Region.CAVES
	elif depth <= 20:
		return Region.CITY
	else:
		return Region.HALLS

## Returns the region name as a display string.
static func region_name(region: Region) -> String:
	match region:
		Region.SEWERS:  return "Sewers"
		Region.PRISON:  return "Prison"
		Region.CAVES:   return "Caves"
		Region.CITY:    return "Dwarf City"
		Region.HALLS:   return "Demon Halls"
	return "Unknown"

# --- Terrain Types ---
enum Terrain {
	CHASM,
	EMPTY,
	GRASS,
	EMPTY_WELL,
	WALL,
	DOOR,
	OPEN_DOOR,
	ENTRANCE,
	EXIT,
	EMBERS,
	LOCKED_DOOR,
	CRYSTAL_DOOR,
	PEDESTAL,
	WALL_DECO,
	BARRICADE,
	EMPTY_SP,
	HIGH_GRASS,
	FURROWED_GRASS,
	SECRET_DOOR,
	SECRET_TRAP,
	TRAP,
	INACTIVE_TRAP,
	WATER,
	SIGN,
	WELL,
	STATUE,
	STATUE_SP,
	BOOKSHELF,
	ALCHEMY,
	WEB,
}

## Returns true if the terrain type is "solid" — blocks knockback and
## push effects. Note: DOOR is both PASSABLE and SOLID in the original
## (heroes/mobs can walk through, but objects can't be pushed through).
static func terrain_is_solid(terrain: Terrain) -> bool:
	match terrain:
		Terrain.WALL, Terrain.WALL_DECO, Terrain.DOOR, Terrain.LOCKED_DOOR, \
		Terrain.CRYSTAL_DOOR, Terrain.BARRICADE, Terrain.BOOKSHELF, \
		Terrain.SECRET_DOOR, Terrain.STATUE, Terrain.STATUE_SP, \
		Terrain.ALCHEMY:
			return true
	return false

## Returns true if the terrain type blocks vision (LOS_BLOCKING flag).
## Matches the original SPD Terrain.java flags exactly.
static func terrain_blocks_vision(terrain: Terrain) -> bool:
	match terrain:
		Terrain.WALL, Terrain.WALL_DECO, Terrain.LOCKED_DOOR, \
		Terrain.BARRICADE, Terrain.BOOKSHELF, \
		Terrain.SECRET_DOOR, Terrain.DOOR, \
		Terrain.HIGH_GRASS:
			return true
	return false

## Returns true if the terrain is passable (can be walked on).
## Note: DOOR is both passable AND solid in the original (heroes walk through
## but knockback is blocked). So passable != !solid.
static func terrain_is_passable(terrain: Terrain) -> bool:
	match terrain:
		Terrain.EMPTY, Terrain.GRASS, Terrain.EMPTY_WELL, Terrain.WATER, \
		Terrain.DOOR, Terrain.OPEN_DOOR, Terrain.ENTRANCE, Terrain.EXIT, \
		Terrain.EMBERS, Terrain.PEDESTAL, Terrain.EMPTY_SP, \
		Terrain.HIGH_GRASS, Terrain.FURROWED_GRASS, Terrain.INACTIVE_TRAP, \
		Terrain.TRAP, Terrain.SECRET_TRAP, Terrain.SIGN, Terrain.WELL, \
		Terrain.ALCHEMY, Terrain.WEB:
			return true
	return false

## Returns true if the terrain is a door variant that can be opened.
static func terrain_is_door(terrain: Terrain) -> bool:
	match terrain:
		Terrain.DOOR, Terrain.LOCKED_DOOR, Terrain.CRYSTAL_DOOR, Terrain.SECRET_DOOR:
			return true
	return false

# --- Hero Classes ---
enum HeroClass {
	WARRIOR,
	MAGE,
	ROGUE,
	HUNTRESS,
	DUELIST,
}

## Hero subclasses. Each hero class has two subclass options unlocked at level 6.
enum HeroSubclass {
	NONE,
	# Warrior
	BERSERKER,
	GLADIATOR,
	# Mage
	BATTLEMAGE,
	WARLOCK,
	# Rogue
	ASSASSIN,
	FREERUNNER,
	# Huntress
	SNIPER,
	WARDEN,
	# Duelist
	CHAMPION,
	MONK,
}

## Returns the two subclass choices available for a given hero class.
static func subclasses_for(hero_class: HeroClass) -> Array[HeroSubclass]:
	match hero_class:
		HeroClass.WARRIOR:
			return [HeroSubclass.BERSERKER, HeroSubclass.GLADIATOR]
		HeroClass.MAGE:
			return [HeroSubclass.BATTLEMAGE, HeroSubclass.WARLOCK]
		HeroClass.ROGUE:
			return [HeroSubclass.ASSASSIN, HeroSubclass.FREERUNNER]
		HeroClass.HUNTRESS:
			return [HeroSubclass.SNIPER, HeroSubclass.WARDEN]
		HeroClass.DUELIST:
			return [HeroSubclass.CHAMPION, HeroSubclass.MONK]
	return [HeroSubclass.NONE]

# --- Item Categories ---
enum ItemCategory {
	WEAPON,
	ARMOR,
	WAND,
	RING,
	ARTIFACT,
	POTION,
	SCROLL,
	STONE,
	SEED,
	FOOD,
	GOLD,
	MISC,
}

# --- Direction Constants (cell offsets in a flat array) ---
const DIR_N: int  = -WIDTH
const DIR_S: int  = WIDTH
const DIR_W: int  = -1
const DIR_E: int  = 1
const DIR_NW: int = -WIDTH - 1
const DIR_NE: int = -WIDTH + 1
const DIR_SW: int = WIDTH - 1
const DIR_SE: int = WIDTH + 1

## All 8 directional offsets for neighbor lookup.
const DIRS_8: Array[int] = [DIR_N, DIR_NE, DIR_E, DIR_SE, DIR_S, DIR_SW, DIR_W, DIR_NW]
## Cardinal 4 directional offsets.
const DIRS_4: Array[int] = [DIR_N, DIR_E, DIR_S, DIR_W]

# --- Combat Formula Constants ---
## Base accuracy for a standard attack (before modifiers).
const BASE_HIT_CHANCE: float = 0.5
## Minimum hit chance floor so attacks always have some chance.
const MIN_HIT_CHANCE: float = 0.1
## Maximum hit chance ceiling.
const MAX_HIT_CHANCE: float = 1.0
## Accuracy vs evasion exponent used in the hit formula.
const ACC_EVA_EXPONENT: float = 0.5
## Armor roll is uniform in [0, armor_value]. Damage reduced by roll result.
const ARMOR_REDUCTION_MIN: float = 0.0
## Damage cannot be reduced below this fraction of original by armor.
const MIN_DAMAGE_FRACTION: float = 0.0
## Surprise attack damage multiplier.
const SURPRISE_ATTACK_MULTI: float = 1.5
## Critical strike damage multiplier (Gladiator combo finisher, etc.).
const CRIT_MULTI: float = 1.5

## Hunger constants
const MAX_HUNGER: float = 450.0
const HUNGER_STEP: float = 1.0  # hunger gained per turn (starve after ~450 turns)
const STARVING_DAMAGE: int = 1

## Experience per hero level: XP needed = 5 + hero_lvl * 5
static func xp_for_level(hero_lvl: int) -> int:
	return 5 + hero_lvl * 5

## Max hero level.
const MAX_HERO_LEVEL: int = 30

## View distance for FOV calculation.
const VIEW_DISTANCE: int = 8

# --- Utility ---

## Convert flat index to grid x coordinate.
static func pos_to_x(pos: int) -> int:
	return pos % WIDTH

## Convert flat index to grid y coordinate.
static func pos_to_y(pos: int) -> int:
	@warning_ignore("integer_division")
	return pos / WIDTH

## Convert grid coordinates to flat index.
static func xy_to_pos(x: int, y: int) -> int:
	return y * WIDTH + x

## Check if a position is within the valid map bounds.
static func is_valid_pos(pos: int) -> bool:
	return pos >= 0 and pos < LENGTH


# --- Alignment ---
enum Alignment {
	ENEMY,
	NEUTRAL,
	ALLY,
}

# --- Utility: Safe property access ---
## Safely get a property from any object/dictionary, returning default if not found.
## This avoids crashes when duck-typing items, mobs, etc.
static func get_prop(obj: Variant, prop_name: String, default_val: Variant = null) -> Variant:
	if obj == null:
		return default_val
	if obj is Dictionary:
		return obj.get(prop_name, default_val)
	if obj is Object and obj.has_method("get"):
		var val: Variant = obj.get(prop_name)
		if val != null:
			return val
	return default_val
