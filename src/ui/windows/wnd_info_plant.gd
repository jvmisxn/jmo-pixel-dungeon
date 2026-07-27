class_name WndInfoPlant
extends WndBase
## Plant information window (upstream WndInfoPlant): the plant's in-scene
## sprite next to the description. Upstream shows the plant tile image via
## WndTitledMessage; the port reuses its procedural PlantSprite.

const SPRITE_SCALE: float = 1.5

var _plant: Variant = null
var _desc: String = ""


func _init() -> void:
	window_title = "Plant"
	custom_minimum_size = Vector2(320, 130)


func setup(plant: Variant, desc: String) -> void:
	_plant = plant
	_desc = desc
	if plant != null and "plant_name" in plant:
		window_title = str(plant.plant_name).capitalize()
	if _title_label:
		_title_label.text = window_title
	refresh_content()


func _build_content() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var sprite_holder: Control = Control.new()
	sprite_holder.custom_minimum_size = Vector2(30, 32)
	sprite_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sprite: PlantSprite = PlantSprite.new()
	var plant_id: String = ""
	if _plant != null:
		plant_id = str(_plant.get("plant_id")) if _plant.get("plant_id") != null else str(_plant.get("plant_name"))
	sprite.setup_for_plant(plant_id)
	sprite.position = Vector2(15, 19)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite_holder.add_child(sprite)
	row.add_child(sprite_holder)

	var desc: Label = Label.new()
	desc.text = _desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	row.add_child(desc)
	return row
