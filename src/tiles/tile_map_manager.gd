class_name TileMapManager
extends Node2D
## Renders the dungeon level using Godot TileMapLayer nodes for GPU-batched
## rendering. Two layers (water background + terrain) replace the previous
## 2048 individual Sprite2D nodes, reducing draw calls from ~2048 to 2.
##
## The TileSet is built at runtime from the SPD tile sheet PNG for the current
## region. A second atlas source holds the water background pattern. The fog
## of war shader handles visibility — all tiles are always rendered.

const TILE_SIZE: int = 16
const ATLAS_COLUMNS: int = 16

## TileSet atlas source IDs
const SRC_TERRAIN: int = 0
const SRC_WATER_BG: int = 1

# --- References ---
## The Level data object being rendered.
var level: Variant = null
## Current region (determines tile palette).
var region: int = ConstantsData.Region.SEWERS

# --- Internal ---
var _terrain_layer: TileMapLayer = null
var _water_layer: TileMapLayer = null
var _tile_set: TileSet = null
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

## Initialize the tile map with a Level and region. Creates the TileSet and layers.
func setup(p_level: Variant, p_region: int) -> void:
	level = p_level
	region = p_region
	_clear_tiles()
	_build_tileset()
	_create_layers()
	render_full()
	_initialized = true

## Re-render the entire map (e.g., after level generation or magic mapping).
func render_full() -> void:
	if level == null or _terrain_layer == null:
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
## With TileMapLayer, all tiles are always rendered and the FogOfWar shader
## handles visibility. This method is kept for API compatibility but is now
## a no-op — the fog overlay alone controls what the player sees.
func update_tile_visibility() -> void:
	pass

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
	# Rebuild tileset for new region's tile sheet
	_build_tileset()
	if _terrain_layer:
		_terrain_layer.tile_set = _tile_set
	if _water_layer:
		_water_layer.tile_set = _tile_set
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
# TileSet Construction
# ---------------------------------------------------------------------------

func _build_tileset() -> void:
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Source 0: Main terrain tile sheet (256x256, 16 columns of 16x16 tiles)
	var sheet: Texture2D = SPDTileset.get_sheet(region)
	if sheet != null:
		var terrain_src: TileSetAtlasSource = TileSetAtlasSource.new()
		terrain_src.texture = sheet
		terrain_src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		# Create tiles for every position in the sheet
		var sheet_w: int = int(sheet.get_width()) / TILE_SIZE
		var sheet_h: int = int(sheet.get_height()) / TILE_SIZE
		for ty: int in range(sheet_h):
			for tx: int in range(sheet_w):
				var coords: Vector2i = Vector2i(tx, ty)
				terrain_src.create_tile(coords)
		_tile_set.add_source(terrain_src, SRC_TERRAIN)

	# Source 1: Water background (single 16x16 tile from water pattern)
	var water_bg_tex: Texture2D = _get_water_bg_image_texture()
	if water_bg_tex != null:
		var water_src: TileSetAtlasSource = TileSetAtlasSource.new()
		water_src.texture = water_bg_tex
		water_src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		water_src.create_tile(Vector2i(0, 0))
		_tile_set.add_source(water_src, SRC_WATER_BG)


## Get a standalone 16x16 ImageTexture for the water background.
## TileSetAtlasSource needs its own texture, so we crop the 32x32 water pattern.
func _get_water_bg_image_texture() -> Texture2D:
	var water_paths: Dictionary = {
		ConstantsData.Region.SEWERS: "res://assets/spd/environment/water0.png",
		ConstantsData.Region.PRISON: "res://assets/spd/environment/water1.png",
		ConstantsData.Region.CAVES:  "res://assets/spd/environment/water2.png",
		ConstantsData.Region.CITY:   "res://assets/spd/environment/water3.png",
		ConstantsData.Region.HALLS:  "res://assets/spd/environment/water4.png",
	}
	var path: String = water_paths.get(region, water_paths[ConstantsData.Region.SEWERS])
	if not ResourceLoader.exists(path):
		return null
	var full_tex: Texture2D = load(path) as Texture2D
	if full_tex == null:
		return null
	# Crop center 16x16 from the 32x32 tileable texture
	var src_img: Image = full_tex.get_image()
	# Ensure format matches before blit — source PNGs may be RGB8 or compressed
	if src_img.get_format() != Image.FORMAT_RGBA8:
		src_img.convert(Image.FORMAT_RGBA8)
	var cropped: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(src_img, Rect2i(8, 8, TILE_SIZE, TILE_SIZE), Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)

# ---------------------------------------------------------------------------
# Layer Construction
# ---------------------------------------------------------------------------

func _create_layers() -> void:
	# Water background layer — sits below terrain
	_water_layer = TileMapLayer.new()
	_water_layer.name = "WaterLayer"
	_water_layer.tile_set = _tile_set
	_water_layer.z_index = -1
	_water_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_water_layer)

	# Terrain layer — main tiles
	_terrain_layer = TileMapLayer.new()
	_terrain_layer.name = "TerrainLayer"
	_terrain_layer.tile_set = _tile_set
	_terrain_layer.z_index = 0
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)

	_rendered_terrain.resize(ConstantsData.LENGTH)
	_rendered_terrain.fill(-1)


func _clear_tiles() -> void:
	if _terrain_layer != null:
		_terrain_layer.queue_free()
		_terrain_layer = null
	if _water_layer != null:
		_water_layer.queue_free()
		_water_layer = null
	_rendered_terrain.clear()
	_tile_set = null

# ---------------------------------------------------------------------------
# Tile Updates
# ---------------------------------------------------------------------------

func _update_tile(pos: int) -> void:
	if level == null or _terrain_layer == null:
		return
	var terrain: int = level.map[pos]
	var x: int = ConstantsData.pos_to_x(pos)
	var y: int = ConstantsData.pos_to_y(pos)
	var cell: Vector2i = Vector2i(x, y)

	# --- Terrain layer ---
	var tile_index: int = -1
	if terrain == ConstantsData.Terrain.WATER:
		var edge_mask: int = _compute_water_edge_mask(pos)
		tile_index = SPDTileset.WATER + edge_mask
	else:
		tile_index = TerrainVisuals._terrain_to_tile.get(terrain, SPDTileset.FLOOR)

	# Convert flat tile index to atlas coordinates
	var atlas_x: int = tile_index % ATLAS_COLUMNS
	var atlas_y: int = tile_index / ATLAS_COLUMNS
	_terrain_layer.set_cell(cell, SRC_TERRAIN, Vector2i(atlas_x, atlas_y))

	# --- Water background layer ---
	if terrain == ConstantsData.Terrain.WATER:
		_water_layer.set_cell(cell, SRC_WATER_BG, Vector2i(0, 0))
	else:
		_water_layer.erase_cell(cell)


## Compute a 4-bit edge bitmask for a water cell.
## Bit 0 = north neighbor is non-water, bit 1 = east, bit 2 = south, bit 3 = west.
## Used to select the correct stitched water edge tile (indices 32-47).
func _compute_water_edge_mask(pos: int) -> int:
	if level == null:
		return 0
	var mask: int = 0
	var width: int = ConstantsData.WIDTH
	# North
	var n: int = pos - width
	if n < 0 or level.map[n] != ConstantsData.Terrain.WATER:
		mask |= 1
	# East
	var e: int = pos + 1
	if (pos % width) == (width - 1) or e >= ConstantsData.LENGTH or level.map[e] != ConstantsData.Terrain.WATER:
		mask |= 2
	# South
	var s: int = pos + width
	if s >= ConstantsData.LENGTH or level.map[s] != ConstantsData.Terrain.WATER:
		mask |= 4
	# West
	var w: int = pos - 1
	if (pos % width) == 0 or w < 0 or level.map[w] != ConstantsData.Terrain.WATER:
		mask |= 8
	return mask
