class_name Recipe
extends RefCounted
## Represents a single alchemy recipe. Ingredients are consumed to produce a
## result item. The static helpers expose the compact recipe list used by the
## current alchemy window.

var ingredients: Array[String] = []
var result_id: String = ""
var energy_cost: int = 0

static func make(p_ingredients: Array[String], p_result: String, p_energy: int) -> Recipe:
	var recipe: Recipe = Recipe.new()
	recipe.ingredients = p_ingredients
	recipe.result_id = p_result
	recipe.energy_cost = p_energy
	return recipe

func can_craft(available_items: Array) -> bool:
	var needed: Dictionary[String, int] = {}
	for ing_id: String in ingredients:
		needed[ing_id] = needed.get(ing_id, 0) + 1

	var have: Dictionary[String, int] = {}
	for item: Variant in available_items:
		if item == null:
			continue
		var item_id: String = item.item_id if item.get("item_id") != null else ""
		if item_id == "":
			continue
		var count: int = item.quantity if item.get("quantity") != null else 1
		have[item_id] = have.get(item_id, 0) + maxi(1, count)

	for ing_id: String in needed.keys():
		if have.get(ing_id, 0) < needed[ing_id]:
			return false
	return true

func craft(hero: Hero, available_items: Array) -> Item:
	if hero == null or hero.belongings == null or not can_craft(available_items):
		return null

	var needed: Dictionary[String, int] = {}
	for ing_id: String in ingredients:
		needed[ing_id] = needed.get(ing_id, 0) + 1

	for ing_id: String in needed.keys():
		var remaining: int = needed[ing_id]
		for item: Variant in available_items:
			if remaining <= 0:
				break
			if item == null or item.item_id != ing_id:
				continue
			while remaining > 0 and item.quantity > 1:
				item.quantity -= 1
				remaining -= 1
			if remaining > 0:
				hero.belongings.remove_item(item)
				remaining -= 1
		if remaining > 0:
			push_error("Recipe.craft: failed to consume ingredient '%s'." % ing_id)
			return null

	var result: Item = Generator.create_item(result_id)
	if result == null:
		push_error("Recipe.craft: failed to create result '%s'." % result_id)
		return null
	return result

func get_input_names() -> Array[String]:
	var names: Array[String] = []
	for ing_id: String in ingredients:
		names.append(_display_name_for_id(ing_id))
	return names

func get_output_name() -> String:
	return _display_name_for_id(result_id)

func get_description() -> String:
	return "%s -> %s" % [", ".join(get_input_names()), get_output_name()]

static func get_all_recipes() -> Array[Recipe]:
	var recipes: Array[Recipe] = []

	# Seeds -> potions
	recipes.append(Recipe.make(["seed_of_firebloom", "seed_of_firebloom", "seed_of_firebloom"], "liquid_flame", 0))
	recipes.append(Recipe.make(["seed_of_icecap", "seed_of_icecap", "seed_of_icecap"], "frost", 0))
	recipes.append(Recipe.make(["seed_of_sorrowmoss", "seed_of_sorrowmoss", "seed_of_sorrowmoss"], "toxic_gas", 0))
	recipes.append(Recipe.make(["seed_of_stormvine", "seed_of_stormvine", "seed_of_stormvine"], "levitation", 0))
	recipes.append(Recipe.make(["seed_of_sungrass", "seed_of_sungrass", "seed_of_sungrass"], "healing", 0))
	recipes.append(Recipe.make(["seed_of_earthroot", "seed_of_earthroot", "seed_of_earthroot"], "paralytic_gas", 0))
	recipes.append(Recipe.make(["seed_of_fadeleaf", "seed_of_fadeleaf", "seed_of_fadeleaf"], "mind_vision", 0))
	recipes.append(Recipe.make(["seed_of_blindweed", "seed_of_blindweed", "seed_of_blindweed"], "invisibility", 0))
	recipes.append(Recipe.make(["seed_of_dreamfoil", "seed_of_dreamfoil", "seed_of_dreamfoil"], "purity", 0))
	recipes.append(Recipe.make(["seed_of_swiftthistle", "seed_of_swiftthistle", "seed_of_swiftthistle"], "haste", 0))
	recipes.append(Recipe.make(["seed_of_starflower", "seed_of_starflower", "seed_of_starflower"], "experience", 0))

	# Stones -> scrolls
	recipes.append(Recipe.make(["augmentation", "augmentation"], "upgrade", 2))
	recipes.append(Recipe.make(["intuition", "intuition"], "identify", 0))
	recipes.append(Recipe.make(["enchantment", "enchantment"], "transmutation", 2))
	recipes.append(Recipe.make(["flock", "flock"], "mirror_image", 0))
	recipes.append(Recipe.make(["shock", "shock"], "recharging", 0))
	recipes.append(Recipe.make(["blink", "blink"], "teleportation", 0))
	recipes.append(Recipe.make(["clairvoyance", "clairvoyance"], "magic_mapping", 0))
	recipes.append(Recipe.make(["blast", "blast"], "retribution", 0))
	recipes.append(Recipe.make(["fear", "fear"], "terror", 0))
	recipes.append(Recipe.make(["deepened_sleep", "deepened_sleep"], "lullaby", 0))
	recipes.append(Recipe.make(["disarming", "disarming"], "remove_curse", 0))

	return recipes

static func find_craftable(available_items: Array) -> Array[Recipe]:
	var craftable: Array[Recipe] = []
	for recipe: Recipe in get_all_recipes():
		if recipe.can_craft(available_items):
			craftable.append(recipe)
	return craftable

static func find_recipe_for(result_item_id: String) -> Recipe:
	for recipe: Recipe in get_all_recipes():
		if recipe.result_id == result_item_id:
			return recipe
	return null

static func find_recipe(ingredients_list: Array) -> Recipe:
	for recipe: Recipe in get_all_recipes():
		if recipe.can_craft(ingredients_list):
			return recipe
	return null

static func get_known_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: Recipe in get_all_recipes():
		result.append({
			"input_names": recipe.get_input_names(),
			"output_name": recipe.get_output_name(),
			"energy_cost": recipe.energy_cost,
			"result_id": recipe.result_id,
		})
	return result

static func _display_name_for_id(item_id: String) -> String:
	var item: Item = Generator.create_item(item_id)
	if item != null:
		return item.item_name
	return item_id.replace("_", " ").capitalize()
