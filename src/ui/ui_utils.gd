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
