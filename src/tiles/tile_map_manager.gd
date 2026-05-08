class_name TileMapManager
extends Node2D
## Renders the dungeon level using Sprite2D nodes with procedurally generated textures.
## Reads from the Level's map array and creates a visual grid of 16x16 tiles.
## Efficiently updates only changed tiles to minimize draw calls.

const TILE_SIZE: int = 16

# --- References ---
## The Level data object being rendered.
var level: Variant = null
## Current region (determines tile palette).
var region: int = ConstantsData.Region.SEWERS

# --- Internal ---
## Pool of Sprite2D nodes indexed by cell position (terrain layer).
var _tile_sprites: Array[Sprite2D] = []
## Pool of Sprite2D nodes for the water background layer (below terrain).
var _water_sprites: Array[Sprite2D] = []
## Container node for water background sprites (z_index below terrain).
var _water_layer: Node2D = null
## Track which terrain was last rendered per cell (to avoid redundant updates).
var _rendered_terrain: Array[int] = []
## Whether the map has been initialized.
var _initialized: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Tiles render behind everything else on this layer
	z_index = -10

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialize the tile map with a Level and region. Creates all tile sprites.
func setup(p_level: Variant, p_region: int) -> void:
	level = p_level
	region = p_region
	_clear_tiles()
	_create_tiles()
	render_full()
	_initialized = true

## Re-render the entire map (e.g., after level generation or magic mapping).
func render_full() -> void:
	if level == null:
		return
	for pos: int in range(ConstantsData.LENGTH):
		_update_tile(pos)
	_rendered_terrain = level.map.duplicate()

## Update only tiles whose terrain has changed since last render.
## Also updates neighbors of changed water tiles (their edge stitching may change).
func render_changed() -> void:
	if level == null or not _initialized:
		return
	var needs_update: Array[int] = []
	for pos: int in range(ConstantsData.LENGTH):
		if pos < _rendered_terrain.size() and _rendered_terrain[pos] != level.map[pos]:
			needs_update.append(pos)
			# If this tile changed to/from water, neighbors' stitching may change
			var old_terrain: int = _rendered_terrain[pos]
			var new_terrain: int = level.map[pos]
			if old_terrain == ConstantsData.Terrain.WATER or new_terrain == ConstantsData.Terrain.WATER:
				for dir: int in ConstantsData.DIRS_4:
					var n: int = pos + dir
					if n >= 0 and n < ConstantsData.LENGTH:
						if level.map[n] == ConstantsData.Terrain.WATER:
							needs_update.append(n)
	for pos: int in needs_update:
		_update_tile(pos)
		if pos < _rendered_terrain.size():
			_rendered_terrain[pos] = level.map[pos]

## Update tile visibility based on fog state.
## Tiles render at full brightness; the FogOfWar overlay alone handles dimming
## for visited/unseen cells. Previous code applied alpha 0.5 for visited tiles,
## which compounded with the fog overlay to make them much too dark.
func update_tile_visibility() -> void:
	if level == null or not _initialized:
		return
	for pos: int in range(ConstantsData.LENGTH):
		if pos < _tile_sprites.size() and _tile_sprites[pos] != null:
			var sprite: Sprite2D = _tile_sprites[pos]
			var vis: bool = level.visible[pos] or level.visited[pos] or level.mapped[pos]
			sprite.visible = vis
			sprite.modulate.a = 1.0

			# Sync water background sprite visibility with terrain
			if pos < _water_sprites.size() and _water_sprites[pos] != null:
				var is_water: bool = level.map[pos] == ConstantsData.Terrain.WATER
				_water_sprites[pos].visible = vis and is_water
				_water_sprites[pos].modulate.a = 1.0

## Update a single tile at a specific position.
func update_tile_at(pos: int) -> void:
	if pos < 0 or pos >= ConstantsData.LENGTH:
		return
	_update_tile(pos)
	if pos < _rendered_terrain.size():
		_rendered_terrain[pos] = level.map[pos]

## Change the region palette and re-render all tiles.
func set_region(p_region: int) -> void:
	region = p_region
	TerrainVisuals.clear_cache()
	render_full()

## Get the world position (pixel coords) for a cell index.
func cell_to_world(pos: int) -> Vector2:
	var x: int = ConstantsData.pos_to_x(pos)
	var y: int = ConstantsData.pos_to_y(pos)
	return Vector2(x * TILE_SIZE + TILE_SIZE / 2, y * TILE_SIZE + TILE_SIZE / 2)

## Get the cell index for a world position.
func world_to_cell(world_pos: Vector2) -> int:
	var x: int = int(world_pos.x) / TILE_SIZE
	var y: int = int(world_pos.y) / TILE_SIZE
	if x < 0 or x >= ConstantsData.WIDTH or y < 0 or y >= ConstantsData.HEIGHT:
		return -1
	return ConstantsData.xy_to_pos(x, y)

## Get pixel size of the entire map.
func get_map_pixel_size() -> Vector2:
	return Vector2(ConstantsData.WIDTH * TILE_SIZE, ConstantsData.HEIGHT * TILE_SIZE)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _create_tiles() -> void:
	# Water background layer — sits below terrain so edge tiles blend on top
	_water_layer = Node2D.new()
	_water_layer.name = "WaterLayer"
	_water_layer.z_index = -1  # Below terrain sprites (which are at z_index 0 within this node)
	add_child(_water_layer)

	_tile_sprites.resize(ConstantsData.LENGTH)
	_water_sprites.resize(ConstantsData.LENGTH)
	_rendered_terrain.resize(ConstantsData.LENGTH)
	_rendered_terrain.fill(-1)
	for pos: int in range(ConstantsData.LENGTH):
		var x: int = ConstantsData.pos_to_x(pos)
		var y: int = ConstantsData.pos_to_y(pos)
		var world_pos: Vector2 = Vector2(x * TILE_SIZE + TILE_SIZE / 2, y * TILE_SIZE + TILE_SIZE / 2)

		# Terrain sprite
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = true
		sprite.visible = false  # Hidden until FOV reveals
		sprite.position = world_pos
		add_child(sprite)
		_tile_sprites[pos] = sprite

		# Water background sprite (hidden by default, shown for water cells)
		var water_sprite: Sprite2D = Sprite2D.new()
		water_sprite.centered = true
		water_sprite.visible = false
		water_sprite.position = world_pos
		_water_layer.add_child(water_sprite)
		_water_sprites[pos] = water_sprite

func _clear_tiles() -> void:
	for sprite: Sprite2D in _tile_sprites:
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_tile_sprites.clear()
	for sprite: Sprite2D in _water_sprites:
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_water_sprites.clear()
	if _water_layer != null:
		_water_layer.queue_free()
		_water_layer = null
	_rendered_terrain.clear()

func _update_tile(pos: int) -> void:
	if level == null or pos < 0 or pos >= _tile_sprites.size():
		return
	var terrain: int = level.map[pos]
	var sprite: Sprite2D = _tile_sprites[pos]
	if sprite == null:
		return

	# Get the texture for this terrain type and region
	var tex: Texture2D = TerrainVisuals.get_texture(terrain, region)
	if tex != null:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Water background
	var water_sprite: Sprite2D = _water_sprites[pos] if pos < _water_sprites.size() else null
	if water_sprite != null:
		if terrain == ConstantsData.Terrain.WATER:
			var water_tex: Texture2D = TerrainVisuals.get_texture(ConstantsData.Terrain.WATER, region)
			if water_tex != null:
				water_sprite.texture = water_tex
				water_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			water_sprite.visible = true
		else:
			water_sprite.visible = false
