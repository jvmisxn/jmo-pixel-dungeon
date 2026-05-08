class_name SPDTileset
extends RefCounted
## Static utility class that loads SPD tile sheets and extracts individual
## 16x16 tile textures via AtlasTexture.  Tile sheets are 256x256 PNG images
## arranged in a 16-column grid (16x16 tiles each).

const TILE_SIZE: int = 16
const COLUMNS: int = 16

# --- SPD Tile Indices (from DungeonTileSheet.java) ---
# Floor row
const FLOOR: int          = 0
const FLOOR_DECO: int     = 1
const GRASS: int          = 2
const EMBERS: int         = 3
const FLOOR_SP: int       = 4

const ENTRANCE: int       = 16
const EXIT: int           = 17
const WELL: int           = 18
const EMPTY_WELL: int     = 19
const PEDESTAL: int       = 20

# Chasm
const CHASM: int          = 24

# Water
const WATER: int          = 32

# Flat walls / doors
const FLAT_WALL: int          = 48
const FLAT_WALL_DECO: int     = 49
const FLAT_BOOKSHELF: int     = 50
const FLAT_DOOR: int          = 56
const FLAT_DOOR_OPEN: int     = 57
const FLAT_DOOR_LOCKED: int   = 58
const FLAT_DOOR_CRYSTAL: int  = 59

# Flat other
const FLAT_ALCHEMY_POT: int   = 64
const FLAT_BARRICADE: int     = 65
const FLAT_HIGH_GRASS: int    = 66
const FLAT_FURROWED_GRASS: int = 67
const FLAT_STATUE: int        = 72
const FLAT_STATUE_SP: int     = 73

# --- Region → tile sheet filename ---
static var _region_names: Dictionary = {
	ConstantsData.Region.SEWERS: "sewers",
	ConstantsData.Region.PRISON: "prison",
	ConstantsData.Region.CAVES:  "caves",
	ConstantsData.Region.CITY:   "city",
	ConstantsData.Region.HALLS:  "halls",
}

# --- Cache ---
## Key: "region_index" (String) -> AtlasTexture
static var _cache: Dictionary[String, AtlasTexture] = {}
## Key: region (String) -> Texture2D (loaded sheet)
static var _sheet_cache: Dictionary[int, Texture2D] = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Return the tile sheet path for a given region.
static func get_sheet_path(region: int) -> String:
	var name: String = _region_names.get(region, "sewers")
	return "res://assets/spd/environment/tiles_%s.png" % name

## Load (and cache) the full tile sheet texture for a region.
static func get_sheet(region: int) -> Texture2D:
	if _sheet_cache.has(region):
		return _sheet_cache[region]
	var path: String = get_sheet_path(region)
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_sheet_cache[region] = tex
	return tex

## Extract a single 16x16 tile as an AtlasTexture by tile index and region.
static func get_tile(tile_index: int, region: int) -> AtlasTexture:
	var key: String = "%d_%d" % [region, tile_index]
	if _cache.has(key):
		return _cache[key]

	var sheet: Texture2D = get_sheet(region)
	if sheet == null:
		return null

	var col: int = tile_index % COLUMNS
	var row: int = tile_index / COLUMNS
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	_cache[key] = atlas
	return atlas

## Clear all cached textures.
static func clear_cache() -> void:
	_cache.clear()
	_sheet_cache.clear()
