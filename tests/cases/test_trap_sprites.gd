extends RefCounted
## Revealed-trap rendering: every port trap class has a TrapSprite style
## matching upstream TrapSprite color/shape assignments, and
## SceneVisualCoordinator.refresh_trap_sprites creates sprites only for
## revealed traps, greys out triggered ones, and drops removed ones.


class StubScene:
	extends RefCounted
	var _current_level: Level = null
	var _trap_sprites: Dictionary[int, Variant] = {}
	var _entity_layer: Node2D = null

	func _instantiate_script(path: String) -> Variant:
		return (load(path) as GDScript).new()


func _make_level() -> Level:
	var level := Level.new()
	level.depth = 1
	level._init_arrays()
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	return level


func run(t: Object) -> void:
	# --- Every trap class carries a style entry keyed by its trap_name ---
	var trap_dir: DirAccess = DirAccess.open("res://src/levels/traps")
	t.check(trap_dir != null, "trap directory opens")
	var missing: Array[String] = []
	var checked: int = 0
	for file_name: String in trap_dir.get_files():
		if not file_name.ends_with(".gd") or file_name == "trap.gd":
			continue
		var trap: Variant = (load("res://src/levels/traps/" + file_name) as GDScript).new()
		checked += 1
		if not TrapSprite.TRAP_STYLES.has(str(trap.trap_name)):
			missing.append(str(trap.trap_name))
	t.check(checked >= 30, "found the expected number of trap classes (got %d)" % checked)
	t.check(missing.is_empty(), "every trap_name has a TrapSprite style (missing: %s)" % str(missing))

	# --- Style lookup applies upstream color/shape; unknown names fall back ---
	var sprite: TrapSprite = TrapSprite.new()
	sprite.setup_for_trap("blazing trap")
	t.check(sprite._color == TrapSprite.COLOR_ORANGE and sprite._shape == TrapSprite.Shape.STARS,
		"blazing trap uses upstream ORANGE/STARS")
	sprite.setup_for_trap("pitfall trap")
	t.check(sprite._color == TrapSprite.COLOR_RED and sprite._shape == TrapSprite.Shape.DIAMOND,
		"pitfall trap uses upstream RED/DIAMOND")
	sprite.setup_for_trap("no such trap")
	t.check(sprite._color == TrapSprite.COLOR_RED and sprite._shape == TrapSprite.Shape.DOTS,
		"unknown trap names fall back to RED/DOTS")
	sprite.free()

	# --- Coordinator only builds sprites for revealed traps ---
	var scene: StubScene = StubScene.new()
	scene._current_level = _make_level()
	scene._entity_layer = Node2D.new()
	var hidden_pos: int = ConstantsData.xy_to_pos(4, 4)
	var shown_pos: int = ConstantsData.xy_to_pos(6, 4)
	var hidden_trap: Variant = (load("res://src/levels/traps/toxic_trap.gd") as GDScript).new()
	hidden_trap.set_pos(hidden_pos)
	scene._current_level.traps[hidden_pos] = hidden_trap
	var shown_trap: Variant = (load("res://src/levels/traps/fire_trap.gd") as GDScript).new()
	shown_trap.set_pos(shown_pos)
	shown_trap.visible = true
	scene._current_level.traps[shown_pos] = shown_trap

	SceneVisualCoordinator.refresh_trap_sprites(scene)
	t.check(not scene._trap_sprites.has(hidden_pos), "hidden trap gets no sprite")
	t.check(scene._trap_sprites.size() == 1, "exactly one sprite for the one revealed trap")
	var shown_sprite: Variant = scene._trap_sprites.get(shown_pos)
	t.check(shown_sprite != null and shown_sprite.trap_key == "fire trap",
		"revealed trap sprite carries its trap_name key")
	t.check(shown_sprite != null and shown_sprite.trap_active,
		"an untriggered revealed trap renders active")

	# --- Reveal, trigger, and removal all reconcile on refresh ---
	hidden_trap.reveal(scene._current_level)
	SceneVisualCoordinator.refresh_trap_sprites(scene)
	t.check(scene._trap_sprites.has(hidden_pos), "revealing a trap adds its sprite")

	shown_trap.active = false
	SceneVisualCoordinator.refresh_trap_sprites(scene)
	t.check(shown_sprite.trap_active == false, "triggered trap sprite flips to inactive/grey state")

	scene._current_level.traps.erase(hidden_pos)
	SceneVisualCoordinator.refresh_trap_sprites(scene)
	t.check(not scene._trap_sprites.has(hidden_pos), "removed trap loses its sprite")

	scene._entity_layer.free()
	scene._current_level = null
