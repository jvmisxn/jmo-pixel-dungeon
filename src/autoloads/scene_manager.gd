class_name SceneManagerNode
extends Node
## Centralized scene transition manager.
## Eliminates get_parent() / get_tree().root.add_child() anti-patterns.
## All scene transitions go through this autoload — "signal up, call down."

## Emitted after a scene transition completes (new scene is ready).
signal scene_changed(new_scene: Node)

## The currently active scene (top-level game screen).
var current_scene: Node = null

func _ready() -> void:
	if current_scene == null:
		var tree: SceneTree = get_tree()
		if tree != null:
			current_scene = tree.current_scene

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
	call_deferred("_finalize_transition", new_scene)

func _finalize_transition(new_scene: Node) -> void:
	if new_scene == null or not is_instance_valid(new_scene):
		return
	# Keep Godot's SceneTree.current_scene in sync with our tracked scene.
	# We add scenes via root.add_child() (not change_scene_to_*), so without
	# this the engine's current_scene stays pinned to the original MainScene,
	# and consumers that read get_tree().current_scene (e.g. TurnManager's
	# on_mob_action refresh) resolve the wrong node.
	# Resolve the tree without tripping get_tree()'s "node not in tree" error in
	# bare-instance contexts (e.g. headless tests where autoloads aren't mounted).
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	# set_current_scene() requires the node to be parented to the tree root
	# (which _do_transition guarantees via root.add_child before this runs).
	if tree != null and new_scene.get_parent() == tree.root:
		tree.set_current_scene(new_scene)
	scene_changed.emit(new_scene)
