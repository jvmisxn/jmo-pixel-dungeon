extends RefCounted
## Regression tests for [audit:S25] — on_mob_action must not run a full
## FOV/fog/entity-visibility rebuild for every acting mob. Off-view mob
## actions defer to one coalesced refresh at round end; in-view (or
## near-hero, for mind-vision reveals) actions still refresh immediately.


class StubLevel:
	extends RefCounted
	var visible: Array[bool] = []
	var width: int = 32

	func _init(size: int = 32 * 32) -> void:
		visible.resize(size)
		visible.fill(false)

	func update_fov(_pos: int, _view_distance: int) -> void:
		StubCounters.update_fov_calls += 1

	func distance(a: int, b: int) -> int:
		var ax: int = a % width
		var ay: int = a / width
		var bx: int = b % width
		var by: int = b / width
		return maxi(absi(ax - bx), absi(ay - by))


class StubFog:
	extends RefCounted
	func update_visibility() -> void:
		StubCounters.fog_calls += 1


class StubHero:
	extends RefCounted
	var pos: int = 0

	func get_view_distance() -> int:
		return 8


class StubScene:
	extends RefCounted
	var _current_level: Variant = null
	var _mob_sprites: Dictionary = {}
	var fog_of_war: Variant = null
	var hero: Variant = null

	func _get_focused_hero() -> Variant:
		return hero

	func _update_entity_visibility() -> void:
		StubCounters.entity_visibility_calls += 1

	func _interrupt_rest_if_needed() -> void:
		StubCounters.interrupt_calls += 1

	func _queue_online_snapshot_sync(_force: bool = false) -> void:
		StubCounters.snapshot_calls += 1


class StubCounters:
	static var update_fov_calls: int = 0
	static var fog_calls: int = 0
	static var entity_visibility_calls: int = 0
	static var interrupt_calls: int = 0
	static var snapshot_calls: int = 0

	static func reset() -> void:
		update_fov_calls = 0
		fog_calls = 0
		entity_visibility_calls = 0
		interrupt_calls = 0
		snapshot_calls = 0


class StubSprite:
	extends RefCounted
	var cell_pos: int = -1

	func move_to(new_pos: int, _interval: float) -> void:
		cell_pos = new_pos

	func play_attack(_target_pos: int) -> void:
		pass

	func update_hp_bar(_hp: int, _ht: int) -> void:
		pass


func run(t: Object) -> void:
	_test_far_fogged_mob_defers_refresh(t)
	_test_round_end_flushes_once(t)
	_test_visible_mob_refreshes_immediately(t)
	_test_mob_leaving_view_refreshes_immediately(t)
	_test_near_hero_fogged_mob_refreshes(t)
	_test_clean_round_end_skips_refresh(t)


func _make_scene(hero_pos: int = 0) -> StubScene:
	StubCounters.reset()
	var scene := StubScene.new()
	scene._current_level = StubLevel.new()
	scene.fog_of_war = StubFog.new()
	var stub_hero := StubHero.new()
	stub_hero.pos = hero_pos
	scene.hero = stub_hero
	return scene


func _make_mob(pos: int, actor_id: int = 7) -> Node:
	# on_mob_action reads mob fields via Node.get(), so a tiny runtime script
	# supplies just the properties the coordinator touches.
	var mob := Node.new()
	var script := GDScript.new()
	script.source_code = (
		"extends Node\n"
		+ "var pos: int = -1\n"
		+ "var actor_id: int = -1\n"
		+ "var last_visible_action: String = \"move\"\n"
		+ "var last_visible_target_pos: int = -1\n"
	)
	script.reload()
	mob.set_script(script)
	mob.set("pos", pos)
	mob.set("actor_id", actor_id)
	return mob


## A mob acting far away in fog (further than view distance, not visible)
## must not trigger any FOV/fog/entity refresh — only mark the deferral.
func _test_far_fogged_mob_defers_refresh(t: Object) -> void:
	var scene := _make_scene(0)
	var mob := _make_mob(31 + 31 * 32)
	SceneFeedbackCoordinator.on_mob_action(scene, mob)
	t.check(StubCounters.update_fov_calls == 0, "S25: far fogged mob action skips update_fov")
	t.check(StubCounters.fog_calls == 0, "S25: far fogged mob action skips fog update")
	t.check(StubCounters.entity_visibility_calls == 0, "S25: far fogged mob action skips entity visibility")
	t.check(
		scene.get_meta(SceneFeedbackCoordinator.MOB_VISIBILITY_DIRTY_META, false) == true,
		"S25: deferred refresh marks the scene dirty"
	)
	t.check(StubCounters.snapshot_calls == 1, "S25: snapshot sync still queued for deferred actions")
	mob.free()


## Several deferred mob actions coalesce into exactly one refresh when the
## party round completes, and the dirty flag clears.
func _test_round_end_flushes_once(t: Object) -> void:
	var scene := _make_scene(0)
	var far_cell: int = 31 + 31 * 32
	var mobs: Array[Node] = []
	for i: int in range(4):
		mobs.append(_make_mob(far_cell - i, 10 + i))
	for mob: Node in mobs:
		SceneFeedbackCoordinator.on_mob_action(scene, mob)
	t.check(StubCounters.update_fov_calls == 0, "S25: four far mob actions produce zero immediate refreshes")
	SceneFeedbackCoordinator.on_round_completed(scene, 1)
	t.check(StubCounters.update_fov_calls == 1, "S25: round end flushes exactly one FOV refresh")
	t.check(StubCounters.fog_calls == 1, "S25: round end flushes exactly one fog refresh")
	t.check(StubCounters.entity_visibility_calls == 1, "S25: round end flushes exactly one entity-visibility pass")
	t.check(
		scene.get_meta(SceneFeedbackCoordinator.MOB_VISIBILITY_DIRTY_META, true) == false,
		"S25: round-end flush clears the dirty flag"
	)
	SceneFeedbackCoordinator.on_round_completed(scene, 2)
	t.check(StubCounters.update_fov_calls == 1, "S25: a clean following round does not refresh again")
	for mob: Node in mobs:
		mob.free()


## A mob acting on a currently-visible cell refreshes immediately.
func _test_visible_mob_refreshes_immediately(t: Object) -> void:
	var scene := _make_scene(0)
	var mob_cell: int = 20 + 20 * 32
	(scene._current_level as StubLevel).visible[mob_cell] = true
	var mob := _make_mob(mob_cell)
	SceneFeedbackCoordinator.on_mob_action(scene, mob)
	t.check(StubCounters.update_fov_calls == 1, "S25: visible mob action refreshes FOV immediately")
	t.check(StubCounters.interrupt_calls == 1, "S25: visible mob action still checks rest interruption")
	t.check(
		scene.get_meta(SceneFeedbackCoordinator.MOB_VISIBILITY_DIRTY_META, true) == false,
		"S25: immediate refresh leaves the scene clean"
	)
	mob.free()


## A mob stepping from a visible cell into fog must refresh immediately so
## its sprite is hidden without waiting for round end.
func _test_mob_leaving_view_refreshes_immediately(t: Object) -> void:
	var scene := _make_scene(0)
	var from_cell: int = 20 + 20 * 32
	var to_cell: int = 21 + 20 * 32
	(scene._current_level as StubLevel).visible[from_cell] = true
	var sprite := StubSprite.new()
	sprite.cell_pos = from_cell
	scene._mob_sprites[7] = sprite
	var mob := _make_mob(to_cell, 7)
	SceneFeedbackCoordinator.on_mob_action(scene, mob)
	t.check(sprite.cell_pos == to_cell, "S25: sprite still moves to the new cell")
	t.check(StubCounters.update_fov_calls == 1, "S25: leaving view refreshes immediately via the previous cell")
	mob.free()


## A fogged mob acting within mind-vision reach of the hero (view distance
## + 1) refreshes immediately — Heightened Senses / Arcane Vision overlays
## reveal through walls, so near-hero actions can change what is drawn.
func _test_near_hero_fogged_mob_refreshes(t: Object) -> void:
	var hero_cell: int = 10 + 10 * 32
	var scene := _make_scene(hero_cell)
	var mob := _make_mob(hero_cell + 2)
	SceneFeedbackCoordinator.on_mob_action(scene, mob)
	t.check(StubCounters.update_fov_calls == 1, "S25: near-hero fogged mob action refreshes immediately")
	mob.free()


## A round completing with no deferred mob actions performs no extra refresh.
func _test_clean_round_end_skips_refresh(t: Object) -> void:
	var scene := _make_scene(0)
	SceneFeedbackCoordinator.on_round_completed(scene, 1)
	t.check(StubCounters.update_fov_calls == 0, "S25: clean round end performs no visibility refresh")
