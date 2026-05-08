class_name TerrainVisuals
extends RefCounted
## Provides 16x16 terrain tile textures by loading real SPD tile sheets.
## Falls back to a solid-color placeholder if the tile sheet cannot be loaded.
## Each region has its own color palette kept for UI / minimap use.

const TILE_SIZE: int = 16

# --- Region → water texture file (water0..water4 are 32x32 tileable textures) ---
static var _water_region_file: Dictionary = {
	ConstantsData.Region.SEWERS: "res://assets/spd/environment/water0.png",
	ConstantsData.Region.PRISON: "res://assets/spd/environment/water1.png",
	ConstantsData.Region.CAVES:  "res://assets/spd/environment/water2.png",
	ConstantsData.Region.CITY:   "res://assets/spd/environment/water3.png",
	ConstantsData.Region.HALLS:  "res://assets/spd/environment/water4.png",
}

# --- Water texture cache (region -> AtlasTexture 16x16) ---
static var _water_cache: Dictionary[int, Texture2D] = {}

# --- Terrain → SPD tile index mapping ---
static var _terrain_to_tile: Dictionary = {
	ConstantsData.Terrain.CHASM:          SPDTileset.CHASM,
	ConstantsData.Terrain.EMPTY:          SPDTileset.FLOOR,
	ConstantsData.Terrain.GRASS:          SPDTileset.GRASS,
	ConstantsData.Terrain.EMPTY_WELL:     SPDTileset.EMPTY_WELL,
	ConstantsData.Terrain.WALL:           SPDTileset.FLAT_WALL,
	ConstantsData.Terrain.DOOR:           SPDTileset.FLAT_DOOR,
	ConstantsData.Terrain.OPEN_DOOR:      SPDTileset.FLAT_DOOR_OPEN,
	ConstantsData.Terrain.ENTRANCE:       SPDTileset.ENTRANCE,
	ConstantsData.Terrain.EXIT:           SPDTileset.EXIT,
	ConstantsData.Terrain.EMBERS:         SPDTileset.EMBERS,
	ConstantsData.Terrain.LOCKED_DOOR:    SPDTileset.FLAT_DOOR_LOCKED,
	ConstantsData.Terrain.CRYSTAL_DOOR:   SPDTileset.FLAT_DOOR_CRYSTAL,
	ConstantsData.Terrain.PEDESTAL:       SPDTileset.PEDESTAL,
	ConstantsData.Terrain.WALL_DECO:      SPDTileset.FLAT_WALL_DECO,
	ConstantsData.Terrain.BARRICADE:      SPDTileset.FLAT_BARRICADE,
	ConstantsData.Terrain.EMPTY_SP:       SPDTileset.FLOOR_SP,
	ConstantsData.Terrain.HIGH_GRASS:     SPDTileset.FLAT_HIGH_GRASS,
	ConstantsData.Terrain.FURROWED_GRASS: SPDTileset.FLAT_FURROWED_GRASS,
	ConstantsData.Terrain.SECRET_DOOR:    SPDTileset.FLAT_WALL,
	ConstantsData.Terrain.SECRET_TRAP:    SPDTileset.FLOOR,
	ConstantsData.Terrain.TRAP:           SPDTileset.FLOOR,
	ConstantsData.Terrain.INACTIVE_TRAP:  SPDTileset.FLOOR,
	ConstantsData.Terrain.WATER:          SPDTileset.WATER,
	ConstantsData.Terrain.SIGN:           SPDTileset.FLOOR,
	ConstantsData.Terrain.WELL:           SPDTileset.WELL,
	ConstantsData.Terrain.STATUE:         SPDTileset.FLAT_STATUE,
	ConstantsData.Terrain.STATUE_SP:      SPDTileset.FLAT_STATUE_SP,
	ConstantsData.Terrain.BOOKSHELF:      SPDTileset.FLAT_BOOKSHELF,
	ConstantsData.Terrain.ALCHEMY:        SPDTileset.FLAT_ALCHEMY_POT,
}

# --- Region Color Palettes (kept for UI / minimap / fallback) ---
static var _palettes: Dictionary = {
	ConstantsData.Region.SEWERS: {
		"wall": Color(0.28, 0.32, 0.25),
		"wall_dark": Color(0.18, 0.22, 0.16),
		"wall_highlight": Color(0.38, 0.42, 0.34),
		"floor": Color(0.42, 0.40, 0.35),
		"floor_alt": Color(0.38, 0.36, 0.32),
		"water": Color(0.20, 0.35, 0.55),
		"water_light": Color(0.30, 0.50, 0.70),
		"grass": Color(0.25, 0.50, 0.20),
		"grass_tall": Color(0.20, 0.60, 0.15),
		"door": Color(0.55, 0.35, 0.15),
		"special": Color(0.60, 0.55, 0.30),
		"embers": Color(0.50, 0.30, 0.15),
	},
	ConstantsData.Region.PRISON: {
		"wall": Color(0.35, 0.30, 0.28),
		"wall_dark": Color(0.25, 0.20, 0.18),
		"wall_highlight": Color(0.45, 0.40, 0.38),
		"floor": Color(0.50, 0.45, 0.40),
		"floor_alt": Color(0.45, 0.40, 0.36),
		"water": Color(0.20, 0.30, 0.50),
		"water_light": Color(0.28, 0.42, 0.62),
		"grass": Color(0.30, 0.45, 0.20),
		"grass_tall": Color(0.25, 0.55, 0.15),
		"door": Color(0.50, 0.35, 0.20),
		"special": Color(0.55, 0.50, 0.35),
		"embers": Color(0.55, 0.30, 0.10),
	},
	ConstantsData.Region.CAVES: {
		"wall": Color(0.35, 0.28, 0.22),
		"wall_dark": Color(0.25, 0.18, 0.12),
		"wall_highlight": Color(0.48, 0.38, 0.30),
		"floor": Color(0.45, 0.38, 0.30),
		"floor_alt": Color(0.40, 0.34, 0.26),
		"water": Color(0.15, 0.30, 0.45),
		"water_light": Color(0.25, 0.45, 0.60),
		"grass": Color(0.30, 0.42, 0.18),
		"grass_tall": Color(0.28, 0.55, 0.15),
		"door": Color(0.50, 0.30, 0.15),
		"special": Color(0.65, 0.50, 0.25),
		"embers": Color(0.60, 0.35, 0.10),
	},
	ConstantsData.Region.CITY: {
		"wall": Color(0.40, 0.35, 0.42),
		"wall_dark": Color(0.28, 0.24, 0.30),
		"wall_highlight": Color(0.52, 0.47, 0.55),
		"floor": Color(0.50, 0.48, 0.52),
		"floor_alt": Color(0.45, 0.43, 0.48),
		"water": Color(0.18, 0.28, 0.55),
		"water_light": Color(0.28, 0.40, 0.68),
		"grass": Color(0.22, 0.40, 0.22),
		"grass_tall": Color(0.18, 0.50, 0.18),
		"door": Color(0.55, 0.40, 0.25),
		"special": Color(0.60, 0.50, 0.60),
		"embers": Color(0.55, 0.28, 0.15),
	},
	ConstantsData.Region.HALLS: {
		"wall": Color(0.30, 0.20, 0.25),
		"wall_dark": Color(0.20, 0.10, 0.15),
		"wall_highlight": Color(0.45, 0.30, 0.38),
		"floor": Color(0.40, 0.30, 0.35),
		"floor_alt": Color(0.36, 0.26, 0.32),
		"water": Color(0.30, 0.15, 0.40),
		"water_light": Color(0.45, 0.25, 0.55),
		"grass": Color(0.35, 0.20, 0.15),
		"grass_tall": Color(0.45, 0.15, 0.10),
		"door": Color(0.50, 0.25, 0.20),
		"special": Color(0.70, 0.35, 0.25),
		"embers": Color(0.65, 0.20, 0.10),
	},
}

# --- Texture Cache ---
## Key: "{region}_{terrain}" -> Texture2D (AtlasTexture or fallback ImageTexture)
static var _cache: Dictionary[String, Texture2D] = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Get the texture for a terrain type in a given region.
## Returns an AtlasTexture from the real SPD tile sheet when available,
## otherwise a solid-color fallback ImageTexture.
static func get_texture(terrain: int, region: int) -> Texture2D:
	var key: String = "%d_%d" % [region, terrain]
	if _cache.has(key):
		return _cache[key]

	var tex: Texture2D = _load_tile(terrain, region)
	_cache[key] = tex
	return tex

## Clear the texture cache (e.g., on scene change).
static func clear_cache() -> void:
	_cache.clear()
	_water_cache.clear()

## Get the palette for a region (used by UI, minimap, etc.).
static func get_palette(region: int) -> Dictionary:
	if _palettes.has(region):
		return _palettes[region]
	return _palettes[ConstantsData.Region.SEWERS]

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

static func _load_tile(terrain: int, region: int) -> Texture2D:
	# Water tiles use stitched edge variants (indices 32-47) rendered on the
	# terrain layer, with the actual water texture on a separate background
	# layer. Don't intercept here — let the tilesheet handle it. The
	# TileMapManager calls get_stitched_water_tile() and get_water_bg_texture()
	# directly for water cells.
	if terrain == ConstantsData.Terrain.WATER:
		# Return the base transparent water tile (index 32) as default.
		# TileMapManager overrides this with the stitched variant.
		var atlas_tex: AtlasTexture = SPDTileset.get_tile(SPDTileset.WATER, region)
		if atlas_tex:
			return atlas_tex

	# Look up the tile index for this terrain type
	if _terrain_to_tile.has(terrain):
		var tile_index: int = _terrain_to_tile[terrain]
		var atlas_tex: AtlasTexture = SPDTileset.get_tile(tile_index, region)
		if atlas_tex:
			return atlas_tex

	# Fallback: generate a solid-color placeholder texture
	return _create_fallback(terrain, region)

static func _create_fallback(terrain: int, region: int) -> Texture2D:
	var palette: Dictionary = get_palette(region)
	var color: Color = Color(0.5, 0.5, 0.5)

	match terrain:
		ConstantsData.Terrain.WALL, ConstantsData.Terrain.WALL_DECO:
			color = palette.get("wall", Color(0.3, 0.3, 0.3))
		ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.EMPTY_SP, \
		ConstantsData.Terrain.INACTIVE_TRAP, ConstantsData.Terrain.SECRET_TRAP, \
		ConstantsData.Terrain.SIGN:
			color = palette.get("floor", Color(0.4, 0.4, 0.35))
		ConstantsData.Terrain.WATER:
			color = palette.get("water", Color(0.2, 0.3, 0.5))
		ConstantsData.Terrain.GRASS:
			color = palette.get("grass", Color(0.25, 0.5, 0.2))
		ConstantsData.Terrain.HIGH_GRASS, ConstantsData.Terrain.FURROWED_GRASS:
			color = palette.get("grass_tall", Color(0.2, 0.6, 0.15))
		ConstantsData.Terrain.DOOR, ConstantsData.Terrain.OPEN_DOOR, \
		ConstantsData.Terrain.LOCKED_DOOR, ConstantsData.Terrain.CRYSTAL_DOOR:
			color = palette.get("door", Color(0.55, 0.35, 0.15))
		ConstantsData.Terrain.ENTRANCE:
			color = Color(0.8, 0.8, 0.2)
		ConstantsData.Terrain.EXIT:
			color = Color(0.2, 0.8, 0.2)
		ConstantsData.Terrain.CHASM:
			color = Color(0.05, 0.05, 0.1)
		ConstantsData.Terrain.EMBERS:
			color = palette.get("embers", Color(0.5, 0.3, 0.15))
		ConstantsData.Terrain.PEDESTAL, ConstantsData.Terrain.STATUE, \
		ConstantsData.Terrain.STATUE_SP:
			color = palette.get("special", Color(0.6, 0.55, 0.3))
		ConstantsData.Terrain.BOOKSHELF:
			color = Color(0.45, 0.3, 0.15)
		ConstantsData.Terrain.ALCHEMY:
			color = Color(0.5, 0.3, 0.6)
		ConstantsData.Terrain.BARRICADE:
			color = Color(0.6, 0.4, 0.2)
		ConstantsData.Terrain.WELL, ConstantsData.Terrain.EMPTY_WELL:
			color = Color(0.3, 0.4, 0.6)
		ConstantsData.Terrain.TRAP, ConstantsData.Terrain.SECRET_DOOR:
			color = palette.get("floor", Color(0.4, 0.4, 0.35))

	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

## Get the water background texture for a region (32x32 tileable pattern).
static func get_water_bg_texture(region: int) -> Texture2D:
	if _water_cache.has(region):
		return _water_cache[region]
	var path: String = _water_region_file.get(region, _water_region_file[ConstantsData.Region.SEWERS])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var palette: Dictionary = get_palette(region)
		var water_color: Color = palette.get("water", Color(0.2, 0.3, 0.5))
		var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(water_color)
		tex = ImageTexture.create_from_image(img)
	_water_cache[region] = tex
	return tex

## Get a stitched water edge tile for a given edge bitmask.
static func get_stitched_water_tile(edge_mask: int, region: int) -> Texture2D:
	# Water edge tiles are indices 32-47 in SPD tilesheet (4-bit edge mask)
	var tile_index: int = SPDTileset.WATER + edge_mask
	var atlas_tex: AtlasTexture = SPDTileset.get_tile(tile_index, region)
	if atlas_tex:
		return atlas_tex
	# Fallback to base water color
	return get_water_bg_texture(region)
