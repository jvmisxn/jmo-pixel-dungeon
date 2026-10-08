class_name UIUtils
extends RefCounted
## Shared static utility methods for UI scripts.
## Eliminates duplicated helpers (e.g., _get_autoload) across HUD, StatusPane,
## Minimap, GameLogDisplay, and window files.


## Safely get an autoload node by name from the scene tree.
## Returns null if the tree isn't ready or the autoload doesn't exist.
static func get_autoload(autoload_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/" + autoload_name)


## Shorthand for getting the GameManager autoload.
static func get_game_manager() -> Node:
	return get_autoload("GameManager")


## Shorthand for getting the hero from GameManager.
static func get_hero() -> Node:
	var gm: Node = get_game_manager()
	if gm and gm.get("hero") != null:
		return gm.hero
	return null


## Shorthand for getting the EventBus autoload.
static func get_event_bus() -> Node:
	return get_autoload("EventBus")


## Return a nearest-filtered AtlasTexture for a region in an SPD atlas.
static func atlas_texture(path: String, region: Rect2) -> AtlasTexture:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas


## Build a reusable SPD chrome StyleBoxTexture from a region.
static func chrome_stylebox(region: Rect2, margins: Vector4 = Vector4(4, 4, 4, 4), content: Vector4 = Vector4(6, 6, 4, 4), modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var chrome: Texture2D = load("res://assets/spd/interfaces/chrome.png") as Texture2D
	var style := StyleBoxTexture.new()
	style.texture = chrome
	style.region_rect = region
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	style.modulate_color = modulate
	return style

## Build a toolbar.png-backed StyleBoxTexture.
static func toolbar_stylebox(region: Rect2, margins: Vector4 = Vector4(5, 5, 5, 5), content: Vector4 = Vector4(4, 4, 4, 4), modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var toolbar: Texture2D = load("res://assets/spd/interfaces/toolbar.png") as Texture2D
	var style := StyleBoxTexture.new()
	style.texture = toolbar
	style.region_rect = region
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	style.modulate_color = modulate
	return style


# ---------------------------------------------------------------------------
# Scaled SPD chrome (window frames and buttons)
# ---------------------------------------------------------------------------

const CHROME_PATH: String = "res://assets/spd/interfaces/chrome.png"
const ICONS_PATH: String = "res://assets/spd/interfaces/icons.png"
## Pixel scale for window chrome so frames match the zoomed tile art.
const CHROME_SCALE: int = 2

## Upstream Chrome.java nine-patch regions (x, y, w, h) and slice margins.
const CHROME_WINDOW: Rect2 = Rect2(0, 0, 20, 20)
const CHROME_WINDOW_MARGIN: int = 6
const CHROME_RED_BUTTON: Rect2 = Rect2(38, 0, 6, 6)
const CHROME_GREY_BUTTON: Rect2 = Rect2(38, 6, 6, 6)
const CHROME_BUTTON_MARGIN: int = 2
## Upstream Icons.CLOSE region in interfaces/icons.png.
const ICON_CLOSE: Rect2 = Rect2(80, 32, 11, 11)

static var _scaled_textures: Dictionary = {}


## Nearest-neighbour upscale of a texture, cached per path and scale, so
## nine-patch borders draw at whole-pixel multiples of the source art.
static func scaled_texture(path: String, pixel_scale: int) -> Texture2D:
	var key: String = "%s@%d" % [path, pixel_scale]
	if _scaled_textures.has(key):
		return _scaled_textures[key] as Texture2D
	var source: Texture2D = load(path) as Texture2D
	if source == null:
		return null
	if pixel_scale <= 1:
		_scaled_textures[key] = source
		return source
	var image: Image = source.get_image()
	if image == null:
		return source
	if image.is_compressed():
		image.decompress()
	image.resize(image.get_width() * pixel_scale, image.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_scaled_textures[key] = texture
	return texture


## SPD chrome nine-patch drawn at CHROME_SCALE. `slice` is the source-pixel
## border; `content` is extra padding (screen pixels) inside that border.
static func scaled_chrome_stylebox(region: Rect2, slice: int, content: Vector4 = Vector4.ZERO, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var s: float = float(CHROME_SCALE)
	var style := StyleBoxTexture.new()
	style.texture = scaled_texture(CHROME_PATH, CHROME_SCALE)
	style.region_rect = Rect2(region.position * s, region.size * s)
	style.set_texture_margin_all(slice * s)
	style.content_margin_left = slice * s + content.x
	style.content_margin_top = slice * s + content.y
	style.content_margin_right = slice * s + content.z
	style.content_margin_bottom = slice * s + content.w
	style.modulate_color = modulate
	return style


## Icon from interfaces/icons.png drawn at CHROME_SCALE.
static func scaled_icon(region: Rect2) -> AtlasTexture:
	var s: float = float(CHROME_SCALE)
	var atlas := AtlasTexture.new()
	atlas.atlas = scaled_texture(ICONS_PATH, CHROME_SCALE)
	atlas.region = Rect2(region.position * s, region.size * s)
	atlas.filter_clip = true
	return atlas
