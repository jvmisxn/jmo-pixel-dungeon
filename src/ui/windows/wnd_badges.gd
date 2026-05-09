class_name WndBadges
extends WndBase
## Displays all game badges in a grid. Earned badges show colored icons with names.
## Unearned badges appear grayed out / locked.

# --- Constants ---
const BADGE_SIZE: Vector2 = Vector2(64, 72)
const GRID_COLUMNS: int = 4
const ICON_SIZE: float = 32.0

# --- Badge category colors ---
const COLOR_PROGRESS := Color(0.3, 0.7, 1.0)
const COLOR_COMBAT := Color(1.0, 0.3, 0.3)
const COLOR_COLLECTION := Color(1.0, 0.85, 0.0)
const COLOR_SKILL := Color(0.4, 1.0, 0.4)
const COLOR_DEATH := Color(0.6, 0.2, 0.7)
const COLOR_LOCKED := Color(0.3, 0.3, 0.35, 0.5)

# --- Internal ---
var _grid: GridContainer = null
var _count_label: Label = null


func _init() -> void:
	window_title = "Badges"
	custom_minimum_size = Vector2(400, 480)


func _build_content() -> Control:
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# --- Badge count header ---
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 13)
	_update_count_label()
	main.add_child(_count_label)

	var sep := HSeparator.new()
	main.add_child(sep)

	# --- Scrollable badge grid ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 340)
	main.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_populate_badges()

	return main


func _update_count_label() -> void:
	var badges_mgr: Node = _get_badges_manager()
	if badges_mgr:
		var unlocked: int = badges_mgr.get_unlocked_count()
		var total: int = badges_mgr.get_total_badge_count()
		_count_label.text = "Badges: %d / %d" % [unlocked, total]
	else:
		_count_label.text = "Badges"


func _populate_badges() -> void:
	var badges_mgr: Node = _get_badges_manager()

	# Badge IDs organized by category for display
	var badge_categories: Array[Dictionary] = [
		{ "name": "Progress", "color": COLOR_PROGRESS, "ids": [
			"first_victory", "all_classes_won", "boss_slain_1", "boss_slain_2",
			"boss_slain_3", "boss_slain_4", "boss_slain_5", "depth_10", "depth_20",
		] },
		{ "name": "Combat", "color": COLOR_COMBAT, "ids": [
			"enemies_slain_10", "enemies_slain_50", "enemies_slain_100",
			"enemies_slain_250", "piranhas_slain_5",
		] },
		{ "name": "Collection", "color": COLOR_COLLECTION, "ids": [
			"all_potions_identified", "all_scrolls_identified",
			"gold_collected_500", "gold_collected_2500", "gold_collected_5000",
			"items_collected_50",
		] },
		{ "name": "Skill", "color": COLOR_SKILL, "ids": [
			"no_armor_win", "no_food_win", "champion_win", "strength_15",
		] },
		{ "name": "Death", "color": COLOR_DEATH, "ids": [
			"first_death", "death_by_goo",
		] },
	]

	for category: Dictionary in badge_categories:
		# Category header spanning the full grid
		var cat_label := Label.new()
		cat_label.text = "-- %s --" % (category["name"] as String)
		cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cat_label.add_theme_font_size_override("font_size", 12)
		cat_label.add_theme_color_override("font_color", category["color"] as Color)
		cat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(cat_label)

		# Pad remaining columns in header row
		for _pad in range(GRID_COLUMNS - 1):
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 0)
			_grid.add_child(spacer)

		# Badge entries
		var ids: Array = category["ids"] as Array
		var cat_color: Color = category["color"] as Color
		for badge_id: String in ids:
			var is_unlocked: bool = false
			var badge_name: String = badge_id.capitalize().replace("_", " ")
			var badge_desc: String = ""

			if badges_mgr:
				is_unlocked = badges_mgr.is_unlocked(badge_id)
				if badges_mgr.has_method("get_badge_name"):
					badge_name = badges_mgr.get_badge_name(badge_id)
				if badges_mgr.has_method("get_badge_description"):
					badge_desc = badges_mgr.get_badge_description(badge_id)

			var badge_cell := _create_badge_cell(badge_name, badge_desc, cat_color, is_unlocked)
			_grid.add_child(badge_cell)

		# Pad the last row if needed
		var remainder: int = ids.size() % GRID_COLUMNS
		if remainder > 0:
			for _pad in range(GRID_COLUMNS - remainder):
				var spacer := Control.new()
				spacer.custom_minimum_size = BADGE_SIZE
				_grid.add_child(spacer)


func _create_badge_cell(badge_name: String, badge_desc: String, color: Color, unlocked: bool) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = BADGE_SIZE

	var cell_style := StyleBoxFlat.new()
	if unlocked:
		cell_style.bg_color = color.darkened(0.7)
		cell_style.bg_color.a = 0.6
		cell_style.border_color = color.darkened(0.3)
	else:
		cell_style.bg_color = Color(0.1, 0.1, 0.12, 0.5)
		cell_style.border_color = Color(0.25, 0.25, 0.3, 0.5)
	cell_style.set_border_width_all(1)
	cell_style.set_corner_radius_all(4)
	cell_style.set_content_margin_all(4)
	cell.add_theme_stylebox_override("panel", cell_style)

	# Tooltip with description
	if unlocked:
		cell.tooltip_text = "%s\n%s" % [badge_name, badge_desc]
	else:
		cell.tooltip_text = "???\n(Locked)"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(vbox)

	# Icon area
	var icon_container := CenterContainer.new()
	var icon := _BadgeIcon.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.badge_color = color if unlocked else COLOR_LOCKED
	icon.is_locked = not unlocked
	icon_container.add_child(icon)
	vbox.add_child(icon_container)

	# Name label
	var name_label := Label.new()
	if unlocked:
		name_label.text = badge_name
		name_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(BADGE_SIZE.x - 8, 0)
	vbox.add_child(name_label)

	return cell


# --- Utilities ---

func _get_badges_manager() -> Node:
	var tree: SceneTree = get_tree()
	if tree and tree.root.has_node("Badges"):
		return tree.root.get_node("Badges")
	return null

# Autoloads are accessed directly by name (e.g., GameManager, AudioManager)


# ---------------------------------------------------------------------------
# Inner class for procedural badge icon drawing
# ---------------------------------------------------------------------------

class _BadgeIcon extends Control:
	var badge_color: Color = Color.WHITE
	var is_locked: bool = false

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = min(size.x, size.y) / 2.0 - 2.0

		if is_locked:
			# Locked: draw a lock shape
			# Lock body
			var body_rect := Rect2(center.x - 6, center.y - 2, 12, 10)
			draw_rect(body_rect, badge_color, true)
			# Lock shackle (arc)
			draw_arc(Vector2(center.x, center.y - 2), 5.0, PI, TAU, 12, badge_color, 2.0)
			# Keyhole
			draw_circle(Vector2(center.x, center.y + 2), 1.5, Color(0.05, 0.05, 0.08))
		else:
			# Unlocked: draw a star / badge shape
			var points: PackedVector2Array = PackedVector2Array()
			var point_count: int = 5
			for i in (point_count * 2):
				var angle: float = (float(i) / float(point_count * 2)) * TAU - PI / 2.0
				var r: float = radius if i % 2 == 0 else radius * 0.45
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, badge_color)
			draw_polyline(points + PackedVector2Array([points[0]]), badge_color.lightened(0.3), 1.0)
