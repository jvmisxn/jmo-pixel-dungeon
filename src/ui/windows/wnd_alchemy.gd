class_name WndAlchemy
extends WndBase
## Alchemy crafting window. Allows selecting ingredients and brewing recipes.

var _hero: Hero = null
var _ingredient_slots: Array[Button] = []
var _ingredient_icons: Array[ItemSlot] = []
var _ingredients: Array = [null, null, null]  # Up to 3 ingredient items
var _result_label: Label = null
var _result_preview: ItemSlot = null
var _brew_button: Button = null
var _recipe_list: VBoxContainer = null

const MAX_INGREDIENTS: int = 3


func _init() -> void:
	window_title = "Alchemy"
	custom_minimum_size = Vector2(400, 420)


func _build_content() -> Control:
	_hero = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)

	# --- Ingredient Slots ---
	var ing_label: Label = Label.new()
	ing_label.text = "Ingredients:"
	main.add_child(ing_label)

	var ing_row: HBoxContainer = HBoxContainer.new()
	ing_row.add_theme_constant_override("separation", 8)
	ing_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(ing_row)

	for i: int in range(MAX_INGREDIENTS):
		var slot_btn: Button = Button.new()
		slot_btn.custom_minimum_size = Vector2(64, 64)
		slot_btn.text = "+"
		slot_btn.tooltip_text = "Click to add ingredient"
		slot_btn.pressed.connect(_on_ingredient_slot_pressed.bind(i))
		var icon_holder: CenterContainer = CenterContainer.new()
		icon_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_slot: ItemSlot = ItemSlot.new()
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(icon_slot)
		slot_btn.add_child(icon_holder)
		ing_row.add_child(slot_btn)
		_ingredient_slots.append(slot_btn)
		_ingredient_icons.append(icon_slot)

	# --- Arrow + Result Preview ---
	var result_row: HBoxContainer = HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 12)
	main.add_child(result_row)

	var arrow_label: Label = Label.new()
	arrow_label.text = ">>>"
	arrow_label.add_theme_font_size_override("font_size", 20)
	result_row.add_child(arrow_label)

	_result_preview = ItemSlot.new()
	_result_preview.custom_minimum_size = Vector2(64, 64)
	_result_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_row.add_child(_result_preview)

	_result_label = Label.new()
	_result_label.text = "No recipe found"
	_result_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	result_row.add_child(_result_label)

	# --- Brew Button ---
	_brew_button = Button.new()
	_brew_button.text = "Brew"
	_brew_button.custom_minimum_size = Vector2(120, 36)
	_brew_button.disabled = true
	_brew_button.pressed.connect(_on_brew_pressed)
	var brew_center: CenterContainer = CenterContainer.new()
	brew_center.add_child(_brew_button)
	main.add_child(brew_center)

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	# --- Known Recipes List ---
	var recipes_label: Label = Label.new()
	recipes_label.text = "Known Recipes:"
	main.add_child(recipes_label)

	var recipe_scroll: ScrollContainer = ScrollContainer.new()
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_scroll.custom_minimum_size = Vector2(0, 120)
	main.add_child(recipe_scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.add_child(_recipe_list)

	_populate_known_recipes()

	return main


func _on_ingredient_slot_pressed(slot_idx: int) -> void:
	if _ingredients[slot_idx] != null:
		# Remove ingredient
		_ingredients[slot_idx] = null
		_ingredient_slots[slot_idx].text = "+"
		_ingredient_slots[slot_idx].tooltip_text = "Click to add ingredient"
		if slot_idx < _ingredient_icons.size():
			_ingredient_icons[slot_idx].item = null
		_check_recipe()
		return

	# Open ingredient picker
	var picker: IngredientPicker = IngredientPicker.new()
	picker.setup(_hero, _ingredients)
	picker.ingredient_selected.connect(_on_ingredient_selected.bind(slot_idx))
	open_sub_window.emit(picker)


func _on_ingredient_selected(item: Variant, slot_idx: int) -> void:
	if item == null:
		return
	_ingredients[slot_idx] = item
	_ingredient_slots[slot_idx].text = ""
	_ingredient_slots[slot_idx].tooltip_text = ConstantsData.get_prop(item, "item_name", "?")
	if slot_idx < _ingredient_icons.size():
		_ingredient_icons[slot_idx].item = item
	_check_recipe()


func _check_recipe() -> void:
	# Gather non-null ingredients
	var active_ingredients: Array = []
	for ing: Variant in _ingredients:
		if ing != null:
			active_ingredients.append(ing)

	if active_ingredients.is_empty():
		_result_label.text = "No recipe found"
		_result_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_result_preview.item = null
		_brew_button.disabled = true
		return

	# Try to find a matching recipe via Recipe.find_recipe()
	var recipe: Recipe = _find_recipe_static(active_ingredients)
	if recipe != null:
		var result: Item = Generator.create_item(recipe.result_id)
		_result_label.text = recipe.get_output_name()
		_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		_result_preview.item = result
		_brew_button.disabled = false
	else:
		_result_label.text = "No recipe found"
		_result_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_result_preview.item = null
		_brew_button.disabled = true


func _find_recipe_static(ingredients: Array) -> Recipe:
	var recipe_script: GDScript = load("res://src/items/recipe.gd") as GDScript
	if recipe_script and recipe_script.has_method("find_recipe"):
		return recipe_script.find_recipe(ingredients)
	return null


func _on_brew_pressed() -> void:
	if not _hero or not _hero.belongings:
		return

	var active_ingredients: Array = []
	for ing: Variant in _ingredients:
		if ing != null:
			active_ingredients.append(ing)

	var recipe: Recipe = _find_recipe_static(active_ingredients)
	if recipe == null:
		return

	var result: Item = recipe.craft(_hero, active_ingredients)
	if result == null:
		return
	_hero.belongings.add_item(result)
	var toolkit: Variant = _hero.belongings.get_equipped_artifact() if _hero.belongings.has_method("get_equipped_artifact") else null
	if toolkit != null and toolkit.item_id == "alchemists_toolkit" and toolkit.has_method("on_craft"):
		toolkit.on_craft(recipe.energy_cost)

	if MessageLog:
		var craft_msg: String = "You brewed a %s!" % result.item_name
		if recipe.energy_cost > 0:
			craft_msg += " (%d energy)" % recipe.energy_cost
		MessageLog.add(craft_msg)
	if EventBus:
		EventBus.item_picked_up.emit(result.item_name)

	# Reset slots
	_ingredients = [null, null, null]
	for i: int in range(MAX_INGREDIENTS):
		_ingredient_slots[i].text = "+"
		_ingredient_slots[i].tooltip_text = "Click to add ingredient"
		if i < _ingredient_icons.size():
			_ingredient_icons[i].item = null
	_check_recipe()


func _populate_known_recipes() -> void:
	if not _recipe_list:
		return

	# Try to load recipes from the recipe system
	var recipe_script: GDScript = load("res://src/items/recipe.gd") as GDScript
	if recipe_script and recipe_script.has_method("get_known_recipes"):
		var recipes: Array = recipe_script.get_known_recipes()
		for recipe: Dictionary in recipes:
			var row: Label = Label.new()
			var inputs_str: String = ", ".join(recipe.get("input_names", []))
			var output_str: String = recipe.get("output_name", "?")
			var energy_cost: int = recipe.get("energy_cost", 0)
			row.text = "%s  ->  %s%s" % [inputs_str, output_str, "" if energy_cost <= 0 else "  (%d energy)" % energy_cost]
			row.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			_recipe_list.add_child(row)
	else:
		var placeholder: Label = Label.new()
		placeholder.text = "No recipes discovered yet."
		placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_recipe_list.add_child(placeholder)


# --- Inner class: Ingredient Picker ---
class IngredientPicker:
	extends WndBase

	signal ingredient_selected(item: Variant)

	var _hero_ref: Hero = null
	var _excluded: Array = []

	func _init() -> void:
		window_title = "Select Ingredient"
		custom_minimum_size = Vector2(300, 280)

	func setup(hero: Hero, already_selected: Array) -> void:
		_hero_ref = hero
		_excluded = already_selected

	func _build_content() -> Control:
		if not _hero_ref or not _hero_ref.belongings:
			var empty: Label = Label.new()
			empty.text = "No items available."
			return empty

		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)

		for item: Variant in _hero_ref.belongings.backpack:
			# Skip items already used as ingredients
			if item in _excluded:
				continue
			# Only show seeds, potions, stones, and misc as alchemy inputs
			var cat: int = ConstantsData.get_prop(item, "category", -1)
			if cat not in [
				ConstantsData.ItemCategory.SEED,
				ConstantsData.ItemCategory.POTION,
				ConstantsData.ItemCategory.STONE,
				ConstantsData.ItemCategory.MISC,
			]:
				continue

			var row: HBoxContainer = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var icon_slot: ItemSlot = ItemSlot.new()
			icon_slot.item = item
			icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon_slot)

			var name_lbl: Label = Label.new()
			name_lbl.text = ConstantsData.get_prop(item, "item_name", "Unknown")
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)

			var select_btn: Button = Button.new()
			select_btn.text = "Select"
			select_btn.pressed.connect(_on_select_item.bind(item))
			row.add_child(select_btn)

			list.add_child(row)

		if list.get_child_count() == 0:
			var empty: Label = Label.new()
			empty.text = "No suitable ingredients in inventory."
			list.add_child(empty)

		return scroll

	func _on_select_item(item: Variant) -> void:
		ingredient_selected.emit(item)
		close_window()
