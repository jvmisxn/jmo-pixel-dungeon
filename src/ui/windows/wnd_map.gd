class_name WndMap
extends WndBase
## Large centered map window that shows an expanded version of the current minimap.

const MIN_MAP_SCALE: float = 6.0
const MAX_MAP_SCALE: float = 15.0
const MAP_VIEWPORT_FRACTION: float = 0.94

func _init() -> void:
	window_title = "Map"

func _build_content() -> Control:
	var container: VBoxContainer = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)

	var map_frame: PanelContainer = PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.06, 0.06, 0.07, 0.96)
	frame_style.border_color = Color(0.42, 0.38, 0.32)
	frame_style.set_border_width_all(1)
	frame_style.content_margin_left = 4.0
	frame_style.content_margin_right = 4.0
	frame_style.content_margin_top = 4.0
	frame_style.content_margin_bottom = 4.0
	map_frame.add_theme_stylebox_override("panel", frame_style)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var minimap: Minimap = Minimap.new()
	var map_scale: float = _compute_map_scale()
	minimap.custom_minimum_size = Vector2(Minimap.MAP_SIZE * map_scale, Minimap.MAP_SIZE * map_scale)
	minimap.size = minimap.custom_minimum_size
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate_map(minimap)
	center.add_child(minimap)
	map_frame.add_child(center)
	container.add_child(map_frame)

	var hint: Label = Label.new()
	hint.text = "Visited areas stay dim. Visible enemies are red, you are white."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.82, 0.78, 0.68))
	container.add_child(hint)

	return container

func _compute_map_scale() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return MIN_MAP_SCALE
	var max_pixels: float = minf(viewport_size.x, viewport_size.y) * MAP_VIEWPORT_FRACTION
	var scale: float = floor(max_pixels / float(Minimap.MAP_SIZE))
	return clampf(scale, MIN_MAP_SCALE, MAX_MAP_SCALE)

func _populate_map(minimap: Minimap) -> void:
	if minimap == null or GameManager == null or GameManager.current_level == null:
		return
	var level_ref: Variant = GameManager.current_level
	var level_map: Array[int] = level_ref.map if level_ref.get("map") != null else []
	var visited: Array[bool] = level_ref.visited if level_ref.get("visited") != null else []
	var visible_cells: Array[bool] = level_ref.visible if level_ref.get("visible") != null else []
	var hero_ref: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
	var hero_pos: int = hero_ref.pos if hero_ref != null else -1
	var mob_positions: Array[int] = []
	var party_positions: Array[int] = []
	if level_ref.has_method("get_mobs"):
		for mob_ref: Variant in level_ref.get_mobs():
			if mob_ref != null and is_instance_valid(mob_ref) and mob_ref.get("pos") != null:
				mob_positions.append(int(mob_ref.pos))
	if GameManager and GameManager.has_method("get_active_heroes"):
		for party_hero: Node in GameManager.get_active_heroes():
			if party_hero != null:
				party_positions.append(int(party_hero.pos))
	minimap.update_map(level_map, visited, visible_cells, hero_pos, mob_positions, party_positions)
