class_name Generator
extends RefCounted
## Loot generation system. Produces random items appropriate for a given
## dungeon depth, using weighted category selection and tiered sub-tables.
##
## All item creation goes through create_item(item_id) which delegates to
## the proper specialized class factory (MeleeWeapon.create, Potion.create, etc.).
## This is the single factory entry point for the entire item system.

# ---------------------------------------------------------------------------
# Category Weights (approximate Shattered PD distribution)
# ---------------------------------------------------------------------------

## Weights for random_item category selection. Higher = more common.
const CATEGORY_WEIGHTS: Dictionary = {
	ConstantsData.ItemCategory.GOLD:     16,
	ConstantsData.ItemCategory.POTION:   12,
	ConstantsData.ItemCategory.SCROLL:   12,
	ConstantsData.ItemCategory.FOOD:     6,
	ConstantsData.ItemCategory.WEAPON:   8,
	ConstantsData.ItemCategory.ARMOR:    6,
	ConstantsData.ItemCategory.STONE:    6,
	ConstantsData.ItemCategory.SEED:     4,
	ConstantsData.ItemCategory.RING:     2,
	ConstantsData.ItemCategory.WAND:     2,
	ConstantsData.ItemCategory.ARTIFACT: 1,
	ConstantsData.ItemCategory.MISC:     1,
}

# ---------------------------------------------------------------------------
# Item Tables — IDs match the specialized class factories
# ---------------------------------------------------------------------------

## Tier-1 melee weapons (sewers, depths 1-5).
const WEAPONS_T1: Array[String] = [
	"worn_shortsword", "cudgel", "gloves", "rapier", "dagger",
]
## Tier-2 melee weapons (prison, depths 6-10).
const WEAPONS_T2: Array[String] = [
	"shortsword", "hand_axe", "spear", "quarterstaff", "dirk",
]
## Tier-3 melee weapons (caves, depths 11-15).
const WEAPONS_T3: Array[String] = [
	"sword", "mace", "scimitar", "round_shield", "sai",
]
## Tier-4 melee weapons (city, depths 16-20).
const WEAPONS_T4: Array[String] = [
	"longsword", "battle_axe", "flail", "runic_blade", "assassins_blade",
]
## Tier-5 melee weapons (halls, depths 21-26).
const WEAPONS_T5: Array[String] = [
	"greatsword", "war_hammer", "glaive", "greataxe", "greatshield",
]

## Missile / thrown weapons per tier.
const MISSILES_T1: Array[String] = ["throwing_stone", "throwing_knife", "throwing_club"]
const MISSILES_T2: Array[String] = ["shuriken", "kunai", "bolas"]
const MISSILES_T3: Array[String] = ["javelin", "tomahawk", "boomerang"]
const MISSILES_T4: Array[String] = ["trident", "heavy_boomerang"]
const MISSILES_T5: Array[String] = ["force_cudgel"]

## Armor per tier.
const ARMORS_T1: Array[String] = ["cloth_armor"]
const ARMORS_T2: Array[String] = ["leather_armor"]
const ARMORS_T3: Array[String] = ["mail_armor"]
const ARMORS_T4: Array[String] = ["scale_armor"]
const ARMORS_T5: Array[String] = ["plate_armor"]

## Potions — short IDs matching Potion.create().
## NOTE: "strength" and "experience" are excluded from random drops (prob 0 in original).
## They are placed deliberately by level generation, not randomly generated.
const POTIONS: Array[String] = [
	"healing", "mind_vision", "frost", "liquid_flame",
	"toxic_gas", "paralytic_gas", "levitation", "invisibility",
	"purity", "haste",
]

## Potion weights matching original defaultProbs (excluding strength=0 and experience=0).
## healing:3, mind_vision:2, frost:1, liquid_flame:2, toxic_gas:1,
## paralytic_gas:1, levitation:1, invisibility:1, purity:1, haste:1
const POTION_WEIGHTS: Array[int] = [3, 2, 1, 2, 1, 1, 1, 1, 1, 1]

## Scrolls — short IDs matching Scroll.create().
## NOTE: "upgrade" is excluded from random drops (prob 0 in original).
## It is placed deliberately by level generation (3 per chapter).
const SCROLLS: Array[String] = [
	"identify", "remove_curse", "magic_mapping",
	"teleportation", "lullaby", "rage", "terror", "mirror_image",
	"retribution", "transmutation", "recharging",
]

## Scroll weights matching original defaultProbs (excluding upgrade=0).
## identify:3, remove_curse:2, magic_mapping:1, teleportation:1, lullaby:1,
## rage:1, terror:1, mirror_image:1, retribution:1, transmutation:1, recharging:2
const SCROLL_WEIGHTS: Array[int] = [3, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2]

## Rings — full IDs matching Ring.create().
const RINGS: Array[String] = [
	"ring_of_accuracy", "ring_of_elements", "ring_of_energy",
	"ring_of_evasion", "ring_of_force", "ring_of_furor",
	"ring_of_haste", "ring_of_might", "ring_of_sharpshooting",
	"ring_of_tenacity", "ring_of_wealth",
]

## Wands — full IDs matching Wand.create().
const WANDS: Array[String] = [
	"wand_of_magic_missile", "wand_of_fire_bolt", "wand_of_frost",
	"wand_of_lightning", "wand_of_disintegration", "wand_of_corrosion",
	"wand_of_living_earth", "wand_of_blast_wave", "wand_of_prismatic_light",
	"wand_of_warding", "wand_of_transfusion", "wand_of_corruption",
	"wand_of_regrowth",
]

## Artifacts — IDs matching Artifact.create().
const ARTIFACTS: Array[String] = [
	"cape_of_thorns", "chalice_of_blood", "cloak_of_shadows",
	"dried_rose", "ethereal_chains", "horn_of_plenty",
	"master_thieves_armband", "sandals_of_nature", "talisman_of_foresight",
	"timekeeper_hourglass", "unstable_spellbook", "alchemists_toolkit",
]

## Seeds.
const SEEDS: Array[String] = [
	"seed_of_firebloom", "seed_of_icecap", "seed_of_sorrowmoss",
	"seed_of_stormvine", "seed_of_sungrass", "seed_of_earthroot",
	"seed_of_fadeleaf", "seed_of_rotberry", "seed_of_blindweed",
	"seed_of_dreamfoil", "seed_of_starflower", "seed_of_swiftthistle",
]

## Stones — short IDs matching Stone.create().
const STONES: Array[String] = [
	"enchantment", "augmentation", "intuition", "blast", "blink",
	"clairvoyance", "deepened_sleep", "disarming", "fear", "flock", "shock",
]

## Food — short IDs matching Food.create().
const FOODS: Array[String] = [
	"ration", "pasty", "mystery_meat",
]

## Bombs — IDs matching Bomb.create().
const BOMBS: Array[String] = [
	"bomb", "fire_bomb", "frost_bomb", "holy_bomb", "wooly_bomb",
	"noisemaker", "flashbang", "shock_bomb", "regrowth_bomb", "arcane_bomb",
]

## Spells — IDs matching Spell.create().
const SPELLS: Array[String] = [
	"phase_shift", "wild_energy", "aqua_blast", "feather_fall",
	"recycle", "alchemize", "curse_infusion", "reclaim_trap", "summon_elemental",
]

## Keys — IDs matching Key.create().
const KEYS: Array[String] = [
	"iron_key", "golden_key", "crystal_key", "skeleton_key",
]

## Bags — IDs matching Bag.create().
const BAGS: Array[String] = [
	"velvet_pouch", "scroll_holder", "potion_bandolier", "magical_holster",
]

# ---------------------------------------------------------------------------
# Floor-Set Tier Probabilities (matching original Generator.java)
# ---------------------------------------------------------------------------

## Probability weights for each tier (1-5) based on floor set (depth / 5).
## floorSetTierProbs[floorSet] = [t1%, t2%, t3%, t4%, t5%]
## Original: {0,75,20,4,1}, {0,25,50,20,5}, {0,0,40,50,10}, {0,0,20,40,40}, {0,0,0,20,80}
const FLOOR_SET_TIER_PROBS: Array = [
	[0, 75, 20, 4, 1],    # Floor set 0 (depths 1-5): mostly T1
	[0, 25, 50, 20, 5],   # Floor set 1 (depths 6-10): mostly T2
	[0, 0, 40, 50, 10],   # Floor set 2 (depths 11-15): mostly T3
	[0, 0, 20, 40, 40],   # Floor set 3 (depths 16-20): mostly T4
	[0, 0, 0, 20, 80],    # Floor set 4 (depths 21+): mostly T5
]

# ---------------------------------------------------------------------------
# Artifact Uniqueness Tracking
# ---------------------------------------------------------------------------

## Artifacts that have already been generated this run (only one of each).
static var _generated_artifacts: Array[String] = []

## Reset artifact tracking (call at start of new run).
static func reset_artifacts() -> void:
	_generated_artifacts.clear()

# ---------------------------------------------------------------------------
# Factory — create_item
# ---------------------------------------------------------------------------

## Master factory method. Given an item_id string, instantiate the correct
## specialized class via its factory and return it.
##
## Uses known-ID sets for dispatch to avoid false matches from factories
## that always return non-null objects.
static func create_item(item_id: String) -> Item:
	var result: Item = _create_item_internal(item_id)
	# Apply SPD sprite sheet index if available
	if result != null and SPRITE_INDICES.has(result.item_id):
		result.sprite_index = SPRITE_INDICES[result.item_id]
	if result != null and ItemAppearance:
		ItemAppearance.apply_appearance(result)
	if result != null and ItemCatalog:
		ItemCatalog.apply_knowledge(result)
	return result


## Internal factory dispatch — returns the item without sprite_index applied.
static func _create_item_internal(item_id: String) -> Item:
	# --- Gold ---
	if item_id == "gold":
		return Gold.new()

	# --- Misc single items ---
	match item_id:
		"spirit_bow":
			return SpiritBow.new()
		"dewdrop":
			return Dewdrop.new()
		"ankh":
			return Ankh.new()
		"torch":
			return Torch.new()
		"amulet_of_yendor":
			return AmuletOfYendor.new()

	# --- Melee Weapons (known IDs) ---
	if item_id in _MELEE_IDS:
		return MeleeWeapon.create(item_id)

	# --- Missile Weapons (known IDs) ---
	if item_id in _MISSILE_IDS:
		return MissileWeapon.create(item_id)

	# --- Armor (known IDs) ---
	if item_id in _ARMOR_IDS:
		return Armor.create(item_id)

	# --- Potions (known IDs) ---
	if item_id in _POTION_IDS:
		return Potion.create(item_id)

	# --- Scrolls (known IDs) ---
	if item_id in _SCROLL_IDS:
		return Scroll.create(item_id)

	# --- Rings (known IDs) ---
	if item_id in RINGS:
		return Ring.create(item_id)

	# --- Wands (known IDs) ---
	if item_id in WANDS:
		return Wand.create(item_id)

	# --- Artifacts (known IDs) ---
	if item_id in ARTIFACTS:
		return Artifact.create(item_id)

	# --- Food (known IDs) ---
	if item_id in _FOOD_IDS:
		return Food.create(item_id)

	# --- Bombs (known IDs) ---
	if item_id in BOMBS:
		return Bomb.create(item_id)

	# --- Stones (known IDs) ---
	if item_id in STONES:
		return Stone.create(item_id)

	# --- Spells (known IDs) ---
	if item_id in SPELLS:
		return Spell.create(item_id)

	# --- Keys (known IDs) ---
	if item_id in KEYS:
		return Key.create(item_id)

	# --- Bags (known IDs) ---
	if item_id in BAGS:
		return Bag.create(item_id)

	# --- Seeds (generic Item for now — plants system built in Phase 6) ---
	if item_id.begins_with("seed_of_"):
		return _make_seed(item_id)

	# Fallback — unknown item_id, create a generic item.
	push_warning("Generator: Unknown item_id '%s', creating generic Item." % item_id)
	var generic: Item = Item.new()
	generic.item_id = item_id
	generic.item_name = item_id.replace("_", " ").capitalize()
	return generic

# ---------------------------------------------------------------------------
# Known ID sets for safe dispatch (avoids false matches from non-null factories)
# ---------------------------------------------------------------------------

const _MELEE_IDS: Array[String] = [
	"worn_shortsword", "cudgel", "gloves", "rapier", "dagger",
	"shortsword", "hand_axe", "spear", "quarterstaff", "dirk",
	"sword", "mace", "scimitar", "round_shield", "sai",
	"longsword", "battle_axe", "flail", "runic_blade", "assassins_blade",
	"greatsword", "war_hammer", "glaive", "greataxe", "greatshield",
]

const _MISSILE_IDS: Array[String] = [
	"throwing_knife", "throwing_club", "throwing_stone",
	"shuriken", "kunai", "bolas",
	"javelin", "tomahawk", "boomerang",
	"trident", "heavy_boomerang",
	"force_cudgel",
]

const _ARMOR_IDS: Array[String] = [
	"cloth_armor", "leather_armor", "mail_armor", "scale_armor", "plate_armor",
]

const _POTION_IDS: Array[String] = [
	"healing", "strength", "mind_vision", "frost", "liquid_flame",
	"toxic_gas", "paralytic_gas", "levitation", "invisibility",
	"purity", "experience", "haste", "divine_inspiration", "mastery",
]

const _SCROLL_IDS: Array[String] = [
	"upgrade", "identify", "remove_curse", "magic_mapping",
	"teleportation", "lullaby", "rage", "terror", "mirror_image",
	"retribution", "transmutation", "recharging", "enchantment", "divination",
]

const _FOOD_IDS: Array[String] = [
	"ration", "pasty", "mystery_meat", "overpriced_ration",
	"small_ration", "frozen_carpaccio", "meat_pie",
]

# ---------------------------------------------------------------------------
# Seed Helper (plants system is Phase 6, seeds are basic Items for now)
# ---------------------------------------------------------------------------

## Seed color lookup.
const SEED_COLORS: Dictionary = {
	"seed_of_firebloom": Color(0.9, 0.4, 0.1),
	"seed_of_icecap": Color(0.4, 0.7, 1.0),
	"seed_of_sorrowmoss": Color(0.3, 0.7, 0.3),
	"seed_of_stormvine": Color(0.6, 0.6, 0.9),
	"seed_of_sungrass": Color(0.7, 0.8, 0.2),
	"seed_of_earthroot": Color(0.5, 0.4, 0.2),
	"seed_of_fadeleaf": Color(0.6, 0.7, 0.5),
	"seed_of_rotberry": Color(0.5, 0.3, 0.4),
	"seed_of_blindweed": Color(0.4, 0.5, 0.3),
	"seed_of_dreamfoil": Color(0.6, 0.5, 0.8),
	"seed_of_starflower": Color(0.9, 0.9, 0.4),
	"seed_of_swiftthistle": Color(0.8, 0.6, 0.7),
}

static func _make_seed(id: String) -> Item:
	var item: Item = Item.new()
	item.item_id = id
	var seed_name: String = id.replace("seed_of_", "").replace("_", " ").capitalize()
	item.item_name = "Seed of %s" % seed_name
	item.description = "A magical seed that can be planted or used in alchemy."
	item.category = ConstantsData.ItemCategory.SEED
	item.icon_color = SEED_COLORS.get(id, Color(0.5, 0.7, 0.3))
	item.default_action = "PLANT"
	item.stackable = true
	item.quantity = 1
	item.identified = true
	item.cursed_known = true
	return item

# ---------------------------------------------------------------------------
# Random Generation — Public API
# ---------------------------------------------------------------------------

## Weighted random category selection using CATEGORY_WEIGHTS.
static func _weighted_category() -> ConstantsData.ItemCategory:
	var total_weight: float = 0.0
	for w: int in CATEGORY_WEIGHTS.values():
		total_weight += w
	var roll: float = randf() * total_weight
	for cat: ConstantsData.ItemCategory in CATEGORY_WEIGHTS:
		roll -= CATEGORY_WEIGHTS[cat]
		if roll <= 0.0:
			return cat
	# Fallback (should not reach here)
	return ConstantsData.ItemCategory.GOLD

## Generate a random item appropriate for the given dungeon depth.
static func random_item(depth: int) -> Item:
	var category: ConstantsData.ItemCategory = _weighted_category()
	match category:
		ConstantsData.ItemCategory.GOLD:
			return random_gold(depth)
		ConstantsData.ItemCategory.POTION:
			return random_potion()
		ConstantsData.ItemCategory.SCROLL:
			return random_scroll()
		ConstantsData.ItemCategory.FOOD:
			return random_food()
		ConstantsData.ItemCategory.WEAPON:
			# 50/50 melee vs missile
			if randf() < 0.5:
				return random_weapon(depth)
			else:
				return random_missile(depth)
		ConstantsData.ItemCategory.ARMOR:
			return random_armor(depth)
		ConstantsData.ItemCategory.STONE:
			return random_stone()
		ConstantsData.ItemCategory.SEED:
			return random_seed()
		ConstantsData.ItemCategory.RING:
			return random_ring()
		ConstantsData.ItemCategory.WAND:
			return random_wand()
		ConstantsData.ItemCategory.ARTIFACT:
			return random_artifact()
		ConstantsData.ItemCategory.MISC:
			# Misc falls back to a random stone or seed
			if randf() < 0.5:
				return random_stone()
			else:
				return random_seed()
	return random_gold(depth)

## Generate a random melee weapon whose tier is based on depth.
## Uses floorSetTierProbs for tier selection and calls random() for upgrades/curses.
static func random_weapon(depth: int) -> Item:
	var tier: int = _roll_tier_for_depth(depth)
	var table: Array[String] = _weapon_table_for_tier(tier)
	var weapon: Item = _random_from_table(table)
	if weapon is Weapon and weapon.has_method("random"):
		weapon.random()
	return weapon

## Generate a random armor whose tier is based on depth.
## Uses floorSetTierProbs for tier selection and calls random() for upgrades/curses.
static func random_armor(depth: int) -> Item:
	var tier: int = _roll_tier_for_depth(depth)
	var table: Array[String] = _armor_table_for_tier(tier)
	var armor: Item = _random_from_table(table)
	if armor is Armor and armor.has_method("random"):
		armor.random()
	return armor

## Generate a random potion using weighted probabilities matching original.
static func random_potion() -> Item:
	return _weighted_random_from_table(POTIONS, POTION_WEIGHTS)

## Generate a random scroll using weighted probabilities matching original.
static func random_scroll() -> Item:
	return _weighted_random_from_table(SCROLLS, SCROLL_WEIGHTS)

## Generate a random ring with random upgrade/curse.
static func random_ring() -> Item:
	var ring: Item = _random_from_table(RINGS)
	if ring is Ring and ring.has_method("random"):
		ring.random()
	return ring

## Generate a random wand with random upgrade/curse.
## Uses Wand.random() if available, matching original distribution:
## +0: 66.67% (2/3), +1: 26.67% (4/15), +2: 6.67% (1/15). 30% cursed.
static func random_wand() -> Item:
	var wand: Item = _random_from_table(WANDS)
	if wand is Wand and wand.has_method("random"):
		wand.random()
	else:
		# Fallback: apply manually with correct distribution
		var n: int = 0
		if randi() % 3 == 0:  # 33% chance for +1 (was % 4 = 25%, wrong)
			n += 1
			if randi() % 5 == 0:
				n += 1
		wand.level = n
		if randf() < 0.3:
			wand.cursed = true
	return wand

## Generate a random artifact (respects uniqueness — won't re-generate one already given).
static func random_artifact() -> Item:
	var available: Array[String] = []
	for art_id: String in ARTIFACTS:
		if art_id not in _generated_artifacts:
			available.append(art_id)
	if available.is_empty():
		# All artifacts generated, fall back to a ring
		return random_ring()
	var idx: int = randi_range(0, available.size() - 1)
	var chosen: String = available[idx]
	_generated_artifacts.append(chosen)
	return create_item(chosen)

## Generate a random food item.
static func random_food() -> Item:
	# Weighted: rations are more common than pasty, mystery meat is rare
	var roll: float = randf()
	if roll < 0.65:
		return create_item("ration")
	elif roll < 0.90:
		return create_item("pasty")
	else:
		return create_item("mystery_meat")

## Generate a random missile weapon whose tier is based on depth.
## Uses floorSetTierProbs for tier selection.
static func random_missile(depth: int) -> Item:
	var tier: int = _roll_tier_for_depth(depth)
	var table: Array[String] = _missile_table_for_tier(tier)
	return _random_from_table(table)

## Generate a random stone.
static func random_stone() -> Item:
	return _random_from_table(STONES)

## Generate a random seed.
static func random_seed() -> Item:
	return _random_from_table(SEEDS)

## Generate a random gold pile scaled to depth.
static func random_gold(depth: int) -> Gold:
	var amount: int = randi_range(5, 10 + depth * 5)
	var gold: Gold = create_item("gold") as Gold
	if gold != null:
		gold.quantity = amount
		return gold
	return Gold.new(amount)

# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Roll an equipment tier (1-5) based on dungeon depth using FLOOR_SET_TIER_PROBS.
static func _roll_tier_for_depth(depth: int) -> int:
	var floor_set: int = clampi((depth - 1) / 5, 0, FLOOR_SET_TIER_PROBS.size() - 1)
	var probs: Array = FLOOR_SET_TIER_PROBS[floor_set]
	var total: int = 0
	for p: int in probs:
		total += p
	var roll: int = randi() % maxi(total, 1)
	for i: int in range(probs.size()):
		roll -= probs[i]
		if roll < 0:
			return i + 1  # Tiers are 1-indexed
	return 1

## Return the melee weapon table for a given tier.
static func _weapon_table_for_tier(tier: int) -> Array[String]:
	match tier:
		1: return WEAPONS_T1
		2: return WEAPONS_T2
		3: return WEAPONS_T3
		4: return WEAPONS_T4
		5: return WEAPONS_T5
	return WEAPONS_T1

## Return the armor table for a given tier.
static func _armor_table_for_tier(tier: int) -> Array[String]:
	match tier:
		1: return ARMORS_T1
		2: return ARMORS_T2
		3: return ARMORS_T3
		4: return ARMORS_T4
		5: return ARMORS_T5
	return ARMORS_T1

## Return the missile weapon table for a given tier.
static func _missile_table_for_tier(tier: int) -> Array[String]:
	match tier:
		1: return MISSILES_T1
		2: return MISSILES_T2
		3: return MISSILES_T3
		4: return MISSILES_T4
		5: return MISSILES_T5
	return MISSILES_T1

## Pick a random item from a string table and create it via create_item().
static func _random_from_table(table: Array[String]) -> Item:
	if table.is_empty():
		return Item.new()
	var idx: int = randi_range(0, table.size() - 1)
	return create_item(table[idx])

## Pick a weighted random item from a table using parallel weight array.
static func _weighted_random_from_table(table: Array[String], weights: Array[int]) -> Item:
	if table.is_empty():
		return Item.new()
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = randi() % maxi(total, 1)
	for i: int in range(mini(table.size(), weights.size())):
		roll -= weights[i]
		if roll < 0:
			return create_item(table[i])
	return create_item(table[0])

# ---------------------------------------------------------------------------
# SPD items.png Sprite Sheet Indices (from ItemSpriteSheet.java)
# ---------------------------------------------------------------------------
# 16-column grid of 16x16 tiles. Index = row * 16 + col.

const SPRITE_INDICES: Dictionary = {
	# SPD ItemSpriteSheet.java: xy(x,y) = (x-1) + (y-1)*16
	# --- Uncollectible / Misc (row 2+) ---
	"gold": 18,
	"dewdrop": 21,
	"ankh": 48,
	"torch": 51,
	"amulet_of_yendor": 61,
	# --- Keys (row 4) ---
	"iron_key": 55,
	"golden_key": 56,
	"crystal_key": 57,
	"skeleton_key": 58,
	# --- Bombs (row 6) ---
	"bomb": 80,
	"fire_bomb": 82,
	"frost_bomb": 83,
	"holy_bomb": 87,
	"wooly_bomb": 88,
	"noisemaker": 89,
	"flashbang": 86,
	"shock_bomb": 91,
	"regrowth_bomb": 84,
	"arcane_bomb": 90,
	# --- Melee weapons tier 1 (row 7) ---
	"worn_shortsword": 96,
	"cudgel": 97,
	"gloves": 98,
	"rapier": 99,
	"dagger": 100,
	# --- Melee weapons tier 2 (row 7.5) ---
	"shortsword": 104,
	"hand_axe": 105,
	"spear": 106,
	"quarterstaff": 107,
	"dirk": 108,
	# --- Melee weapons tier 3 (row 8) ---
	"sword": 112,
	"mace": 113,
	"scimitar": 114,
	"round_shield": 115,
	"sai": 116,
	# --- Melee weapons tier 4 (row 8.5) ---
	"longsword": 120,
	"battle_axe": 121,
	"flail": 122,
	"runic_blade": 123,
	"assassins_blade": 124,
	# --- Melee weapons tier 5 (row 9) ---
	"greatsword": 128,
	"war_hammer": 129,
	"glaive": 130,
	"greataxe": 131,
	"greatshield": 132,
	# --- Missile/thrown weapons (row 10) ---
	"spirit_bow": 144,
	"throwing_knife": 146,
	"throwing_stone": 147,
	"shuriken": 149,
	"throwing_club": 150,
	"bolas": 152,
	"kunai": 153,
	"javelin": 154,
	"tomahawk": 155,
	"boomerang": 156,
	"trident": 157,
	"heavy_boomerang": 158,
	"force_cudgel": 159,
	# --- Armor (row 12) ---
	"cloth_armor": 176,
	"leather_armor": 177,
	"mail_armor": 178,
	"scale_armor": 179,
	"plate_armor": 180,
	# --- Wands (row 14) ---
	"wand_of_magic_missile": 208,
	"wand_of_fire_bolt": 209,
	"wand_of_frost": 210,
	"wand_of_lightning": 211,
	"wand_of_disintegration": 212,
	"wand_of_prismatic_light": 213,
	"wand_of_corrosion": 214,
	"wand_of_living_earth": 215,
	"wand_of_blast_wave": 216,
	"wand_of_corruption": 217,
	"wand_of_warding": 218,
	"wand_of_regrowth": 219,
	"wand_of_transfusion": 220,
	# --- Rings (row 15) ---
	"ring_of_accuracy": 224,
	"ring_of_elements": 226,
	"ring_of_energy": 227,
	"ring_of_evasion": 228,
	"ring_of_force": 229,
	"ring_of_furor": 230,
	"ring_of_haste": 231,
	"ring_of_might": 232,
	"ring_of_sharpshooting": 233,
	"ring_of_tenacity": 234,
	"ring_of_wealth": 235,
	# --- Artifacts (row 16) ---
	"cloak_of_shadows": 240,
	"master_thieves_armband": 241,
	"cape_of_thorns": 242,
	"talisman_of_foresight": 243,
	"timekeeper_hourglass": 244,
	"alchemists_toolkit": 245,
	"unstable_spellbook": 246,
	"ethereal_chains": 248,
	"horn_of_plenty": 249,
	"chalice_of_blood": 253,
	"sandals_of_nature": 256,
	"dried_rose": 260,
	# --- Scrolls (row 20) ---
	"upgrade": 304,
	"identify": 305,
	"remove_curse": 306,
	"mirror_image": 307,
	"recharging": 308,
	"teleportation": 309,
	"lullaby": 310,
	"magic_mapping": 311,
	"rage": 312,
	"retribution": 313,
	"terror": 314,
	"transmutation": 315,
	# --- Stones (row 22) ---
	"enchantment": 344,
	"augmentation": 337,
	"intuition": 346,
	"blast": 339,
	"blink": 340,
	"clairvoyance": 341,
	"deepened_sleep": 342,
	"disarming": 343,
	"fear": 338,
	"flock": 345,
	"shock": 347,
	# --- Potions (row 23) ---
	"strength": 352,
	"healing": 353,
	"mind_vision": 354,
	"frost": 355,
	"liquid_flame": 356,
	"toxic_gas": 357,
	"haste": 358,
	"invisibility": 359,
	"levitation": 360,
	"paralytic_gas": 361,
	"purity": 362,
	"experience": 363,
	# --- Seeds (row 25) ---
	"seed_of_rotberry": 384,
	"seed_of_firebloom": 385,
	"seed_of_swiftthistle": 386,
	"seed_of_sungrass": 387,
	"seed_of_icecap": 388,
	"seed_of_stormvine": 389,
	"seed_of_sorrowmoss": 390,
	"seed_of_dreamfoil": 391,
	"seed_of_earthroot": 392,
	"seed_of_starflower": 393,
	"seed_of_fadeleaf": 394,
	"seed_of_blindweed": 395,
	# --- Food (row 28) ---
	"mystery_meat": 432,
	"ration": 437,
	"pasty": 438,
	"meat_pie": 439,
	# --- Bags (row 31) ---
	"velvet_pouch": 482,
	"scroll_holder": 483,
	"potion_bandolier": 484,
	"magical_holster": 485,
}
