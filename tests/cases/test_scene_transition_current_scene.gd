extends RefCounted
## Regression tests for [audit:S28] — SceneManager must keep Godot's
## SceneTree.current_scene in sync with the scene it tracks, and TurnManager
## must resolve that active scene so on_mob_action refreshes reach the real
## GameScene instead of the pinned MainScene.

func run(t: Object) -> void:
	_test_finalize_sets_current_scene(t)
	_test_turn_manager_prefers_scene_manager(t)
	_test_turn_manager_cache_invalidation(t)

## _finalize_transition should mirror the new scene into the engine's
## current_scene pointer (the fix for the MainScene pin).
func _test_finalize_sets_current_scene(t: Object) -> void:
	var tree: SceneTree = t as SceneTree
	var prev_current: Node = tree.current_scene
	var prev_tracked: Node = SceneManager.current_scene

	var scene := Node.new()
	scene.name = "S28ProbeScene"
	tree.root.add_child(scene)

	SceneManager._finalize_transition(scene)

	t.check(
		tree.current_scene == scene,
		"finalize_transition sets SceneTree.current_scene to the new scene"
	)

	# Restore engine state so we don't leak a probe scene into later cases.
	tree.set_current_scene(prev_current)
	scene.free()
	SceneManager.current_scene = prev_tracked

## TurnManager should resolve the active scene from SceneManager, not a scene
## pinned in the tree. A fake scene exposing on_mob_action stands in for the
## GameScene.
func _test_turn_manager_prefers_scene_manager(t: Object) -> void:
	var prev_cached: Node = TurnManager._cached_game_scene
	var prev_tracked: Node = SceneManager.current_scene

	var fake_scene := _make_fake_game_scene()
	t.root.add_child(fake_scene)

	TurnManager._cached_game_scene = null
	SceneManager.current_scene = fake_scene

	var resolved: Node = TurnManager._get_game_scene_cached()
	t.check(
		resolved == fake_scene,
		"TurnManager resolves the SceneManager-tracked scene for on_mob_action"
	)
	t.check(
		resolved != null and resolved.has_method("on_mob_action"),
		"resolved scene exposes on_mob_action (would receive mob refreshes)"
	)

	TurnManager._cached_game_scene = prev_cached
	SceneManager.current_scene = prev_tracked
	fake_scene.free()

## A scene_changed emission must drop TurnManager's cached scene so the next
## resolution picks up the freshly active scene rather than a stale node.
func _test_turn_manager_cache_invalidation(t: Object) -> void:
	var prev_cached: Node = TurnManager._cached_game_scene

	var stale := Node.new()
	stale.name = "S28StaleScene"
	t.root.add_child(stale)
	TurnManager._cached_game_scene = stale

	TurnManager._on_scene_changed(null)
	t.check(
		TurnManager._cached_game_scene == null,
		"scene_changed handler clears TurnManager's cached game scene"
	)

	TurnManager._cached_game_scene = prev_cached
	stale.free()

func _make_fake_game_scene() -> Node:
	var scene := Node.new()
	scene.name = "S28FakeGameScene"
	scene.set_script(_FakeGameScene)
	return scene

const _FakeGameScene := preload("res://tests/cases/test_scene_transition_current_scene_stub.gd")
