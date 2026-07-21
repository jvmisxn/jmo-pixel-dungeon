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
