class_name WndProfileIconPicker
extends WndBase
## Profile icon picker showing unlocked and locked icons in one grid.

signal icon_selected(icon_id: String)

const GRID_COLUMNS: int = 3
const CELL_SIZE: Vector2 = Vector2(108, 118)
const PROFILE_ICON_SPRITES: Dictionary = {
	"warrior": "res://assets/spd/sprites/warrior.png",
	"mage": "res://assets/spd/sprites/mage.png",
	"rogue": "res://assets/spd/sprites/rogue.png",
	"huntress": "res://assets/spd/sprites/huntress.png",
	"duelist": "res://assets/spd/sprites/duelist.png",
	"rat": "res://assets/spd/sprites/rat.png",
	"gnoll": "res://assets/spd/sprites/gnoll.png",
	"crab": "res://assets/spd/sprites/crab.png",
	"skeleton": "res://assets/spd/sprites/skeleton.png",
	"goo": "res://assets/spd/sprites/goo.png",
}

class _LockBadge extends Control:
	func _draw() -> void:
		var fill_color: Color = Color(0.12, 0.12, 0.14, 0.95)
		var border_color: Color = Color(0.75, 0.75, 0.82, 0.95)
		draw_circle(Vector2(9, 9), 9.0, fill_color)
		draw_arc(Vector2(9, 9), 9.0, 0.0, TAU, 18, border_color, 1.0)
		draw_rect(Rect2(5, 8, 8, 6), border_color, true)
		draw_arc(Vector2(9, 8), 3.5, PI, TAU, 12, fill_color, 2.0)
		draw_arc(Vector2(9, 8), 3.5, PI, TAU, 12, border_color, 1.2)

func _init() -> void:
	window_title = "Choose Icon"
	custom_minimum_size = Vector2(420, 520)

func _build_content() -> Control:
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(grid)

	for icon_id: String in ["warrior", "mage", "rogue", "huntress", "duelist", "rat", "gnoll", "crab", "skeleton", "goo"]:
		grid.add_child(_create_icon_cell(icon_id))

	return main

func _create_icon_cell(icon_id: String) -> PanelContainer:
	var unlocked: bool = PlayerProfile != null and PlayerProfile.has_method("is_profile_icon_unlocked") and PlayerProfile.is_profile_icon_unlocked(icon_id)
	var selected: bool = PlayerProfile != null and PlayerProfile.has_method("get_selected_icon_id") and PlayerProfile.get_selected_icon_id() == icon_id

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CELL_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.15, 0.13, 0.9) if unlocked else Color(0.09, 0.09, 0.1, 0.82)
	style.border_color = Color(1.0, 0.85, 0.3) if selected else (Color(0.48, 0.42, 0.32) if unlocked else Color(0.28, 0.28, 0.3))
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var icon_holder := Panel.new()
	icon_holder.custom_minimum_size = Vector2(0, 60)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.08, 0.08, 0.09, 0.9)
	icon_style.border_color = Color(0.25, 0.25, 0.28)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(3)
	icon_holder.add_theme_stylebox_override("panel", icon_style)
	box.add_child(icon_holder)

	var circular_icon_script: GDScript = load("res://src/ui/components/circular_icon_view.gd") as GDScript
	var icon_rect: Variant = circular_icon_script.new() if circular_icon_script else TextureRect.new()
	icon_rect.position = Vector2(14, 8)
	icon_rect.size = Vector2(36, 36)
	icon_rect.texture = _get_profile_icon_texture(icon_id)
	icon_rect.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.45, 0.45, 0.48, 0.95)
	if icon_rect.has_method("set_ring"):
		icon_rect.set_ring(Color(0.4, 0.36, 0.3), 0.03)
	if icon_rect.has_method("set_crop_adjustment"):
		if ["warrior", "mage", "rogue", "huntress", "duelist"].has(icon_id):
			icon_rect.set_crop_adjustment(1.24, Vector2(0.035, -0.03))
		else:
			icon_rect.set_crop_adjustment(1.35, Vector2.ZERO)
	icon_holder.add_child(icon_rect)

	if not unlocked:
		var lock_badge := _LockBadge.new()
		lock_badge.position = Vector2(icon_rect.position.x + icon_rect.size.x - 10, icon_rect.position.y + icon_rect.size.y - 10)
		lock_badge.custom_minimum_size = Vector2(18, 18)
		lock_badge.size = Vector2(18, 18)
		icon_holder.add_child(lock_badge)

	var name_label := Label.new()
	name_label.text = PlayerProfile.get_profile_icon_display_name(icon_id) if PlayerProfile and PlayerProfile.has_method("get_profile_icon_display_name") else icon_id.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86) if unlocked else Color(0.64, 0.66, 0.7))
	box.add_child(name_label)

	var choose_button := WndBase.create_spd_button("Choose")
	choose_button.custom_minimum_size = Vector2(0, 30)
	choose_button.disabled = not unlocked or selected
	choose_button.text = "Selected" if selected else "Choose"
	choose_button.pressed.connect(func() -> void:
		icon_selected.emit(icon_id)
		close_window()
	)
	box.add_child(choose_button)

	return panel

func _get_profile_icon_texture(icon_id: String) -> Texture2D:
	var sheet_path: String = str(PROFILE_ICON_SPRITES.get(icon_id, PROFILE_ICON_SPRITES["warrior"]))
	if not ResourceLoader.exists(sheet_path):
		return null
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var region: Rect2i = Rect2i(0, 90, 12, 15)
	match icon_id:
		"warrior", "mage", "rogue", "huntress", "duelist":
			region = Rect2i(0, 90, 12, 15)
		"rat":
			region = Rect2i(0, 0, 16, 15)
		"gnoll":
			region = Rect2i(0, 0, 12, 15)
		"crab":
			region = Rect2i(0, 0, 16, 16)
		"skeleton":
			region = Rect2i(0, 0, 12, 15)
		"goo":
			region = Rect2i(0, 0, 16, 14)
		_:
			region = Rect2i(0, 90, 12, 15)
	var source_image: Image = sheet.get_image()
	if source_image == null:
		return sheet
	var cropped_image: Image = source_image.get_region(region)
	return ImageTexture.create_from_image(cropped_image)
