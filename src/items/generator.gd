class_name Generator
extends RefCounted
## Loot generation system. Produces random items appropriate for a given
## dungeon depth, using weighted category selection and tiered sub-tables.
##
## All item creation goes through create_item(item_id) which delegates to
## the proper specialized class factory (MeleeWeapon.create, Potion.create, etc.).
## This is the single factory entry point for the entire item system.

# ---------------------------------------------------------------------------
# Category Decks (upstream Generator.Category firstProb/secondProb)
# ---------------------------------------------------------------------------

## Upstream runs two alternating 35-item category decks: each random_item pick
## decrements the chosen category and when the deck empties the run swaps to
## the other deck. Deck 1 has a ring + an extra armor; deck 2 has an artifact
## + an extra thrown weapon. FOOD is 0 upstream (each floor drops one
## guaranteed food item instead) so it is absent here.
const CATEGORY_ORDER: Array[String] = [
	"weapon", "armor", "missile", "wand", "ring", "artifact",
	"potion", "seed", "scroll", "stone", "gold",
]
const CATEGORY_FIRST_PROBS: Dictionary = {
	"weapon": 2, "armor": 2, "missile": 1, "wand": 1, "ring": 1,
	"artifact": 0, "potion": 8, "seed": 1, "scroll": 8, "stone": 1,
	"gold": 10,
}
const CATEGORY_SECOND_PROBS: Dictionary = {
	"weapon": 2, "armor": 1, "missile": 2, "wand": 1, "ring": 0,
	"artifact": 1, "potion": 8, "seed": 1, "scroll": 8, "stone": 1,
	"gold": 10,
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

## Potions — short IDs matching Potion.create(), upstream class order.
## NOTE: "strength" is excluded from random drops (prob 0 upstream; placed via
## the Dungeon.posNeeded() limited-drop quota instead).
const POTIONS: Array[String] = [
	"healing", "mind_vision", "frost", "liquid_flame", "toxic_gas",
	"haste", "invisibility", "levitation", "paralytic_gas", "purity",
	"experience",
]

## Upstream POTION defaultProbs / defaultProbs2 (strength slot dropped):
## the two decks alternate as each empties; deck 2 trades the experience
## potion + a liquid flame for an extra frost and toxic gas.
const POTION_DECK_1: Array[float] = [3, 2, 1, 2, 1, 1, 1, 1, 1, 1, 1]
const POTION_DECK_2: Array[float] = [3, 2, 2, 1, 2, 1, 1, 1, 1, 1, 0]

## Scrolls — short IDs matching Scroll.create(), upstream class order.
## NOTE: "upgrade" is excluded from random drops (prob 0 upstream; placed via
## the Dungeon.souNeeded() limited-drop quota, 3 per chapter).
const SCROLLS: Array[String] = [
	"identify", "remove_curse", "mirror_image", "recharging",
	"teleportation", "lullaby", "magic_mapping", "rage",
	"retribution", "terror", "transmutation",
]

## Upstream SCROLL defaultProbs / defaultProbs2 (upgrade slot dropped):
## deck 2 trades transmutation + a recharging for an extra mirror image
## and teleportation.
const SCROLL_DECK_1: Array[float] = [3, 2, 1, 2, 1, 1, 1, 1, 1, 1, 1]
const SCROLL_DECK_2: Array[float] = [3, 2, 2, 1, 2, 1, 1, 1, 1, 1, 0]

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

## Seeds — upstream class order (dreamfoil stands in for Mageroyal).
const SEEDS: Array[String] = [
	"seed_of_rotberry", "seed_of_sungrass", "seed_of_fadeleaf",
	"seed_of_icecap", "seed_of_firebloom", "seed_of_sorrowmoss",
	"seed_of_swiftthistle", "seed_of_blindweed", "seed_of_stormvine",
	"seed_of_earthroot", "seed_of_dreamfoil", "seed_of_starflower",
]

## Upstream SEED defaultProbs: rotberry never random (quest item),
## starflower rare. Seeds mostly drop from grass, not levelgen, so upstream
## draws them from these static defaults rather than a depleting deck.
const SEED_DEFAULT_PROBS: Array[float] = [0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1]

## Stones — short IDs matching Stone.create(), upstream class order.
## Disarming fills upstream's StoneOfDetectMagic slot (unported);
## StoneOfAggression is unported and skipped.
const STONES: Array[String] = [
	"enchantment", "intuition", "disarming", "flock", "shock", "blink",
	"deepened_sleep", "clairvoyance", "blast", "fear", "augmentation",
]

## Upstream STONE defaultProbs: enchantment + augmentation never random
## (guaranteed floor drop / shop stock respectively).
const STONE_DECK: Array[float] = [0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0]

## Food — short IDs matching Food.create().
const FOODS: Array[String] = [
	"ration", "pasty", "mystery_meat",
]

## Bombs — IDs matching Bomb.create().
const BOMBS: Array[String] = [
	"bomb", "fire_bomb", "frost_bomb", "holy_bomb", "wooly_bomb",
	"noisemaker", "flashbang", "shock_bomb", "regrowth_bomb", "arcane_bomb",
	"smoke_bomb",
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
# Item Deck System (upstream Generator probs/defaultProbs)
# ---------------------------------------------------------------------------

## Single-deck categories: every draw decrements the item's slot; when the
## deck empties it refills. WAND/RING are flat 3s; FOOD is 4 rations to
## 1 pasty (mystery meat only comes from mob drops, prob 0).
const WAND_DECK: Array[float] = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
const RING_DECK: Array[float] = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
const FOOD_DECK: Array[float] = [4, 1, 0]

## Deck definitions: category -> {table, deck1, deck2 (optional)}.
## Dual-deck categories flip decks on every refill (upstream using2ndProbs).
static var _deck_defs: Dictionary = {
	"potion": {"table": POTIONS, "deck1": POTION_DECK_1, "deck2": POTION_DECK_2},
	"scroll": {"table": SCROLLS, "deck1": SCROLL_DECK_1, "deck2": SCROLL_DECK_2},
	"wand": {"table": WANDS, "deck1": WAND_DECK},
	"ring": {"table": RINGS, "deck1": RING_DECK},
	"stone": {"table": STONES, "deck1": STONE_DECK},
	"food": {"table": FOODS, "deck1": FOOD_DECK},
}

## Live deck state (persisted with the run).
static var _using_first_cat_deck: bool = true
static var _category_probs: Dictionary = {}
static var _item_probs: Dictionary = {}
static var _using_second_deck: Dictionary = {}

## New-run reset (upstream Generator.fullReset): random starting category
## deck, random starting potion/scroll deck, artifacts cleared.
static func full_reset() -> void:
	reset_artifacts()
	_using_first_cat_deck = randi() % 2 == 0
	_general_reset()
	for cat: String in _deck_defs:
		_using_second_deck[cat] = _deck_defs[cat].has("deck2") and randi() % 2 == 0
		_reset_item_deck(cat)


## Refill the category deck from whichever 35-item deck is active
## (upstream Generator.generalReset).
static func _general_reset() -> void:
	for cat_name: String in CATEGORY_ORDER:
		var probs: Dictionary = CATEGORY_FIRST_PROBS if _using_first_cat_deck \
			else CATEGORY_SECOND_PROBS
		_category_probs[cat_name] = float(probs[cat_name])


## Refill one item deck, flipping to the alternate deck when the category
## has two (upstream Generator.reset(cat)).
static func _reset_item_deck(cat: String) -> void:
	var def: Dictionary = _deck_defs[cat]
	if def.has("deck2"):
		_using_second_deck[cat] = not _using_second_deck.get(cat, false)
		var deck: Array = def["deck2"] if _using_second_deck[cat] else def["deck1"]
		_item_probs[cat] = deck.duplicate()
	else:
		_item_probs[cat] = (def["deck1"] as Array).duplicate()


## Weighted index pick; -1 when all weights are spent (upstream Random.chances).
static func _chances(probs: Array) -> int:
	var total: float = 0.0
	for p: Variant in probs:
		total += float(p)
	if total <= 0.0:
		return -1
	var roll: float = randf() * total
	for i: int in range(probs.size()):
		roll -= float(probs[i])
		if roll < 0.0:
			return i
	return probs.size() - 1


## Draw an item id from a category's depleting deck, refilling when empty
## (upstream Generator.random(Category) default branch).
static func _deck_draw(cat: String) -> String:
	if not _item_probs.has(cat):
		_reset_item_deck(cat)
	var idx: int = _chances(_item_probs[cat])
	if idx == -1:
		_reset_item_deck(cat)
		idx = _chances(_item_probs[cat])
	var probs: Array = _item_probs[cat]
	probs[idx] = float(probs[idx]) - 1.0
	return (_deck_defs[cat]["table"] as Array)[idx]


## Pick a category from the depleting 35-item category deck, swapping decks
## when it empties (upstream Generator.random()).
static func _pick_category() -> String:
	if _category_probs.is_empty():
		_general_reset()
	var probs: Array[float] = []
	for cat_name: String in CATEGORY_ORDER:
		probs.append(float(_category_probs.get(cat_name, 0.0)))
	var idx: int = _chances(probs)
	if idx == -1:
		_using_first_cat_deck = not _using_first_cat_deck
		_general_reset()
		for i: int in range(CATEGORY_ORDER.size()):
			probs[i] = float(_category_probs[CATEGORY_ORDER[i]])
		idx = _chances(probs)
	var chosen: String = CATEGORY_ORDER[idx]
	_category_probs[chosen] = float(_category_probs[chosen]) - 1.0
	return chosen


## Persist deck state so save/load keeps drop consistency
## (upstream Generator.storeInBundle).
static func serialize_decks() -> Dictionary:
	var item_probs_out: Dictionary = {}
	for cat: String in _item_probs:
		item_probs_out[cat] = (_item_probs[cat] as Array).duplicate()
	return {
		"using_first_cat_deck": _using_first_cat_deck,
		"category_probs": _category_probs.duplicate(),
		"item_probs": item_probs_out,
		"using_second_deck": _using_second_deck.duplicate(),
	}


## Restore deck state; anything missing or malformed falls back to a fresh
## refill (upstream Generator.restoreFromBundle tolerance).
static func restore_decks(data: Dictionary) -> void:
	_using_first_cat_deck = bool(data.get("using_first_cat_deck", true))
	_general_reset()
	var saved_cats: Variant = data.get("category_probs", {})
	if saved_cats is Dictionary:
		for cat_name: Variant in saved_cats:
			if _category_probs.has(cat_name):
				_category_probs[cat_name] = float(saved_cats[cat_name])
	var saved_flags: Variant = data.get("using_second_deck", {})
	var saved_items: Variant = data.get("item_probs", {})
	for cat: String in _deck_defs:
		if saved_flags is Dictionary and _deck_defs[cat].has("deck2"):
			_using_second_deck[cat] = bool((saved_flags as Dictionary).get(cat, false))
		var probs: Variant = (saved_items as Dictionary).get(cat, null) \
			if saved_items is Dictionary else null
		if probs is Array and (probs as Array).size() == (_deck_defs[cat]["table"] as Array).size():
			var restored: Array = []
			for p: Variant in probs:
				restored.append(float(p))
			_item_probs[cat] = restored
		else:
			_item_probs.erase(cat)
			_reset_item_deck(cat)

# ---------------------------------------------------------------------------
# Artifact Uniqueness Tracking
# ---------------------------------------------------------------------------

## Artifacts that have already been generated this run (only one of each).
static var _generated_artifacts: Array[String] = []

## Reset artifact tracking (call at start of new run).
static func reset_artifacts() -> void:
	_generated_artifacts.clear()


## Persisted so mid-run save/load can't regenerate an already-found artifact
## (upstream Generator.storeInBundle "spawned_artifacts").
static func serialize_artifacts() -> Array:
	return _generated_artifacts.duplicate()


static func restore_artifacts(data: Array) -> void:
	_generated_artifacts.clear()
	for art_id: Variant in data:
		var id_str: String = str(art_id)
		if id_str in ARTIFACTS and id_str not in _generated_artifacts:
			_generated_artifacts.append(id_str)

const ITEM_ID_ALIASES: Dictionary = {
	"potion_of_healing": "healing",
	"scroll_of_identify": "identify",
	"scroll_of_upgrade": "upgrade",
	"scroll_of_remove_curse": "remove_curse",
	"scroll_of_teleportation": "teleportation",
	"scroll_of_lullaby": "lullaby",
	"scroll_of_rage": "rage",
	"scroll_of_terror": "terror",
	"scroll_of_magic_mapping": "magic_mapping",
	"scroll_of_retribution": "retribution",
	"scroll_of_mirror_image": "mirror_image",
	"scroll_of_transmutation": "transmutation",
	"scroll_of_recharging": "recharging",
	"rotberry_seed": "seed_of_rotberry",
	"ring_sharpshoot": "ring_of_sharpshooting",
	"ring_of_sharpshoot": "ring_of_sharpshooting",
}

# ---------------------------------------------------------------------------
# Factory — create_item
# ---------------------------------------------------------------------------

## Master factory method. Given an item_id string, instantiate the correct
## specialized class via its factory and return it.
##
## Uses known-ID sets for dispatch to avoid false matches from factories
## that always return non-null objects.
static func create_item(item_id: String) -> Item:
	var normalized_id: String = ITEM_ID_ALIASES.get(item_id, item_id)
	var result: Item = _create_item_internal(normalized_id)
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
		"reclaimed_trap":
			return TrappedItem.new()
		"dewdrop":
			return Dewdrop.new()
		"ankh":
			return Ankh.new()
		"torch":
			return Torch.new()
		"amulet_of_yendor":
			return AmuletOfYendor.new()
		"metal_shard":
			return _make_misc_item("metal_shard", "Metal Shard", "A jagged fragment of dwarven machinery. It looks like it could be useful to someone.", ConstantsData.ItemCategory.MISC)
		"corpse_dust":
			return _make_misc_item("corpse_dust", "Corpse Dust", "Fine powdery remains gathered for the wandmaker.", ConstantsData.ItemCategory.MISC)
		"elemental_embers":
			return _make_misc_item("elemental_embers", "Elemental Embers", "Warm embers harvested for the wandmaker.", ConstantsData.ItemCategory.MISC)
		"dark_gold_ore":
			return _make_stackable_misc_item("dark_gold_ore", "Dark Gold Ore", "A lump of heavy, dark ore veined with gold. The troll blacksmith covets it.", ConstantsData.ItemCategory.MISC)

	# --- Mage's Staff (imbued-wand melee weapon) ---
	if item_id == "mages_staff":
		var staff: MagesStaff = MagesStaff.new()
		staff.configure_default()
		return staff

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
		return SeedItem.create(item_id)

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
	"dart", "curare_dart", "paralytic_dart",
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
	"small_ration", "frozen_carpaccio", "meat_pie", "chargrilled_meat",
]

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

static func _make_misc_item(id: String, display_name: String, desc: String, category: int) -> Item:
	var item: Item = Item.new()
	item.item_id = id
	item.item_name = display_name
	item.description = desc
	item.category = category
	item.identified = true
	item.cursed_known = true
	item.unique = true
	return item

## Build a stackable quest/material MISC item (e.g. dark gold ore) that the
## Belongings stacking, count_item, and remove_item_quantity APIs can pool and
## consume. Unlike _make_misc_item these are NOT unique — multiple pieces merge.
static func _make_stackable_misc_item(id: String, display_name: String, desc: String, category: int) -> Item:
	var item: Item = Item.new()
	item.item_id = id
	item.item_name = display_name
	item.description = desc
	item.category = category
	item.identified = true
	item.cursed_known = true
	item.stackable = true
	item.quantity = 1
	return item

# ---------------------------------------------------------------------------
# Random Generation — Public API
# ---------------------------------------------------------------------------

## Generate a random item appropriate for the given dungeon depth, drawing
## the category from the depleting two-deck system (upstream Generator.random).
static func random_item(depth: int) -> Item:
	match _pick_category():
		"gold":
			return random_gold(depth)
		"potion":
			return random_potion()
		"scroll":
			return random_scroll()
		"weapon":
			return random_weapon(depth)
		"missile":
			return random_missile(depth)
		"armor":
			return random_armor(depth)
		"stone":
			return random_stone()
		"seed":
			return random_seed()
		"ring":
			return random_ring()
		"wand":
			return random_wand()
		"artifact":
			return random_artifact()
	return random_gold(depth)

## Generate a random melee weapon whose tier is based on depth.
## Uses floorSetTierProbs for tier selection and calls random() for upgrades/curses.
static func random_weapon(depth: int) -> Item:
	var tier: int = _roll_tier_for_depth(depth)
	var weapon: Item = random_weapon_for_tier(tier)
	if weapon is Weapon and weapon.has_method("random"):
		weapon.random()
	return weapon

## Generate a random melee weapon from a specific tier table.
static func random_weapon_for_tier(tier: int) -> Item:
	var table: Array[String] = _weapon_table_for_tier(tier)
	return _random_from_table(table)

## Generate a random armor whose tier is based on depth.
## Uses floorSetTierProbs for tier selection and calls random() for upgrades/curses.
static func random_armor(depth: int) -> Item:
	var tier: int = _roll_tier_for_depth(depth)
	var table: Array[String] = _armor_table_for_tier(tier)
	var armor: Item = _random_from_table(table)
	if armor is Armor and armor.has_method("random"):
		armor.random()
	return armor

## Generate a random potion from the alternating potion decks.
static func random_potion() -> Item:
	return create_item(_deck_draw("potion"))

## Generate a random scroll from the alternating scroll decks.
static func random_scroll() -> Item:
	return create_item(_deck_draw("scroll"))

## Generate a random ring (deck draw) with random upgrade/curse.
static func random_ring() -> Item:
	var ring: Item = create_item(_deck_draw("ring"))
	if ring is Ring and ring.has_method("random"):
		ring.random()
	return ring

## Generate a random wand (deck draw) with random upgrade/curse.
## Uses Wand.random() if available, matching original distribution:
## +0: 66.67% (2/3), +1: 26.67% (4/15), +2: 6.67% (1/15). 30% cursed.
static func random_wand() -> Item:
	var wand: Item = create_item(_deck_draw("wand"))
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

## Generate a random food item from the food deck (upstream FOOD probs 4/1/0:
## each 5-draw cycle is exactly 4 rations + 1 pasty; mystery meat only comes
## from mob drops).
static func random_food() -> Item:
	return create_item(_deck_draw("food"))

## Generate a random missile weapon whose tier is based on depth.
## Uses floorSetTierProbs for tier selection.
static func random_missile(depth: int) -> Item:
	var tier: int = _roll_tier_for_depth(depth)
	var table: Array[String] = _missile_table_for_tier(tier)
	return _random_from_table(table)

## Generate a random stone from the stone deck (enchantment/augmentation
## never drop randomly).
static func random_stone() -> Item:
	return create_item(_deck_draw("stone"))

## Generate a random seed. Upstream deliberately uses the static defaults
## here (not a deck) because most seeds come from grass, so levelgen draws
## stay consistent; rotberry (quest item) never drops randomly.
static func random_seed() -> Item:
	return create_item(random_seed_id())

## Weighted seed id from SEED_DEFAULT_PROBS — shared with grass trampling.
static func random_seed_id() -> String:
	var idx: int = _chances(SEED_DEFAULT_PROBS)
	if idx == -1:
		idx = 1
	return SEEDS[idx]

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
	"smoke_bomb": 85,
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
	"dart": 145,
	"throwing_knife": 146,
	"throwing_stone": 147,
	"curare_dart": 148,
	"shuriken": 149,
	"throwing_club": 150,
	"paralytic_dart": 151,
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
	"chargrilled_meat": 433,
	"frozen_carpaccio": 436,
	"ration": 437,
	"pasty": 438,
	"meat_pie": 439,
	# --- Bags (row 31) ---
	"velvet_pouch": 482,
	"scroll_holder": 483,
	"potion_bandolier": 484,
	"magical_holster": 485,
}
