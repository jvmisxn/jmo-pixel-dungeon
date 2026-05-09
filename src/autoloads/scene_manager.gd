class_name SceneManagerNode
extends Node
## Centralized scene transition manager.
## Eliminates get_parent() / get_tree().root.add_child() anti-patterns.
## All scene transitions go through this autoload — "signal up, call down."

## Emitted after a scene transition completes (new scene is ready).
signal scene_changed(new_scene: Node)

## The currently active scene (top-level game screen).
var current_scene: Node = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Transition to a new scene from a GDScript class.
## The old scene is freed. Metadata can be passed via the meta dictionary.
## Returns the new scene node.
func go_to(scene_script: GDScript, scene_name: String = "", meta: Dictionary = {}) -> Node:
	var new_scene: Node = scene_script.new()
	if scene_name != "":
		new_scene.name = scene_name
	# Apply metadata
	for key: String in meta:
		new_scene.set_meta(key, meta[key])
	_do_transition(new_scene)
	return new_scene

## Transition to an already-instantiated scene node.
## Use this when the caller needs to configure the scene before adding it.
func go_to_node(new_scene: Node) -> void:
	_do_transition(new_scene)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _do_transition(new_scene: Node) -> void:
	var root: Node = get_tree().root
	# Free the old scene
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
	# Defer add_child so it works even when called from _ready()
	root.add_child.call_deferred(new_scene)
	current_scene = new_scene
	scene_changed.emit(new_scene)
