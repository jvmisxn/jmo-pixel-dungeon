class_name Minimap
extends TextureRect
## Small map overview showing the 32x32 level as a tiny image.
## Each cell renders as 2x2 pixels resulting in a 64x64 image.
## Toggleable — can appear in the sidebar or as an overlay.
## Updates when FOV changes or hero moves.

# --- Constants ---
const CELL_SIZE: int = 2
const MAP_SIZE: int = ConstantsData.WIDTH * CELL_SIZE  # 64

# Colors for terrain types
const COLOR_WALL: Color = Color(0.2, 0.2, 0.25)
const COLOR_FLOOR: Color = Color(0.55, 0.55, 0.5)
const COLOR_DOOR: Color = Color(0.6, 0.35, 0.15)
const COLOR_WATER: Color = Color(0.2, 0.35, 0.7)
const COLOR_ENTRANCE: Color = Color(0.2, 0.8, 0.3)
const COLOR_EXIT: Color = Color(0.9, 0.2, 0.2)
const COLOR_HERO: Color = Color.WHITE
const COLOR_MOB: Color = Color(1.0, 0.2, 0.2)
const COLOR_UNEXPLORED: Color = Color(0.05, 0.05, 0.08)
const COLOR_GRASS: Color = Color(0.25, 0.5, 0.2)
const COLOR_TRAP: Color = Color(0.8, 0.5, 0.1)

# --- State ---
var _image: Image = null
var _image_texture: ImageTexture = null
var _is_visible: bool = true
var _blink_timer: float = 0.0
var _hero_blink_on: bool = true

# --- Cached level data references ---
var _level_map: Array[int] = []        # Flat array of terrain ints
var _visited: Array[bool] = []         # Bool array of visited cells
var _visible_cells: Array[bool] = []   # Bool array of currently visible cells
var _hero_pos: int = -1
var _mob_positions: Array[int] = []


func _ready() -> void:
	name = "Minimap"
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Create the image and texture
	_image = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	_image.fill(COLOR_UNEXPLORED)
	_image_texture = ImageTexture.create_from_image(_image)
	texture = _image_texture

	_connect_signals()


func _connect_signals() -> void:
	var event_bus: Node = UIUtils.get_event_bus()
	if event_bus:
		event_bus.hero_moved.connect(_on_hero_moved)
		event_bus.level_changed.connect(_on_level_changed)


func _process(delta: float) -> void:
	if not _is_visible:
		return

	# Blink the hero position
	_blink_timer += delta
	if _blink_timer >= 0.4:
		_blink_timer = 0.0
		_hero_blink_on = not _hero_blink_on
		_draw_hero()
		_image_texture.update(_image)


# --- Public API ---

## Toggle minimap visibility.
func toggle_visible() -> void:
	_is_visible = not _is_visible
	visible = _is_visible


## Set visibility directly.
func set_minimap_visible(vis: bool) -> void:
	_is_visible = vis
	visible = vis


## Full redraw of the minimap from current level data.
func update_map(level_map: Array[int], visited: Array[bool], visible_cells_arr: Array[bool], hero_pos: int, mob_positions: Array[int] = []) -> void:
	_level_map = level_map
	_visited = visited
	_visible_cells = visible_cells_arr
	_hero_pos = hero_pos
	_mob_positions = mob_positions
	_redraw()


## Partial update when FOV changes (hero moves).
func update_fov(visible_cells_arr: Array[bool], hero_pos: int, mob_positions: Array[int] = []) -> void:
	_visible_cells = visible_cells_arr
	_hero_pos = hero_pos
	_mob_positions = mob_positions
	_redraw()


# --- Rendering ---

func _redraw() -> void:
	_image.fill(COLOR_UNEXPLORED)

	var width: int = ConstantsData.WIDTH
	var height: int = ConstantsData.HEIGHT

	for y: int in range(height):
		for x: int in range(width):
			var pos: int = y * width + x
			if pos >= _level_map.size():
				continue

			# Only draw visited or currently visible cells
			var is_visited: bool = false
			if pos < _visited.size():
				is_visited = _visited[pos]
			var is_visible_cell: bool = false
			if pos < _visible_cells.size():
				is_visible_cell = _visible_cells[pos]

			if not is_visited and not is_visible_cell:
				continue

			var terrain: int = _level_map[pos]
			var color: Color = _terrain_to_color(terrain)

			# Dim visited-but-not-visible cells
			if not is_visible_cell:
				color = color.darkened(0.4)

			_draw_cell(x, y, color)

	# Draw mobs (only in visible cells)
	for mob_pos: int in _mob_positions:
		if mob_pos >= 0 and mob_pos < _visible_cells.size():
			if _visible_cells[mob_pos]:
				var mx: int = mob_pos % width
				var my: int = mob_pos / width
				_draw_cell(mx, my, COLOR_MOB)

	# Draw hero
	_draw_hero()

	_image_texture.update(_image)


func _draw_hero() -> void:
	if _hero_pos < 0:
		return
	var width: int = ConstantsData.WIDTH
	var hx: int = _hero_pos % width
	var hy: int = _hero_pos / width
	var color: Color = COLOR_HERO if _hero_blink_on else _terrain_to_color(_level_map[_hero_pos] if _hero_pos < _level_map.size() else 0)
	_draw_cell(hx, hy, color)


func _draw_cell(x: int, y: int, color: Color) -> void:
	var px: int = x * CELL_SIZE
	var py: int = y * CELL_SIZE
	for dy: int in range(CELL_SIZE):
		for dx: int in range(CELL_SIZE):
			var final_x: int = px + dx
			var final_y: int = py + dy
			if final_x < MAP_SIZE and final_y < MAP_SIZE:
				_image.set_pixel(final_x, final_y, color)


func _terrain_to_color(terrain: int) -> Color:
	match terrain:
		ConstantsData.Terrain.WALL, ConstantsData.Terrain.WALL_DECO:
			return COLOR_WALL
		ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.EMPTY_SP, \
		ConstantsData.Terrain.PEDESTAL, ConstantsData.Terrain.EMBERS:
			return COLOR_FLOOR
		ConstantsData.Terrain.DOOR, ConstantsData.Terrain.OPEN_DOOR, \
		ConstantsData.Terrain.LOCKED_DOOR:
			return COLOR_DOOR
		ConstantsData.Terrain.SECRET_DOOR:
			return COLOR_WALL  # Secret doors look like walls until discovered
		ConstantsData.Terrain.WATER:
			return COLOR_WATER
		ConstantsData.Terrain.ENTRANCE:
			return COLOR_ENTRANCE
		ConstantsData.Terrain.EXIT:
			return COLOR_EXIT
		ConstantsData.Terrain.GRASS, ConstantsData.Terrain.HIGH_GRASS, \
		ConstantsData.Terrain.FURROWED_GRASS:
			return COLOR_GRASS
		ConstantsData.Terrain.TRAP:
			return COLOR_TRAP
		ConstantsData.Terrain.SECRET_TRAP:
			return COLOR_FLOOR  # Secret traps look like floor until revealed
		ConstantsData.Terrain.CHASM:
			return COLOR_UNEXPLORED
		_:
			return COLOR_FLOOR


# --- Signal Callbacks ---

func _on_hero_moved(new_pos: int) -> void:
	# Pull current level data from GameManager and refresh the minimap
	var gm: Node = UIUtils.get_game_manager()
	if gm == null:
		return
	var level: Variant = gm.get("current_level")
	if level == null:
		return
	_hero_pos = new_pos
	# Update level data references if available
	if level.get("map") != null:
		_level_map.assign(level.map)
	if level.get("visited") != null:
		_visited.assign(level.visited)
	if level.get("visible_cells") != null:
		_visible_cells.assign(level.visible_cells)
	# Get mob positions
	_mob_positions.clear()
	if level.has_method("get_mobs"):
		for m: Variant in level.get_mobs():
			if m != null and m.get("pos") != null:
				_mob_positions.append(m.pos)
	_redraw()


func _on_level_changed() -> void:
	_level_map.clear()
	_visited.clear()
	_visible_cells.clear()
	_hero_pos = -1
	_mob_positions.clear()
	_image.fill(COLOR_UNEXPLORED)
	_image_texture.update(_image)
