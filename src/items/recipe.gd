class_name Recipe
extends RefCounted
## Represents a single alchemy recipe. Ingredients are consumed to produce a
## result item, costing a certain amount of alchemical energy.
##
## The static method get_all_recipes() returns the master list of known recipes
## mirroring Shattered Pixel Dungeon's alchemy system.

## Item IDs of the required ingredients (order does not matter).
var ingredients: Array[String] = []
## Item ID of the crafted result.
var result_id: String = ""
## Alchemical energy cost to perform the craft.
var energy_cost: int = 0

# ---------------------------------------------------------------------------
# Construction Helper
# ---------------------------------------------------------------------------

## Convenience initializer.
static func make(p_ingredients: Array[String], p_result: String, p_energy: int) -> Recipe:
	var r: Recipe = Recipe.new()
	r.ingredients = p_ingredients
	r.result_id = p_result
	r.energy_cost = p_energy
	return r

# ---------------------------------------------------------------------------
# Crafting Logic
# ---------------------------------------------------------------------------

## Check whether this recipe can be crafted from the available items.
## Each ingredient must match exactly one available item (consumed on craft).
func can_craft(available_items: Array[Item]) -> bool:
	# Build a frequency map of required ingredient IDs
	var needed: Dictionary[String, int] = {}
	for ing_id: String in ingredients:
		needed[ing_id] = needed.get(ing_id, 0) + 1

	# Build a frequency map of available item IDs
	var have: Dictionary[String, int] = {}
	for item: Item in available_items:
		if item == null:
			continue
		if item.item_id != "":
			have[item.item_id] = have.get(item.item_id, 0) + 1

	# Check that we have enough of each ingredient
	for ing_id: String in needed:
		if have.get(ing_id, 0) < needed[ing_id]:
			return false
	return true

## Perform the craft: consume ingredients from available_items and return the
## result item. Returns null if crafting is not possible.
## This mutates available_items by removing consumed ingredients.
func craft(available_items: Array[Item]) -> Item:
	if not can_craft(available_items):
		return null

	# Consume ingredients — remove one matching item per ingredient entry
	var to_consume: Array[String] = ingredients.duplicate()
	for ing_id: String in to_consume:
		var consumed: bool = false
		for i: int in range(available_items.size()):
			var item: Item = available_items[i]
			if item == null:
				continue
			if item.item_id == ing_id:
				# If stackable with quantity > 1, decrement quantity instead of removing
				if item.is_stackable() and item.quantity > 1:
					item.quantity -= 1
				else:
					available_items.remove_at(i)
				consumed = true
				break
		if not consumed:
			push_error("Recipe.craft: failed to consume ingredient '%s'." % ing_id)
			return null

	# Create result
	var result: Item = Generator.create_item(result_id)
	if MessageLog:
		MessageLog.add_positive("You crafted %s!" % result.get_display_name())
	if EventBus:
		EventBus.item_used.emit(result.get_display_name())
	return result

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

## Human-readable description of the recipe for the alchemy UI.
func get_description() -> String:
	var parts: Array[String] = []
	for ing_id: String in ingredients:
		parts.append(ing_id.replace("_", " ").capitalize())
	var result_name: String = result_id.replace("_", " ").capitalize()
	return "%s -> %s (energy: %d)" % [" + ".join(parts), result_name, energy_cost]

# ---------------------------------------------------------------------------
# Master Recipe List
# ---------------------------------------------------------------------------

## Returns an array of all known alchemy recipes.
static func get_all_recipes() -> Array[Recipe]:
	var recipes: Array[Recipe] = []

	# --- Potions from Seeds (2 seeds of the same type -> 1 potion) ---
	recipes.append(Recipe.make(
		["seed_of_firebloom", "seed_of_firebloom", "seed_of_firebloom"],
		"potion_of_liquid_flame", 0))
	recipes.append(Recipe.make(
		["seed_of_icecap", "seed_of_icecap", "seed_of_icecap"],
		"potion_of_frost", 0))
	recipes.append(Recipe.make(
		["seed_of_sorrowmoss", "seed_of_sorrowmoss", "seed_of_sorrowmoss"],
		"potion_of_toxic_gas", 0))
	recipes.append(Recipe.make(
		["seed_of_stormvine", "seed_of_stormvine", "seed_of_stormvine"],
		"potion_of_levitation", 0))
	recipes.append(Recipe.make(
		["seed_of_sungrass", "seed_of_sungrass", "seed_of_sungrass"],
		"potion_of_healing", 0))
	recipes.append(Recipe.make(
		["seed_of_earthroot", "seed_of_earthroot", "seed_of_earthroot"],
		"potion_of_paralytic_gas", 0))
	recipes.append(Recipe.make(
		["seed_of_fadeleaf", "seed_of_fadeleaf", "seed_of_fadeleaf"],
		"potion_of_mind_vision", 0))
	recipes.append(Recipe.make(
		["seed_of_blindweed", "seed_of_blindweed", "seed_of_blindweed"],
		"potion_of_invisibility", 0))
	recipes.append(Recipe.make(
		["seed_of_dreamfoil", "seed_of_dreamfoil", "seed_of_dreamfoil"],
		"potion_of_purity", 0))
	recipes.append(Recipe.make(
		["seed_of_swiftthistle", "seed_of_swiftthistle", "seed_of_swiftthistle"],
		"potion_of_haste", 0))
	recipes.append(Recipe.make(
		["seed_of_starflower", "seed_of_starflower", "seed_of_starflower"],
		"potion_of_experience", 0))

	# --- Scrolls from Stones (2 stones of the same type -> 1 scroll) ---
	recipes.append(Recipe.make(
		["stone_of_augmentation", "stone_of_augmentation"],
		"scroll_of_upgrade", 2))
	recipes.append(Recipe.make(
		["stone_of_intuition", "stone_of_intuition"],
		"scroll_of_identify", 0))
	recipes.append(Recipe.make(
		["stone_of_enchantment", "stone_of_enchantment"],
		"scroll_of_transmutation", 2))
	recipes.append(Recipe.make(
		["stone_of_flock", "stone_of_flock"],
		"scroll_of_mirror_image", 0))
	recipes.append(Recipe.make(
		["stone_of_shock", "stone_of_shock"],
		"scroll_of_recharging", 0))
	recipes.append(Recipe.make(
		["stone_of_blink", "stone_of_blink"],
		"scroll_of_teleportation", 0))
	recipes.append(Recipe.make(
		["stone_of_clairvoyance", "stone_of_clairvoyance"],
		"scroll_of_magic_mapping", 0))
	recipes.append(Recipe.make(
		["stone_of_aggression", "stone_of_aggression"],
		"scroll_of_rage", 0))
	recipes.append(Recipe.make(
		["stone_of_blast", "stone_of_blast"],
		"scroll_of_retribution", 0))
	recipes.append(Recipe.make(
		["stone_of_fear", "stone_of_fear"],
		"scroll_of_terror", 0))
	recipes.append(Recipe.make(
		["stone_of_deepened_sleep", "stone_of_deepened_sleep"],
		"scroll_of_lullaby", 0))
	recipes.append(Recipe.make(
		["stone_of_disarming", "stone_of_disarming"],
		"scroll_of_remove_curse", 0))

	return recipes

## Find all recipes that can be crafted with the given available items.
static func find_craftable(available_items: Array) -> Array[Recipe]:
	var all: Array[Recipe] = get_all_recipes()
	var craftable: Array[Recipe] = []
	for recipe: Recipe in all:
		if recipe.can_craft(available_items):
			craftable.append(recipe)
	return craftable

## Find the first recipe whose result matches the given item_id.
static func find_recipe_for(result_item_id: String) -> Recipe:
	var all: Array[Recipe] = get_all_recipes()
	for recipe: Recipe in all:
		if recipe.result_id == result_item_id:
			return recipe
	return null

## Find the first recipe that can be crafted from the given ingredient items.
## Called by WndAlchemy to check if a valid recipe exists for selected ingredients.
static func find_recipe(ingredients: Array[Item]) -> Recipe:
	var recipes: Array[Recipe] = get_all_recipes()
	for recipe: Recipe in recipes:
		if recipe.can_craft(ingredients):
			return recipe
	return null


## Get a list of all known (previously discovered) recipes as dictionaries.
## Returns an array of {ingredients: Array, result: String} entries.
static func get_known_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: Recipe in ALL_RECIPES:
		if recipe == null:
			continue
		result.append({
			"ingredients": recipe.ingredient_ids.duplicate(),
			"result": recipe.result_id,
			"energy_cost": recipe.energy_cost,
		})
	return result
