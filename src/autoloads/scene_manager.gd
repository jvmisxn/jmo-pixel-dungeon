class_name SceneManagerNode
extends Node
## Centralized scene transition manager.
## Eliminates get_parent() / get_tree().root.add_child() anti-patterns.
## All scene transitions go through this autoload — "signal up, call down."

## Emitted after a scene transition completes (new scene is ready).
signal scene_changed(new_scene: Node)

## The currently active scene (top-level game screen).
var current_scene: Node = null

## Seconds the black cover takes to fade away after a scene swap. The swap
## itself stays synchronous (current_scene updates immediately); the cover
## only hides the hard cut while the new scene builds its first frame.
const FADE_IN_SECONDS: float = 0.3
## Drawn above every game layer, including HUD windows.
const FADE_LAYER: int = 128

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null

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
	_play_fade_in()
	scene_changed.emit(new_scene)

# ---------------------------------------------------------------------------
# Fade cover
# ---------------------------------------------------------------------------

func _ensure_fade_cover() -> bool:
	if _fade_rect != null and is_instance_valid(_fade_rect):
		return true
	# Parent to the tree root (not this autoload) so the cover also works
	# before autoloads have entered the tree, e.g. in headless runs.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "SceneFade"
	_fade_layer.layer = FADE_LAYER
	tree.root.add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	_fade_layer.add_child(_fade_rect)
	return true


## Start fully black and fade out, so the swap reads as a fade from black.
func _play_fade_in() -> void:
	if not _ensure_fade_cover():
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.modulate.a = 1.0
	_fade_tween = _fade_rect.create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_IN_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
