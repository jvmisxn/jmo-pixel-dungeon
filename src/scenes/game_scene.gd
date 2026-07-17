class_name GameScene
extends Node2D
## Main gameplay scene. Assembles the visual layers (tiles, fog, sprites, effects),
## handles input (click to move/attack, keyboard), and bridges game logic to visuals.
## Orchestrates level loading, hero placement, and the turn loop.

class BlobOverlayLayer:
	extends Node2D

	const CELL_SIZE: int = 16

	var _cells: Array[Dictionary] = []

	func set_cells(cells: Array[Dictionary]) -> void:
		_cells = cells
		queue_redraw()

	func clear_cells() -> void:
		if _cells.is_empty():
			return
		_cells.clear()
		queue_redraw()

	func _draw() -> void:
		for cell_entry: Dictionary in _cells:
			var pos: int = int(cell_entry.get("pos", -1))
			if pos < 0:
				continue
			var base_color: Color = cell_entry.get("color", Color.WHITE) as Color
			var alpha: float = clampf(float(cell_entry.get("alpha", 0.0)), 0.0, 0.85)
			if alpha <= 0.0:
				continue
			var style: String = str(cell_entry.get("style", "gas"))
			var x: int = pos % ConstantsData.WIDTH
			@warning_ignore("integer_division")
			var y: int = pos / ConstantsData.WIDTH
			var rect: Rect2 = Rect2(Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))

			match style:
				"web":
					_draw_web(rect, base_color, alpha)
				"fire":
					_draw_fire(rect, pos, base_color, alpha)
				_:
					_draw_gas(rect, pos, base_color, alpha)

	func _draw_web(rect: Rect2, base_color: Color, alpha: float) -> void:
		var mist: Color = base_color
		mist.a = alpha * 0.3
		draw_circle(rect.get_center(), 5.0, mist)
		var web_line: Color = base_color.lightened(0.55)
		web_line.a = minf(alpha + 0.2, 0.9)
		draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(CELL_SIZE - 2, CELL_SIZE - 2), web_line, 1.4)
		draw_line(rect.position + Vector2(CELL_SIZE - 2, 2), rect.position + Vector2(2, CELL_SIZE - 2), web_line, 1.4)
		draw_line(rect.position + Vector2(CELL_SIZE * 0.5, 1), rect.position + Vector2(CELL_SIZE * 0.5, CELL_SIZE - 1), web_line, 1.0)
		draw_line(rect.position + Vector2(1, CELL_SIZE * 0.5), rect.position + Vector2(CELL_SIZE - 1, CELL_SIZE * 0.5), web_line, 1.0)

	func _draw_fire(rect: Rect2, pos: int, base_color: Color, alpha: float) -> void:
		var outer: Color = base_color
		outer.a = alpha * 0.75
		var inner: Color = base_color.lightened(0.45)
		inner.a = minf(alpha + 0.18, 0.92)
		var seed: int = pos * 37 + 11
		_draw_puff(rect, seed, outer, 5.2, 0.95)
		_draw_puff(rect, seed + 3, inner, 3.4, 0.55)
		draw_circle(rect.position + Vector2(8, 11), 2.1, inner)

	func _draw_gas(rect: Rect2, pos: int, base_color: Color, alpha: float) -> void:
		var outer: Color = base_color
		outer.a = alpha * 0.7
		var inner: Color = base_color.lightened(0.22)
		inner.a = minf(alpha + 0.08, 0.72)
		var seed: int = pos * 53 + 7
		_draw_puff(rect, seed, outer, 4.8, 1.0)
		_draw_puff(rect, seed + 5, inner, 3.2, 0.58)

	func _draw_puff(rect: Rect2, seed: int, color: Color, radius: float, spread: float) -> void:
		var center: Vector2 = rect.get_center()
		for i: int in range(3):
			var offset_x: float = float(((seed + i * 11) % 7) - 3) * spread
			var offset_y: float = float((((seed / 3) + i * 13) % 7) - 3) * spread
			draw_circle(center + Vector2(offset_x, offset_y), radius - i * 0.8, color)

# --- Layer References ---
var tile_map: Variant = null
var fog_of_war: Variant = null
var effect_manager: Variant = null
var game_camera: Variant = null

# --- Sprite Tracking ---
## Hero sprite instances. Key: actor_id (int) -> HeroSprite
var _hero_sprites: Dictionary[int, Variant] = {}
## Mob sprite instances. Key: actor_id (int or mob ref) -> CharSprite
var _mob_sprites: Dictionary[int, Variant] = {}
## Item sprites on the ground. Key: pos (int) -> ItemSprite
var _item_sprites: Dictionary[int, Variant] = {}
## Plant sprites on the ground. Key: pos (int) -> PlantSprite
var _plant_sprites: Dictionary[int, Variant] = {}
## Armed bomb sprites on the ground. Key: pos (int) -> ItemSprite
var _armed_bomb_sprites: Dictionary[int, Variant] = {}

# --- Sprite Layers (Node2D containers for z-ordering) ---
var _blob_layer: BlobOverlayLayer = null
var _entity_layer: Node2D = null

# --- Input State ---
var _awaiting_hero_input: bool = false
var _game_ended: bool = false  # Set on hero death/victory to stop _process loop
var _hover_cell: int = -1
var _action_block_feedback_cooldown: float = 0.0
var _pending_online_arrival_feedback: String = ""
var _suppressed_snapshot_pickups: Dictionary[int, int] = {}
var _suppressed_snapshot_doors: Dictionary[int, int] = {}
var _held_move_keycode: int = KEY_NONE
var _held_move_dir: int = 0
var _held_move_keys: Array[int] = []
var _held_move_repeat_cooldown: float = 0.0
var _active_touch_points: Dictionary = {}
var _ui_touch_points: Dictionary = {}
var _touch_gesture_started: bool = false
var _suppress_touch_mouse_until_msec: int = 0
var _last_action_from_touch: bool = false
const HELD_MOVE_REPEAT_DELAY: float = 0.25
const TOUCH_MOVE_DURATION: float = 0.28

# --- Auto-Walk State ---
## When > 0, the hero is auto-walking toward this destination cell.
var _auto_walk_target: int = -1
## Set of mob positions visible BEFORE the last auto-walk step (to detect new enemies).
var _auto_walk_known_mobs: Dictionary[int, bool] = {}
## Hero HP before the last auto-walk step (to detect taking damage).
var _auto_walk_prev_hp: int = -1
## Cooldown timer to pace auto-walk steps so movement animation is visible.
var _auto_walk_cooldown: float = 0.0
const AUTO_WALK_STEP_DELAY: float = 0.15

# --- Targeting Mode State ---
## True when in targeting mode (throw, zap, etc.)
var _targeting_active: bool = false
## The item being thrown/used during targeting.
var _targeting_item: Variant = null
## Maximum range for the targeting action (-1 = unlimited).
var _targeting_max_range: int = -1
## Callback to invoke with the selected cell pos when target is chosen.
var _targeting_callback: Callable = Callable()

# --- HUD ---
var _hud: Variant = null

# --- Level Reference ---
var _current_level: Variant = null
var _network_input_slot: int = -1
var _pending_online_snapshot_sync: bool = false
var _pending_online_snapshot_force: bool = false

# --- Pending level load (set before _ready, consumed in _ready) ---
var _pending_level: Variant = null
var _pending_region: int = -1
const _EQUIP_SLOT_NAMES: Array[String] = ["weapon", "spirit_bow", "armor", "artifact", "misc", "ring_left", "ring_right"]
const ALLY_LABEL_COLOR: Color = Color(0.58, 0.88, 0.96)
const LOCAL_LABEL_COLOR: Color = Color(1.0, 0.9, 0.45)
const FOCUSED_LABEL_COLOR: Color = Color(1.0, 1.0, 1.0)
const FALLEN_LABEL_COLOR: Color = Color(0.75, 0.45, 0.45)
const ALLY_RING_FILL: Color = Color(0.2, 0.8, 0.95, 0.18)
const ALLY_RING_OUTLINE: Color = Color(0.52, 0.92, 1.0, 0.95)
const LOCAL_RING_FILL: Color = Color(1.0, 0.82, 0.26, 0.20)
const LOCAL_RING_OUTLINE: Color = Color(1.0, 0.92, 0.62, 0.98)
const FOCUSED_RING_FILL: Color = Color(1.0, 1.0, 1.0, 0.16)
const FOCUSED_RING_OUTLINE: Color = Color(1.0, 1.0, 1.0, 1.0)
const INPUT_RING_FILL: Color = Color(0.56, 1.0, 0.56, 0.24)
const INPUT_RING_OUTLINE: Color = Color(0.82, 1.0, 0.82, 1.0)
const FALLEN_RING_FILL: Color = Color(0.65, 0.22, 0.22, 0.16)
const FALLEN_RING_OUTLINE: Color = Color(0.9, 0.4, 0.4, 0.85)

func _get_focused_hero() -> Variant:
	if GameManager == null:
		return null
	return GameManager.get_local_hero() if GameManager.has_method("get_local_hero") else GameManager.hero

func _get_input_hero() -> Variant:
	if GameManager == null:
		return null
	if _is_online_client():
		if _network_input_slot >= 0 and _network_input_slot < GameManager.heroes.size():
			var network_hero: Variant = GameManager.heroes[_network_input_slot]
			if network_hero != null and is_instance_valid(network_hero):
				return network_hero
	return GameManager.get_input_hero() if GameManager.has_method("get_input_hero") else _get_focused_hero()

func _is_online_client() -> bool:
	return NetworkManager != null and NetworkManager.has_method("is_client") and NetworkManager.is_client()

func _is_online_host() -> bool:
	return NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host()

func _instantiate_script(path: String) -> Variant:
	var script: GDScript = load(path) as GDScript
	if script == null:
		return null
	return script.new()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Black background so areas outside the map don't show through
	RenderingServer.set_default_clear_color(Color.BLACK)
	_create_layers()
	_connect_signals()
	# If a level was queued before we entered the tree, load it now
	if _pending_level:
		load_level(_pending_level, _pending_region)
		_pending_level = null
		_pending_region = -1
		if not _is_online_client():
			TurnManager.process_until_hero()
			_sync_online_snapshot()

func _process(_delta: float) -> void:
	# Update hover cell
	if game_camera:
		var new_hover: int = game_camera.get_cell_under_mouse()
		if new_hover != _hover_cell:
			_hover_cell = new_hover

	# Stop processing turns after hero death or victory (prevents mobs
	# taking thousands of turns during the death/victory transition delay).
	if _game_ended:
		return
	if _action_block_feedback_cooldown > 0.0:
		_action_block_feedback_cooldown = maxf(0.0, _action_block_feedback_cooldown - _delta)
	_process_held_move_repeat(_delta)
	if _is_online_client():
		return
	if _pending_online_snapshot_sync:
		_sync_online_snapshot(_pending_online_snapshot_force)
		_pending_online_snapshot_sync = false
		_pending_online_snapshot_force = false

	# Sync with TurnManager — if it's waiting for input, we should be too.
	# Don't interfere while the async mob-processing coroutine is running.
	if not _awaiting_hero_input and TurnManager and not TurnManager.processing_mobs:
		if TurnManager.waiting_for_input:
			# TurnManager is already waiting (e.g. from level load) — accept input
			_awaiting_hero_input = true
			_sync_online_snapshot()
		else:
			# Process AI turns until hero's turn comes
			TurnManager.process_until_hero()
			if TurnManager.waiting_for_input:
				_awaiting_hero_input = true
				_sync_online_snapshot()

	# --- Auto-walk: if hero's turn and auto-walking, take the next step ---
	if _awaiting_hero_input and _auto_walk_target >= 0 and _get_input_hero() != null:
		# Wait for the step animation to finish before taking the next step
		if _auto_walk_cooldown > 0.0:
			_auto_walk_cooldown -= _delta
		else:
			_process_auto_walk()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		_suppress_synthesized_touch_mouse()
		if touch.pressed:
			if _is_screen_position_over_hud(touch.position):
				_ui_touch_points[touch.index] = true
				return
			_active_touch_points[touch.index] = touch.position
			if _active_touch_points.size() >= 2:
				_touch_gesture_started = true
				_cancel_auto_walk()
		else:
			if _ui_touch_points.has(touch.index):
				_ui_touch_points.erase(touch.index)
				_handle_hud_touch_release(touch.position)
				get_viewport().set_input_as_handled()
				return
			var should_tap: bool = not _touch_gesture_started \
					and _active_touch_points.size() == 1 \
					and _active_touch_points.has(touch.index)
			_active_touch_points.erase(touch.index)
			if should_tap:
				_handle_touch_tap(touch.position)
			if _active_touch_points.is_empty():
				_touch_gesture_started = false
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_suppress_synthesized_touch_mouse()
		if _ui_touch_points.has(drag.index):
			get_viewport().set_input_as_handled()
			return
		if _active_touch_points.has(drag.index):
			_active_touch_points[drag.index] = drag.position
			if _active_touch_points.size() >= 2:
				_touch_gesture_started = true
				_cancel_auto_walk()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and _is_synthesized_touch_mouse_suppressed() and not _is_screen_position_over_hud(mb.position):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse Click ---
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _is_screen_position_over_hud(mb.position):
				get_viewport().set_input_as_handled()
				return
			if not _awaiting_hero_input:
				if mb.button_index == MOUSE_BUTTON_LEFT and _is_online_client():
					_show_local_action_blocked_feedback()
					get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var cell: int = game_camera.get_cell_under_mouse() if game_camera else -1
				if cell >= 0:
					_handle_cell_click(cell)
					get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				# Right-click cancels targeting mode
				if _targeting_active:
					_cancel_targeting_mode()
					get_viewport().set_input_as_handled()

	# --- Keyboard ---
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed:
			if _movement_dir_for_key(key.keycode) != 0:
				_release_held_move_key(key.keycode)
			return
		if key.pressed and not key.echo:
			if not _awaiting_hero_input:
				if _is_passive_hud_key(key.keycode):
					var passive_handled: bool = _handle_key_input(key.keycode)
					if passive_handled:
						get_viewport().set_input_as_handled()
					return
				if _is_online_client() and _is_local_action_key(key.keycode):
					_show_local_action_blocked_feedback()
					get_viewport().set_input_as_handled()
				return
			var handled: bool = _handle_key_input(key.keycode)
			if handled:
				get_viewport().set_input_as_handled()

func _is_passive_hud_key(keycode: int) -> bool:
	return keycode in [KEY_TAB, KEY_I, KEY_M, KEY_ESCAPE]

func _is_local_action_key(keycode: int) -> bool:
	return keycode in [
		KEY_A, KEY_F, KEY_R, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
		KEY_SPACE, KEY_PERIOD, KEY_S, KEY_ENTER, KEY_KP_ENTER,
		KEY_KP_8, KEY_K, KEY_UP, KEY_KP_2, KEY_J, KEY_DOWN,
		KEY_KP_4, KEY_H, KEY_LEFT, KEY_KP_6, KEY_L, KEY_RIGHT,
		KEY_KP_7, KEY_Y, KEY_KP_9, KEY_U, KEY_KP_1, KEY_B, KEY_KP_3, KEY_N,
		KEY_LESS, KEY_GREATER
	]

func _suppress_synthesized_touch_mouse() -> void:
	_suppress_touch_mouse_until_msec = Time.get_ticks_msec() + 500

func _is_synthesized_touch_mouse_suppressed() -> bool:
	return Time.get_ticks_msec() <= _suppress_touch_mouse_until_msec

func _is_screen_position_over_hud(screen_pos: Vector2) -> bool:
	if _hud == null or not is_instance_valid(_hud):
		return false
	if _hud.has_method("contains_screen_position"):
		return bool(_hud.contains_screen_position(screen_pos))
	return false

func _handle_touch_tap(screen_pos: Vector2) -> void:
	if not _awaiting_hero_input:
		if _is_online_client():
			_show_local_action_blocked_feedback()
		return
	var cell: int = -1
	if game_camera and game_camera.has_method("get_cell_at_screen_position"):
		cell = game_camera.get_cell_at_screen_position(screen_pos)
	if cell >= 0:
		_last_action_from_touch = true
		_handle_cell_click(cell)
		get_viewport().set_input_as_handled()


func _handle_hud_touch_release(screen_pos: Vector2) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	if _hud.has_method("handle_screen_tap"):
		_hud.handle_screen_tap(screen_pos)

func _movement_dir_for_key(keycode: int) -> int:
	match keycode:
		KEY_KP_8, KEY_K, KEY_UP:
			return ConstantsData.DIR_N
		KEY_KP_2, KEY_J, KEY_DOWN:
			return ConstantsData.DIR_S
		KEY_KP_4, KEY_H, KEY_LEFT:
			return ConstantsData.DIR_W
		KEY_KP_6, KEY_L, KEY_RIGHT:
			return ConstantsData.DIR_E
		KEY_KP_7, KEY_Y:
			return ConstantsData.DIR_NW
		KEY_KP_9, KEY_U:
			return ConstantsData.DIR_NE
		KEY_KP_1, KEY_B:
			return ConstantsData.DIR_SW
		KEY_KP_3, KEY_N:
			return ConstantsData.DIR_SE
		_:
			return 0

func _set_held_move_state(keycode: int, dir_offset: int) -> void:
	_held_move_keys.erase(keycode)
	_held_move_keys.append(keycode)
	_held_move_keycode = keycode
	_held_move_dir = dir_offset
	_held_move_repeat_cooldown = HELD_MOVE_REPEAT_DELAY

func _clear_held_move_state() -> void:
	_held_move_keycode = KEY_NONE
	_held_move_dir = 0
	_held_move_keys.clear()
	_held_move_repeat_cooldown = 0.0

func _restore_held_move_from_stack() -> void:
	for i: int in range(_held_move_keys.size() - 1, -1, -1):
		var candidate_keycode: int = _held_move_keys[i]
		if not Input.is_key_pressed(candidate_keycode):
			_held_move_keys.remove_at(i)
			continue
		var candidate_dir: int = _movement_dir_for_key(candidate_keycode)
		if candidate_dir == 0:
			_held_move_keys.remove_at(i)
			continue
		_held_move_keycode = candidate_keycode
		_held_move_dir = candidate_dir
		_held_move_repeat_cooldown = HELD_MOVE_REPEAT_DELAY
		return
	_held_move_keycode = KEY_NONE
	_held_move_dir = 0
	_held_move_repeat_cooldown = 0.0

func _release_held_move_key(keycode: int) -> void:
	_held_move_keys.erase(keycode)
	if keycode != _held_move_keycode:
		return
	_restore_held_move_from_stack()

func _process_held_move_repeat(delta: float) -> void:
	if _held_move_dir == 0 or _held_move_keycode == KEY_NONE:
		return
	if not Input.is_key_pressed(_held_move_keycode):
		_release_held_move_key(_held_move_keycode)
		return
	if _targeting_active or _auto_walk_target >= 0 or not _awaiting_hero_input:
		return
	var hero: Variant = _get_input_hero()
	if hero == null:
		return
	if _held_move_repeat_cooldown > 0.0:
		_held_move_repeat_cooldown = maxf(0.0, _held_move_repeat_cooldown - delta)
		return
	_move_direction(_held_move_dir)
	_held_move_repeat_cooldown = HELD_MOVE_REPEAT_DELAY

func _get_local_action_block_reason() -> String:
	if not _is_online_client():
		return ""
	if GameManager != null and GameManager.has_method("is_local_player_spectating") and GameManager.is_local_player_spectating():
		return "You are spectating another hero."
	var local_owned_hero: Variant = GameManager.get_local_owned_hero() if GameManager != null and GameManager.has_method("get_local_owned_hero") else null
	var input_hero: Variant = _get_input_hero()
	if local_owned_hero == null:
		return "Waiting for party state..."
	if local_owned_hero.get("is_alive") != true:
		return "Your hero is down. Spectate the party."
	if input_hero == null:
		return "Waiting for another player's turn."
	if input_hero != local_owned_hero:
		return "It is not your hero's turn."
	return "Wait for your turn."

func _show_local_action_blocked_feedback() -> void:
	if _action_block_feedback_cooldown > 0.0:
		return
	var reason: String = _get_local_action_block_reason()
	if reason.is_empty():
		return
	_action_block_feedback_cooldown = 0.45
	if MessageLog:
		MessageLog.add_warning(reason)
	var hero_node: Variant = _get_focused_hero()
	if hero_node != null and effect_manager != null:
		effect_manager.show_status(hero_node.pos, "Wait", Color(1.0, 0.76, 0.38))

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load and display a level. Called by game flow when entering a new depth.
func load_level(level: Variant, region: int) -> void:
	_cancel_auto_walk()
	_current_level = level
	GameManager.current_level = level

	# Assign level reference to hero(es) so Actor.level is set for collision checks
	if GameManager.hero:
		GameManager.hero.level = level
	for h: Variant in GameManager.heroes:
		if h is Node and is_instance_valid(h):
			(h as Node).level = level

	# Set up tile map
	tile_map.setup(level, region)

	# Set up fog
	var is_dark: bool = level.feeling == Level.Feeling.DARK
	fog_of_war.setup(level, is_dark)
	if is_dark and MessageLog:
		MessageLog.add_warning("This floor feels unusually dark.")

	# Camera bounds
	game_camera.set_map_bounds(tile_map.get_map_pixel_size())

	# Spawn hero sprites
	_clear_entity_sprites()
	_spawn_hero_sprites()
	_spawn_mob_sprites()
	_spawn_item_sprites()
	_refresh_plant_sprites()
	_refresh_armed_bomb_sprites()

	# Initial FOV from the locally focused hero position
	var local_hero: Variant = _get_focused_hero()
	if local_hero:
		# Debug: log level state
		var non_wall: int = 0
		for i: int in range(Level.LEN):
			if level.map[i] != ConstantsData.Terrain.WALL:
				non_wall += 1
		if MessageLog:
			MessageLog.add("Level loaded: entrance=%d, exit=%d, hero=%d, non-wall=%d, mobs=%d" % [
				level.entrance, level.exit_pos, local_hero.pos, non_wall, level.mobs.size()])

		var _vd: int = local_hero.get_view_distance() if local_hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		level.update_fov(local_hero.pos, _vd)

		# Debug: count visible cells
		var vis_count: int = 0
		for i: int in range(Level.LEN):
			if level.visible[i]:
				vis_count += 1
		if MessageLog:
			MessageLog.add("FOV: %d cells visible (view_dist=%d)" % [vis_count, _vd])

		fog_of_war.update_visibility()
		tile_map.update_tile_visibility()
		_update_entity_visibility()
		# Camera to hero — defer snap so the scene tree is fully ready
		var hero_world: Vector2 = tile_map.cell_to_world(local_hero.pos)
		game_camera.set_target(hero_world)
		game_camera.global_position = hero_world
		# Also defer a snap to ensure viewport size is known
		game_camera.call_deferred("snap_to_target")

	# Play per-region music matching original's playLevelMusic() pattern
	if AudioManager:
		@warning_ignore("integer_division")
		var music_region: int = ConstantsData.region_for_depth(GameManager.depth)
		if GameManager.is_boss_depth():
			AudioManager.play_region_music(music_region, false, true)
		else:
			# Check if a quest is active on this floor
			var quest_active: bool = false
			if QuestHandler._initialized:
				for qid: String in QuestHandler.quest_states:
					if QuestHandler.quest_states[qid] == "active":
						quest_active = true
						break
			AudioManager.play_region_music(music_region, quest_active)

	# Update HUD
	if _hud:
		_hud.update_all()

	# Start the turn loop
	_awaiting_hero_input = false

## Refresh visuals after a turn completes (FOV, sprites, items).
func refresh_after_turn() -> void:
	SceneFeedbackCoordinator.refresh_after_turn(self)

## Called by TurnManager after each visible mob action (move, attack) so the
## player can see the mob act in real time. Updates the mob's sprite position,
## plays attack animation if it attacked the hero, and refreshes FOV/visibility.
func on_mob_action(actor: Node) -> void:
	SceneFeedbackCoordinator.on_mob_action(self, actor)


## Get the EffectManager for external systems to trigger effects.
func get_effects() -> Variant:
	return effect_manager

func _serialize_online_snapshot() -> Dictionary:
	return OnlineSnapshotUtils.serialize_online_snapshot(GameManager.heroes, _get_input_hero(), _current_level)

func _queue_online_snapshot_sync(force: bool = false) -> void:
	if not _is_online_host():
		return
	_pending_online_snapshot_sync = true
	_pending_online_snapshot_force = _pending_online_snapshot_force or force

func _sync_online_snapshot(force: bool = false) -> void:
	OnlineSyncCoordinator.sync_snapshot(self, force)

func _capture_hero_snapshot_state() -> Dictionary:
	return {} if GameManager == null else OnlineSnapshotUtils.capture_hero_snapshot_state(GameManager.heroes)

func _capture_mob_snapshot_state() -> Dictionary:
	return OnlineSnapshotUtils.capture_mob_snapshot_state(_current_level)

func _capture_level_snapshot_state() -> Dictionary:
	return OnlineSnapshotUtils.capture_level_snapshot_state(_current_level)

func _tick_snapshot_feedback_suppression() -> void:
	_tick_suppression_dict(_suppressed_snapshot_pickups)
	_tick_suppression_dict(_suppressed_snapshot_doors)

func _tick_suppression_dict(target_dict: Dictionary[int, int]) -> void:
	var to_remove: Array[int] = []
	for pos: int in target_dict.keys():
		var remaining: int = int(target_dict[pos]) - 1
		if remaining <= 0:
			to_remove.append(pos)
		else:
			target_dict[pos] = remaining
	for pos: int in to_remove:
		target_dict.erase(pos)

func _suppress_snapshot_feedback(target_dict: Dictionary[int, int], pos: int, snapshot_count: int = 2) -> void:
	if pos < 0:
		return
	target_dict[pos] = maxi(int(target_dict.get(pos, 0)), snapshot_count)

func _apply_online_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or GameManager == null:
		return
	var snapshot_depth: int = int(snapshot.get("depth", GameManager.depth))
	var depth_changed: bool = snapshot_depth != GameManager.depth
	if depth_changed:
		_suppressed_snapshot_pickups.clear()
		_suppressed_snapshot_doors.clear()
	else:
		_tick_snapshot_feedback_suppression()
	var previous_hero_state: Dictionary = {} if depth_changed else _capture_hero_snapshot_state()
	var previous_mob_state: Dictionary = {} if depth_changed else _capture_mob_snapshot_state()
	var previous_level_state: Dictionary = {} if depth_changed else _capture_level_snapshot_state()
	if snapshot_depth != GameManager.depth:
		GameManager.depth = snapshot_depth
		if GameManager.has_method("_on_depth_changed"):
			GameManager._on_depth_changed()
		var fresh_level: Variant = LevelFactory.instantiate_for_depth(snapshot_depth)
		if fresh_level != null:
			GameManager.current_level = fresh_level
	var level_data: Variant = snapshot.get("level", {})
	if level_data is Dictionary and GameManager.current_level != null and GameManager.current_level.has_method("deserialize"):
		GameManager.current_level.deserialize(level_data)
	_current_level = GameManager.current_level
	var heroes_data: Variant = snapshot.get("heroes", [])
	if heroes_data is Array:
		for idx: int in range(mini(GameManager.heroes.size(), heroes_data.size())):
			var hero_node: Variant = GameManager.heroes[idx]
			var hero_data: Variant = heroes_data[idx]
			if hero_node != null and is_instance_valid(hero_node) and hero_data is Dictionary and hero_node.has_method("deserialize"):
				hero_node.level = _current_level
				hero_node.deserialize(hero_data)
				hero_node.level = _current_level
	for hero_node: Variant in GameManager.heroes:
		if hero_node != null and is_instance_valid(hero_node):
			hero_node.level = _current_level
	_network_input_slot = int(snapshot.get("current_input_slot", -1))
	_rebuild_scene_from_state(depth_changed, previous_hero_state, previous_mob_state, previous_level_state)

func _rebuild_scene_from_state(force_full_rebuild: bool = false, previous_hero_state: Dictionary = {}, previous_mob_state: Dictionary = {}, previous_level_state: Dictionary = {}) -> void:
	if _current_level == null:
		return
	var focused_hero: Variant = _get_focused_hero()
	if focused_hero != null and focused_hero.get("is_alive") != true:
		var spectate_hero: Variant = _find_best_spectate_hero()
		if spectate_hero != null and GameManager != null and GameManager.has_method("set_local_hero_index") and GameManager.has_method("get_hero_index"):
			var spectate_index: int = GameManager.get_hero_index(spectate_hero)
			if spectate_index >= 0:
				GameManager.set_local_hero_index(spectate_index)
	if tile_map:
		tile_map.level = _current_level
		tile_map.render_changed()
		tile_map.update_tile_visibility()
	if force_full_rebuild or _hero_sprites.is_empty():
		_clear_entity_sprites()
		_spawn_hero_sprites()
		_spawn_mob_sprites()
		_spawn_item_sprites()
		_refresh_plant_sprites()
		_refresh_armed_bomb_sprites()
	else:
		_sync_hero_sprites_from_state(previous_hero_state)
		_sync_mob_sprites_from_state(previous_mob_state)
		_refresh_item_sprites()
		_refresh_plant_sprites()
		_refresh_armed_bomb_sprites()
		_apply_snapshot_world_feedback(previous_level_state)
	_refresh_blob_overlays()
	focused_hero = _get_focused_hero()
	if focused_hero != null:
		var view_distance: int = focused_hero.get_view_distance() if focused_hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		_current_level.update_fov(focused_hero.pos, view_distance)
		fog_of_war.update_visibility()
		_update_entity_visibility()
		if game_camera and tile_map:
			var hero_world: Vector2 = tile_map.cell_to_world(focused_hero.pos)
			game_camera.set_target(hero_world)
			game_camera.global_position = hero_world
		if not _pending_online_arrival_feedback.is_empty() and effect_manager != null:
			effect_manager.show_status(focused_hero.pos, _pending_online_arrival_feedback, Color(0.74, 0.9, 1.0))
			_pending_online_arrival_feedback = ""
	_awaiting_hero_input = false
	if _network_input_slot >= 0 and _network_input_slot < GameManager.heroes.size():
		var acting_hero: Variant = GameManager.heroes[_network_input_slot]
		if acting_hero != null and is_instance_valid(acting_hero):
			_awaiting_hero_input = OnlineEventCodec.is_local_hero(NetworkManager, acting_hero)
	if _hud:
		_hud.update_all()

func _apply_snapshot_world_feedback(previous_level_state: Dictionary) -> void:
	if previous_level_state.is_empty() or _current_level == null:
		return
	var previous_map: Variant = previous_level_state.get("map", [])
	var current_map: Variant = _current_level.get("map")
	if previous_map is Array and current_map is Array:
		var terrain_limit: int = mini(previous_map.size(), current_map.size())
		for pos: int in range(terrain_limit):
			var previous_terrain: int = int(previous_map[pos])
			var current_terrain: int = int(current_map[pos])
			if previous_terrain == current_terrain:
				continue
			if current_terrain == ConstantsData.Terrain.OPEN_DOOR and previous_terrain in [
				ConstantsData.Terrain.DOOR,
				ConstantsData.Terrain.LOCKED_DOOR,
				ConstantsData.Terrain.CRYSTAL_DOOR,
			]:
				if _suppressed_snapshot_doors.has(pos):
					_suppressed_snapshot_doors.erase(pos)
					continue
				_on_door_opened(pos)
				if effect_manager != null:
					effect_manager.show_status(pos, "Open", Color(0.82, 0.72, 0.5))
			elif previous_terrain == ConstantsData.Terrain.SECRET_DOOR and current_terrain == ConstantsData.Terrain.DOOR:
				if tile_map:
					tile_map.update_tile_at(pos)
				if effect_manager != null:
					effect_manager.show_status(pos, "Found", Color(0.85, 0.9, 0.65))
	var previous_heaps: Variant = previous_level_state.get("heaps", {})
	if previous_heaps is Dictionary:
		var current_heaps: Dictionary = {}
		for heap: Dictionary in _current_level.heaps:
			var heap_pos: int = int(heap.get("pos", -1))
			if heap_pos < 0:
				continue
			current_heaps[heap_pos] = true
		for heap_pos_variant: Variant in previous_heaps.keys():
			var heap_pos: int = int(heap_pos_variant)
			if current_heaps.has(heap_pos):
				continue
			if _suppressed_snapshot_pickups.has(heap_pos):
				_suppressed_snapshot_pickups.erase(heap_pos)
				continue
			var pickup_hero: Variant = OnlineSnapshotUtils.find_hero_at_position(GameManager.heroes, heap_pos)
			if pickup_hero != null and effect_manager != null:
				effect_manager.show_status(heap_pos, "Pickup", Color(1.0, 0.9, 0.45))

func _remove_local_heap_at_pos(target_pos: int) -> void:
	OnlineSnapshotUtils.remove_heap_at_pos(_current_level, target_pos)

func _make_item_from_data(item_data: Dictionary) -> Variant:
	return OnlineSnapshotUtils.make_item_from_data(item_data)

func _find_hero_by_actor_id(actor_id: int) -> Variant:
	return null if GameManager == null else OnlineSnapshotUtils.find_hero_by_actor_id(GameManager.heroes, actor_id)

func _find_mob_by_actor_id(actor_id: int) -> Variant:
	return OnlineSnapshotUtils.find_mob_by_actor_id(_current_level, actor_id)

func _sync_hero_sprites_from_state(previous_hero_state: Dictionary = {}) -> void:
	if GameManager == null:
		return
	for hero_node: Variant in GameManager.heroes:
		if hero_node == null or not is_instance_valid(hero_node):
			continue
		var hero_key: int = int(hero_node.get("actor_id")) if hero_node.get("actor_id") != null else -1
		var hero_sprite: Variant = _hero_sprites.get(hero_key) if hero_key >= 0 else null
		if hero_sprite == null or not is_instance_valid(hero_sprite):
			_spawn_hero_sprites()
			return
		_apply_hero_equipment_visuals(hero_sprite, hero_node)
		var previous_state: Dictionary = previous_hero_state.get(hero_key, {}) if previous_hero_state.has(hero_key) else {}
		if hero_sprite.cell_pos != int(hero_node.pos):
			hero_sprite.move_to(int(hero_node.pos), 0.12)
		_apply_snapshot_action_feedback(
			hero_sprite,
			int(hero_node.pos),
			previous_state,
			str(ConstantsData.get_prop(hero_node, "last_visible_action", "")),
			int(ConstantsData.get_prop(hero_node, "last_visible_target_pos", -1))
		)
		if hero_node.get("hp") != null and hero_node.get("ht") != null:
			hero_sprite.update_hp_bar(int(hero_node.hp), int(hero_node.ht))
			_apply_snapshot_hp_feedback(hero_sprite, int(hero_node.pos), previous_state, int(hero_node.hp))
	_refresh_hero_identifiers()

func _apply_hero_equipment_visuals(hero_sprite: Variant, hero_node: Variant) -> void:
	if hero_sprite == null or not is_instance_valid(hero_sprite) or hero_node == null:
		return
	if not hero_sprite.has_method("update_armor"):
		return
	var armor_tier: int = 0
	var belongings: Variant = ConstantsData.get_prop(hero_node, "belongings", null)
	if belongings != null and belongings.has_method("get_equipped_armor"):
		var equipped_armor: Variant = belongings.get_equipped_armor()
		if equipped_armor != null:
			armor_tier = int(ConstantsData.get_prop(equipped_armor, "tier", 0))
	hero_sprite.update_armor(armor_tier)

func _sync_mob_sprites_from_state(previous_mob_state: Dictionary = {}) -> void:
	if _current_level == null:
		return
	_ensure_mob_sprites()
	for mob_node: Variant in _current_level.mobs:
		if mob_node == null or not is_instance_valid(mob_node):
			continue
		var mob_key: int = int(mob_node.get("actor_id")) if mob_node.get("actor_id") != null else mob_node.get_instance_id()
		var mob_sprite: Variant = _mob_sprites.get(mob_key)
		if mob_sprite == null:
			continue
		if not is_instance_valid(mob_sprite):
			continue
		var previous_state: Dictionary = previous_mob_state.get(mob_key, {}) if previous_mob_state.has(mob_key) else {}
		if mob_sprite.cell_pos != int(mob_node.pos):
			mob_sprite.move_to(int(mob_node.pos), 0.12)
		_apply_snapshot_action_feedback(
			mob_sprite,
			int(mob_node.pos),
			previous_state,
			str(mob_node.get("last_visible_action", "")),
			int(mob_node.get("last_visible_target_pos", -1))
		)
		if mob_node.get("hp") != null and mob_node.get("ht") != null:
			mob_sprite.update_hp_bar(int(mob_node.hp), int(mob_node.ht))
			_apply_snapshot_hp_feedback(mob_sprite, int(mob_node.pos), previous_state, int(mob_node.hp))
	_cleanup_dead_mobs()

func _apply_snapshot_action_feedback(sprite_node: Variant, current_pos: int, previous_state: Dictionary, action_name: String, target_pos: int) -> void:
	if sprite_node == null or not is_instance_valid(sprite_node):
		return
	if action_name.is_empty():
		return
	var previous_action: String = str(previous_state.get("action", ""))
	var previous_target_pos: int = int(previous_state.get("target_pos", -1))
	if previous_action == action_name and previous_target_pos == target_pos:
		return
	match action_name:
		"attack":
			if target_pos >= 0 and sprite_node.has_method("play_attack"):
				sprite_node.play_attack(target_pos)
		"interact":
			if target_pos >= 0:
				if sprite_node.has_method("play_operate"):
					sprite_node.play_operate(target_pos)
				elif sprite_node.has_method("play_attack"):
					sprite_node.play_attack(target_pos)
		"throw_item":
			if target_pos >= 0:
				if sprite_node.has_method("play_attack"):
					sprite_node.play_attack(target_pos)
				if effect_manager != null:
					effect_manager.shoot_projectile(current_pos, target_pos, Color(0.9, 0.85, 0.65), 260.0)
		"zap_wand":
			if target_pos >= 0:
				if sprite_node.has_method("play_attack"):
					sprite_node.play_attack(target_pos)
				if effect_manager != null:
					effect_manager.lightning(current_pos, target_pos, Color(0.6, 0.8, 1.0))
		"search":
			if effect_manager != null:
				effect_manager.show_status(current_pos, "Search", Color(0.85, 0.9, 0.65))

func _apply_snapshot_hp_feedback(sprite_node: Variant, current_pos: int, previous_state: Dictionary, current_hp: int) -> void:
	if previous_state.is_empty():
		return
	var previous_hp: int = int(previous_state.get("hp", current_hp))
	if previous_hp == current_hp or effect_manager == null:
		return
	var delta: int = current_hp - previous_hp
	if delta < 0:
		effect_manager.show_damage(current_pos, abs(delta))
		if sprite_node != null and is_instance_valid(sprite_node) and sprite_node.has_method("flash"):
			sprite_node.flash(Color(1.0, 0.35, 0.35), 0.16)
	else:
		effect_manager.show_heal(current_pos, delta)
		if sprite_node != null and is_instance_valid(sprite_node) and sprite_node.has_method("flash"):
			sprite_node.flash(Color(0.45, 1.0, 0.55), 0.16)

# ---------------------------------------------------------------------------
# Layer Setup
# ---------------------------------------------------------------------------

func _create_layers() -> void:
	# Tile map layer (z = -10)
	tile_map = _instantiate_script("res://src/tiles/tile_map_manager.gd")
	tile_map.name = "TileMap"
	add_child(tile_map)

	# Blob overlay layer (z = -2, above terrain and below entities)
	_blob_layer = BlobOverlayLayer.new()
	_blob_layer.name = "BlobOverlayLayer"
	_blob_layer.z_index = -2
	add_child(_blob_layer)

	# Entity layer (z = 0, contains hero/mob/item sprites)
	_entity_layer = Node2D.new()
	_entity_layer.name = "EntityLayer"
	_entity_layer.z_index = 0
	add_child(_entity_layer)

	# Effect layer (z = 50)
	effect_manager = _instantiate_script("res://src/effects/effect_manager.gd")
	effect_manager.name = "EffectManager"
	add_child(effect_manager)

	# Fog of war layer (z = 100)
	fog_of_war = _instantiate_script("res://src/tiles/fog_of_war.gd")
	fog_of_war.name = "FogOfWar"
	add_child(fog_of_war)

	# Camera
	game_camera = _instantiate_script("res://src/scenes/game_camera.gd")
	game_camera.name = "GameCamera"
	add_child(game_camera)
	game_camera.make_current()

	# HUD (CanvasLayer, renders above everything)
	_hud = _instantiate_script("res://src/ui/hud.gd")
	_hud.name = "HUD"
	add_child(_hud)

func _connect_signals() -> void:
	if EventBus:
		if EventBus.has_signal("hero_moved_detailed"):
			EventBus.hero_moved_detailed.connect(_on_hero_moved_detailed)
		else:
			EventBus.hero_moved.connect(_on_hero_moved)
		EventBus.mob_defeated.connect(_on_mob_defeated)
		EventBus.item_picked_up.connect(_on_item_picked_up)
		EventBus.door_opened.connect(_on_door_opened)
		if EventBus.has_signal("hero_damaged_detailed"):
			EventBus.hero_damaged_detailed.connect(_on_hero_damaged_detailed)
		else:
			EventBus.hero_damaged.connect(_on_hero_damaged)
		if EventBus.has_signal("hero_died_detailed"):
			EventBus.hero_died_detailed.connect(_on_hero_died_detailed)
		else:
			EventBus.hero_died.connect(_on_hero_died)
		if EventBus.has_signal("mob_revealed"):
			EventBus.mob_revealed.connect(_on_mob_revealed)
		if EventBus.has_signal("mob_moved_detailed"):
			EventBus.mob_moved_detailed.connect(_on_mob_moved_detailed)
		if EventBus.has_signal("mob_damaged"):
			EventBus.mob_damaged.connect(_on_mob_damaged)
		if EventBus.has_signal("hero_attack_missed"):
			EventBus.hero_attack_missed.connect(_on_hero_attack_missed)
		EventBus.gold_collected.connect(_on_gold_collected)
		EventBus.trap_triggered.connect(_on_trap_triggered)
		EventBus.enchantment_proc.connect(_on_enchantment_proc)
		EventBus.glyph_proc.connect(_on_glyph_proc)
		# Additional audio-relevant signals
		if EventBus.has_signal("item_used"):
			EventBus.item_used.connect(_on_item_used_sfx)
		if EventBus.has_signal("hero_trampled_grass"):
			EventBus.hero_trampled_grass.connect(_on_grass_trampled_sfx)
		if EventBus.has_signal("seed_planted"):
			EventBus.seed_planted.connect(_on_seed_planted)
		if EventBus.has_signal("plant_activated"):
			EventBus.plant_activated.connect(_on_plant_activated_vfx)
		if EventBus.has_signal("status_effect_applied"):
			EventBus.status_effect_applied.connect(_on_status_effect_applied)
		if EventBus.has_signal("badge_unlocked"):
			EventBus.badge_unlocked.connect(_on_badge_unlocked_sfx)
		if EventBus.has_signal("item_equipped"):
			EventBus.item_equipped.connect(_on_item_equipped_sfx)
		if EventBus.has_signal("item_unequipped"):
			EventBus.item_unequipped.connect(_on_item_unequipped_visuals)

		if EventBus.has_signal("enter_targeting"):
			EventBus.enter_targeting.connect(_on_enter_targeting)
		if EventBus.has_signal("cancel_targeting"):
			EventBus.cancel_targeting.connect(_on_cancel_targeting)
		if EventBus.has_signal("request_hero_action"):
			EventBus.request_hero_action.connect(_on_request_hero_action)

	if TurnManager and not TurnManager.round_completed.is_connected(_on_round_completed):
		TurnManager.round_completed.connect(_on_round_completed)
	if TurnManager and TurnManager.has_signal("input_actor_changed"):
		if not TurnManager.input_actor_changed.is_connected(_on_input_actor_changed):
			TurnManager.input_actor_changed.connect(_on_input_actor_changed)
	if GameManager and GameManager.has_signal("local_hero_changed"):
		if not GameManager.local_hero_changed.is_connected(_on_local_hero_changed):
			GameManager.local_hero_changed.connect(_on_local_hero_changed)
	if NetworkManager and NetworkManager.has_signal("online_action_requested"):
		if not NetworkManager.online_action_requested.is_connected(_on_online_action_requested):
			NetworkManager.online_action_requested.connect(_on_online_action_requested)
	if NetworkManager and NetworkManager.has_signal("online_action_rejected"):
		if not NetworkManager.online_action_rejected.is_connected(_on_online_action_rejected):
			NetworkManager.online_action_rejected.connect(_on_online_action_rejected)
	if NetworkManager and NetworkManager.has_signal("run_snapshot_received"):
		if not NetworkManager.run_snapshot_received.is_connected(_on_run_snapshot_received):
			NetworkManager.run_snapshot_received.connect(_on_run_snapshot_received)
	if NetworkManager and NetworkManager.has_signal("online_world_event_received"):
		if not NetworkManager.online_world_event_received.is_connected(_on_online_world_event_received):
			NetworkManager.online_world_event_received.connect(_on_online_world_event_received)
	if NetworkManager and NetworkManager.has_signal("online_ui_event_received"):
		if not NetworkManager.online_ui_event_received.is_connected(_on_online_ui_event_received):
			NetworkManager.online_ui_event_received.connect(_on_online_ui_event_received)
	if NetworkManager and NetworkManager.has_signal("online_level_transition_requested"):
		if not NetworkManager.online_level_transition_requested.is_connected(_on_online_level_transition_requested):
			NetworkManager.online_level_transition_requested.connect(_on_online_level_transition_requested)
	if NetworkManager and NetworkManager.has_signal("online_run_ended"):
		if not NetworkManager.online_run_ended.is_connected(_on_online_run_ended):
			NetworkManager.online_run_ended.connect(_on_online_run_ended)
	if NetworkManager and NetworkManager.has_signal("disconnected"):
		if not NetworkManager.disconnected.is_connected(_on_network_disconnected):
			NetworkManager.disconnected.connect(_on_network_disconnected)

	# HUD toolbar connections — only connect wait/search (gameplay actions).
	# Inventory/map/settings are handled by HUD directly; connecting here
	# would duplicate window opens.
	var tb: Variant = _hud.get("_toolbar_bar") if _hud else null
	if tb:
		if tb.has_signal("wait_pressed"):
			if not tb.wait_pressed.is_connected(_on_toolbar_wait):
				tb.wait_pressed.connect(_on_toolbar_wait)
		if tb.has_signal("search_pressed"):
			if not tb.search_pressed.is_connected(_on_toolbar_search):
				tb.search_pressed.connect(_on_toolbar_search)

# ---------------------------------------------------------------------------
# Entity Sprite Management
# ---------------------------------------------------------------------------

func _spawn_hero_sprites() -> void:
	for hero: Node in GameManager.heroes:
		if hero == null:
			continue
		var sprite: Variant = _instantiate_script("res://src/sprites/hero_sprite.gd")
		sprite.setup_for_class(hero.hero_class)
		_apply_hero_equipment_visuals(sprite, hero)
		sprite.place_at(hero.pos)
		sprite.character = hero
		_entity_layer.add_child(sprite)
		_hero_sprites[hero.actor_id] = sprite
		hero.sprite = sprite
	_refresh_hero_identifiers()

func _refresh_hero_identifiers() -> void:
	SceneVisualCoordinator.refresh_hero_identifiers(self)

func _spawn_mob_sprites() -> void:
	if _current_level == null:
		return
	for mob: Variant in _current_level.mobs:
		if mob is Object and mob.get("is_alive") == true:
			_spawn_single_mob_sprite(mob)

func _ensure_mob_sprites() -> void:
	if _current_level == null:
		return
	for mob: Variant in _current_level.mobs:
		if not (mob is Object) or mob.get("is_alive") != true:
			continue
		var mob_key: int = mob.get("actor_id") if mob.get("actor_id") != null else mob.get_instance_id()
		if _mob_sprites.has(mob_key):
			continue
		_spawn_single_mob_sprite(mob)

func _spawn_single_mob_sprite(mob: Variant) -> void:
	# Disguised mimics render as item sprites until revealed
	if mob.get("disguised") == true and mob.get("mob_id") == "mimic":
		var item_sprite: Variant = _instantiate_script("res://src/sprites/item_sprite.gd")
		var fake_item_id: String = str(mob.get("fake_item_id")) if mob.get("fake_item_id") != null else ""
		var fake_item: Variant = Generator.create_item(fake_item_id)
		if fake_item != null:
			item_sprite.setup_from_item(fake_item)
		else:
			item_sprite.setup_manual(ConstantsData.ItemCategory.MISC)
		item_sprite.place_at(mob.get("pos"))
		_entity_layer.add_child(item_sprite)
		var mob_key: int = mob.get("actor_id") if mob.get("actor_id") != null else mob.get_instance_id()
		_item_sprites[mob.get("pos")] = item_sprite
		# Store reference so we can swap it on reveal
		_mob_sprites[mob_key] = null  # placeholder
		return

	var mob_id: String = mob.get("mob_id") if mob.get("mob_id") else "rat"
	var sprite: Variant = null
	if mob_id == "mirror_image":
		var image_sprite: Variant = _instantiate_script("res://src/sprites/hero_sprite.gd")
		var image_class: int = int(mob.get("source_hero_class")) if mob.get("source_hero_class") != null else ConstantsData.HeroClass.WARRIOR
		image_sprite.setup_for_class(image_class)
		image_sprite.modulate = Color(0.7, 0.9, 1.0, 0.85)
		sprite = image_sprite
	else:
		var mob_sprite: Variant = _instantiate_script("res://src/sprites/mob_sprite.gd")
		mob_sprite.setup_for_mob(mob_id)
		sprite = mob_sprite
	sprite.place_at(mob.get("pos"))
	sprite.character = mob
	_entity_layer.add_child(sprite)
	var mob_key: int = mob.get("actor_id") if mob.get("actor_id") != null else mob.get_instance_id()
	_mob_sprites[mob_key] = sprite
	if mob is Object:
		mob.set("sprite", sprite)
	# Ensure the mob Node is in the scene tree (for queue_free on buffs)
	if mob is Node and not mob.is_inside_tree():
		add_child(mob)

func _spawn_item_sprites() -> void:
	if _current_level == null:
		return
	for heap: Dictionary in _current_level.heaps:
		var pos: int = heap.get("pos", -1)
		if pos < 0 or _item_sprites.has(pos):
			continue
		var sprite: Variant = _instantiate_script("res://src/sprites/item_sprite.gd")
		var item: Variant = heap.get("item")
		if item:
			sprite.setup_from_item(item)
		else:
			sprite.setup_manual(ConstantsData.ItemCategory.MISC)
		sprite.place_at(pos)
		_entity_layer.add_child(sprite)
		_item_sprites[pos] = sprite

func _clear_entity_sprites() -> void:
	for sprite: Variant in _hero_sprites.values():
		if sprite is Node and is_instance_valid(sprite):
			sprite.queue_free()
	_hero_sprites.clear()
	for sprite: Variant in _mob_sprites.values():
		if sprite is Node and is_instance_valid(sprite):
			sprite.queue_free()
	_mob_sprites.clear()
	for sprite: Variant in _item_sprites.values():
		if sprite is Node and is_instance_valid(sprite):
			sprite.queue_free()
	_item_sprites.clear()
	for sprite: Variant in _plant_sprites.values():
		if sprite is Node and is_instance_valid(sprite):
			sprite.queue_free()
	_plant_sprites.clear()
	for sprite: Variant in _armed_bomb_sprites.values():
		if sprite is Node and is_instance_valid(sprite):
			sprite.queue_free()
	_armed_bomb_sprites.clear()
	if _blob_layer:
		_blob_layer.clear_cells()

func _cleanup_dead_mobs() -> void:
	SceneVisualCoordinator.cleanup_dead_mobs(self)

func _refresh_item_sprites() -> void:
	SceneVisualCoordinator.refresh_item_sprites(self)

func _refresh_armed_bomb_sprites() -> void:
	SceneVisualCoordinator.refresh_armed_bomb_sprites(self)

func _refresh_plant_sprites() -> void:
	SceneVisualCoordinator.refresh_plant_sprites(self)

func _refresh_blob_overlays() -> void:
	SceneVisualCoordinator.refresh_blob_overlays(self)

func _update_entity_visibility() -> void:
	SceneVisualCoordinator.update_entity_visibility(self)
	return

	if _current_level == null:
		return
	_refresh_hero_identifiers()
	# Hero sprites always visible (they're the player)
	# Mob sprites: sync position AND visibility after mob turns
	for key: Variant in _mob_sprites.keys():
		var sprite: Variant = _mob_sprites[key]
		if sprite == null:
			continue  # Disguised mimic placeholder
		if not (sprite is Node2D) or not sprite.has_method("set_visible_state"):
			continue
		if not is_instance_valid(sprite.character):
			# Character was freed — hide sprite, cleanup will happen in _cleanup_dead_mobs
			sprite.set_visible_state(false)
		elif sprite.character is Object:
			var mob_pos: int = sprite.character.get("pos")
			# Sync sprite position to mob's logical position (mob may have moved)
			if mob_pos >= 0 and mob_pos != sprite.cell_pos:
				sprite.move_to(mob_pos)
			if mob_pos >= 0 and mob_pos < _current_level.visible.size():
				sprite.set_visible_state(_current_level.visible[mob_pos])
			else:
				sprite.set_visible_state(false)
			# Update mob health bar
			if sprite.character.get("hp") != null and sprite.character.get("ht") != null:
				sprite.update_hp_bar(sprite.character.hp, sprite.character.ht)
	# Item sprites visible if cell is visible or visited
	for pos: int in _item_sprites.keys():
		var sprite: Variant = _item_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	for pos: int in _plant_sprites.keys():
		var plant_sprite: Variant = _plant_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			plant_sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	for pos: int in _armed_bomb_sprites.keys():
		var bomb_sprite: Variant = _armed_bomb_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			bomb_sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	_refresh_blob_overlays()

# ---------------------------------------------------------------------------
# Input Handling
# ---------------------------------------------------------------------------

func _handle_cell_click(cell: int) -> void:
	InputCoordinator.handle_cell_click(self, cell)
	return

	var hero: Variant = _get_input_hero()
	if hero == null:
		return

	# --- Targeting mode: select target cell ---
	if _targeting_active:
		_resolve_targeting(cell)
		return

	# Any manual click cancels auto-walk
	_cancel_auto_walk()

	var hero_pos: int = hero.pos

	# Check what's at the clicked cell
	var char_at: Variant = _current_level.find_char_at(cell) if _current_level else null

	if char_at != null and char_at != hero:
		# Interact with adjacent NPCs instead of attacking them.
		if _current_level.adjacent(hero_pos, cell):
			if char_at.has_method("interact"):
				_submit_hero_action({"type": "interact", "target_pos": cell})
			else:
				_submit_hero_action({"type": "attack", "target": char_at, "target_pos": cell})
		else:
			var ranged_action: Dictionary = hero.get_auto_ranged_action(cell) if hero.has_method("get_auto_ranged_action") else {}
			if not ranged_action.is_empty():
				_submit_hero_action(ranged_action)
			else:
				# Auto-walk toward enemy (will stop when adjacent)
				_start_auto_walk(cell)
				_submit_hero_action({"type": "move", "target_pos": cell})
	elif cell == hero_pos:
		# Click on self: if on stairs, use them; otherwise wait
		var self_terrain: int = _current_level.terrain_at(cell) if _current_level else ConstantsData.Terrain.WALL
		if self_terrain == ConstantsData.Terrain.ENTRANCE and cell == _current_level.entrance:
			_submit_hero_action({"type": "ascend"})
		elif self_terrain == ConstantsData.Terrain.EXIT and cell == _current_level.exit_pos:
			_submit_hero_action({"type": "descend"})
		else:
			_submit_hero_action({"type": "wait"})
	else:
		# Move to cell — if adjacent, just move; if distant, auto-walk
		if _current_level and _current_level.adjacent(hero_pos, cell):
			var terrain: int = _current_level.terrain_at(cell)
			if terrain == ConstantsData.Terrain.DOOR or terrain == ConstantsData.Terrain.LOCKED_DOOR or terrain == ConstantsData.Terrain.CRYSTAL_DOOR:
				_submit_hero_action({"type": "interact", "target_pos": cell})
			elif not _current_level.passable[cell]:
				_submit_hero_action({"type": "search"})
			else:
				_submit_hero_action({"type": "move", "target_pos": cell})
		else:
			_start_auto_walk(cell)
			_submit_hero_action({"type": "move", "target_pos": cell})

func _handle_key_input(keycode: int) -> bool:
	return InputCoordinator.handle_key_input(self, keycode)

	# ESC cancels targeting mode
	if _targeting_active and keycode == KEY_ESCAPE:
		_cancel_targeting_mode()
		return true

	# Any keyboard input cancels auto-walk
	_cancel_auto_walk()
	match keycode:
		KEY_TAB:
			if GameManager and GameManager.has_method("is_party_run") and GameManager.is_party_run():
				if GameManager.has_method("cycle_local_hero_focus"):
					GameManager.cycle_local_hero_focus(1)
					return true
		KEY_A, KEY_F:
			_attack_adjacent_enemy()
			return true
		KEY_I:
			if _hud:
				_hud.toggle_inventory()
				return true
		KEY_M:
			if _hud:
				_hud.toggle_map()
				return true
		KEY_R:
			if _hud:
				_hud._on_rest_pressed()
				return true
		KEY_ESCAPE:
			if _hud and not _hud.has_active_window():
				_hud.open_settings()
				return true
		KEY_1:
			if _hud:
				_hud.use_quickslot(0)
				return true
		KEY_2:
			if _hud:
				_hud.use_quickslot(1)
				return true
		KEY_3:
			if _hud:
				_hud.use_quickslot(2)
				return true
		KEY_4:
			if _hud:
				_hud.use_quickslot(3)
				return true
		KEY_5:
			if _hud:
				_hud.use_quickslot(4)
				return true
		KEY_6:
			if _hud:
				_hud.use_quickslot(5)
				return true
		KEY_SPACE:
			_submit_hero_action({"type": "wait"})
			return true
		KEY_PERIOD:
			_submit_hero_action({"type": "wait"})
			return true
		KEY_S:
			_submit_hero_action({"type": "search"})
			return true
		KEY_ENTER, KEY_KP_ENTER:
			var hero: Variant = _get_input_hero()
			if hero != null and _current_level != null:
				var terrain: int = _current_level.terrain_at(hero.pos)
				if terrain == ConstantsData.Terrain.ENTRANCE and hero.pos == _current_level.entrance:
					_submit_hero_action({"type": "ascend"})
					return true
				if terrain == ConstantsData.Terrain.EXIT and hero.pos == _current_level.exit_pos:
					_submit_hero_action({"type": "descend"})
					return true
		KEY_LESS:
			_submit_hero_action({"type": "ascend"})
			return true
		KEY_GREATER:
			_submit_hero_action({"type": "descend"})
			return true
	var move_dir: int = _movement_dir_for_key(keycode)
	if move_dir != 0:
		_set_held_move_state(keycode, move_dir)
		_move_direction(move_dir)
		return true
	return false

func _move_direction(dir_offset: int) -> void:
	InputCoordinator.move_direction(self, dir_offset)
	return

	var hero: Variant = _get_input_hero()
	if hero == null:
		return
	var target: int = hero.pos + dir_offset
	if not ConstantsData.is_valid_pos(target):
		return

	# Check for enemy at target
	var char_at: Variant = _current_level.find_char_at(target) if _current_level else null
	if char_at != null and char_at != hero:
		if char_at.has_method("interact"):
			_submit_hero_action({"type": "interact", "target_pos": target})
		else:
			_submit_hero_action({"type": "attack", "target": char_at, "target_pos": target})
	else:
		var terrain: int = _current_level.terrain_at(target)
		if terrain == ConstantsData.Terrain.DOOR or terrain == ConstantsData.Terrain.LOCKED_DOOR or terrain == ConstantsData.Terrain.CRYSTAL_DOOR:
			_submit_hero_action({"type": "interact", "target_pos": target})
		elif not _current_level.passable[target]:
			_submit_hero_action({"type": "search"})
		else:
			_submit_hero_action({"type": "move", "target_pos": target})

func _attack_adjacent_enemy() -> void:
	InputCoordinator.attack_adjacent_enemy(self)
	return

	var hero: Variant = _get_input_hero()
	if hero == null or _current_level == null:
		return

	var hero_pos: int = hero.pos
	for dir: int in ConstantsData.DIRS_8:
		var target_pos: int = hero_pos + dir
		if not ConstantsData.is_valid_pos(target_pos):
			continue
		var char_at: Variant = _current_level.find_char_at(target_pos)
		if char_at == null or char_at == hero or char_at.has_method("interact"):
			continue
		_submit_hero_action({"type": "attack", "target": char_at, "target_pos": target_pos})
		return

	if MessageLog:
		MessageLog.add_warning("No adjacent enemy to attack.")

func _submit_hero_action(action: Dictionary) -> void:
	OnlineSyncCoordinator.submit_hero_action(self, action, _EQUIP_SLOT_NAMES)

func _apply_action_for_hero(hero: Variant, action: Dictionary) -> void:
	if hero == null:
		return
	var resolved_action: Dictionary = OnlineActionCodec.normalize_action_for_hero(hero, action, _current_level)
	if _apply_inventory_action_for_hero(hero, resolved_action):
		_awaiting_hero_input = true
		call_deferred("refresh_after_turn")
		return
	_awaiting_hero_input = false

	var action_type: String = resolved_action.get("type", "")

	# Handle level transitions before submitting to hero
	if action_type == "descend":
		_handle_descend()
		return
	if action_type == "ascend":
		_handle_ascend()
		return

	# Check for victory (Amulet of Yendor use)
	if action_type == "use_item":
		var item: Variant = resolved_action.get("item")
		if item is Object and item.get("item_id") == "amulet_of_yendor":
			_transition_to_victory()
			return

	# Submit action to hero via command pattern.
	# hero.submit_action() calls execute_action() which handles:
	#   - process_buffs(), the action itself, spend_turn(), and hero_action_complete()
	# Do NOT call spend_energy or hero_action_complete again here.
	if hero.has_method("submit_action"):
		hero.submit_action(resolved_action)

	# Animate the action
	_animate_action_for_hero(hero, resolved_action)

	# After action executes, refresh visuals
	call_deferred("refresh_after_turn")

func _preview_online_local_action(hero: Variant, action: Dictionary) -> void:
	if hero == null:
		return
	var hero_sprite: Variant = _hero_sprites.get(hero.actor_id) if hero.get("actor_id") != null else null
	if hero_sprite == null:
		return
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"move":
			var target_pos: int = int(action.get("target_pos", -1))
			if target_pos >= 0:
				hero_sprite.move_to(target_pos)
				if game_camera and tile_map:
					game_camera.set_target(tile_map.cell_to_world(target_pos))
		"attack", "throw_item", "zap_wand":
			var target_pos: int = int(action.get("target_pos", -1))
			if target_pos >= 0 and hero_sprite.has_method("play_attack"):
				hero_sprite.play_attack(target_pos)
		"search":
			if effect_manager:
				effect_manager.show_status(hero.pos, "Search", Color(0.85, 0.9, 0.65))
		"interact":
			var interact_target: int = int(action.get("target_pos", -1))
			if interact_target >= 0 and hero_sprite.has_method("play_attack"):
				hero_sprite.play_attack(interact_target)

func _should_route_online_action(hero_node: Variant) -> bool:
	var routing: Dictionary = OnlineEventCodec.should_route_online_action(NetworkManager, hero_node)
	var message: String = str(routing.get("message", ""))
	if not message.is_empty() and MessageLog:
		if message == "It is not your hero's turn.":
			MessageLog.add_warning(message)
		else:
			MessageLog.add(message)
	return bool(routing.get("route", false))

func _apply_inventory_action_for_hero(hero_node: Variant, action: Dictionary) -> bool:
	if hero_node == null:
		return false
	var action_type: String = str(action.get("type", ""))
	var belongings: Variant = hero_node.get("belongings")
	match action_type:
		"equip_item":
			var item_to_equip: Variant = action.get("item")
			if belongings == null or item_to_equip == null:
				return true
			var category: int = int(ConstantsData.get_prop(item_to_equip, "category", -1))
			belongings.remove_item(item_to_equip)
			var old_item: Variant = null
			match category:
				ConstantsData.ItemCategory.WEAPON:
					if item_to_equip is SpiritBow:
						old_item = belongings.equip_spirit_bow(item_to_equip)
					else:
						old_item = belongings.equip_weapon(item_to_equip)
				ConstantsData.ItemCategory.ARMOR:
					old_item = belongings.equip_armor(item_to_equip)
				ConstantsData.ItemCategory.ARTIFACT:
					old_item = belongings.equip_artifact(item_to_equip)
				ConstantsData.ItemCategory.WAND:
					old_item = belongings.equip_misc(item_to_equip)
				ConstantsData.ItemCategory.RING:
					old_item = belongings.equip_ring(item_to_equip, belongings.ring_left == null)
			if old_item != null:
				belongings.add_item(old_item)
			if EventBus:
				EventBus.item_equipped.emit(ConstantsData.get_prop(item_to_equip, "item_name", ""), str(category))
			return true
		"unequip_item":
			var slot_name: String = str(action.get("slot", ""))
			if belongings == null or slot_name.is_empty():
				return true
			var equipped_item: Variant = belongings.get(slot_name)
			if equipped_item == null:
				return true
			if ConstantsData.get_prop(equipped_item, "cursed", false) and ConstantsData.get_prop(equipped_item, "cursed_known", false):
				_deliver_hero_message(hero_node, "You cannot remove the cursed %s!" % ConstantsData.get_prop(equipped_item, "item_name", "item"), "warning")
				return true
			if not belongings.has_space():
				_deliver_hero_message(hero_node, "Your inventory is full!", "warning")
				return true
			var removed_item: Variant = belongings.unequip(slot_name)
			if removed_item != null:
				belongings.add_item(removed_item)
				if EventBus:
					EventBus.item_unequipped.emit(ConstantsData.get_prop(removed_item, "item_name", ""), slot_name)
			return true
		"drop_item":
			var item_to_drop: Variant = action.get("item")
			if belongings == null or item_to_drop == null or _current_level == null:
				return true
			var equip_slot: String = str(action.get("equip_slot", ""))
			if not equip_slot.is_empty():
				if ConstantsData.get_prop(item_to_drop, "cursed", false) and ConstantsData.get_prop(item_to_drop, "cursed_known", false):
					_deliver_hero_message(hero_node, "You cannot remove the cursed %s!" % ConstantsData.get_prop(item_to_drop, "item_name", "item"), "warning")
					return true
				item_to_drop = belongings.unequip(equip_slot)
			else:
				belongings.remove_item(item_to_drop)
			if item_to_drop != null:
				var drop_pos: int = int(ConstantsData.get_prop(hero_node, "pos", 0))
				_current_level.drop_item(drop_pos, item_to_drop)
				if item_to_drop.has_method("on_drop"):
					item_to_drop.on_drop(hero_node)
				_deliver_hero_message(hero_node, "Dropped %s." % ConstantsData.get_prop(item_to_drop, "item_name", "item"))
				if _is_online_host() and item_to_drop.has_method("serialize"):
					OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_item_dropped_world_event_payload(drop_pos, item_to_drop, hero_node))
			return true
		"set_quickslot":
			if belongings != null and belongings.has_method("set_quickslot"):
				belongings.set_quickslot(int(action.get("slot_index", -1)), action.get("item"))
			return true
		"clear_quickslot":
			if belongings != null and belongings.has_method("clear_quickslot"):
				belongings.clear_quickslot(int(action.get("slot_index", -1)))
			return true
		"upgrade_talent":
			if hero_node.has_method("upgrade_talent"):
				hero_node.upgrade_talent(str(action.get("talent_id", "")))
			return true
		"feed_seed_to_sandals":
			if belongings == null:
				return true
			var seed_item: Variant = action.get("item")
			var equipped_artifact: Variant = belongings.get_equipped_artifact() if belongings.has_method("get_equipped_artifact") else null
			if seed_item == null or equipped_artifact == null:
				return true
			if str(ConstantsData.get_prop(equipped_artifact, "item_id", "")) != "sandals_of_nature" or not equipped_artifact.has_method("feed_seed"):
				return true
			var seed_name: String = ConstantsData.get_prop(seed_item, "item_name", "seed")
			equipped_artifact.feed_seed(seed_name)
			var quantity: int = int(ConstantsData.get_prop(seed_item, "quantity", 1))
			if quantity > 1:
				seed_item.quantity = quantity - 1
			else:
				belongings.remove_item(seed_item)
			if EventBus:
				EventBus.item_used.emit(seed_name)
			return true
		"shop_buy":
			var shopkeeper_actor_id: int = int(action.get("shopkeeper_actor_id", -1))
			var item_index: int = int(action.get("item_index", -1))
			var shopkeeper_node: Variant = _find_mob_by_actor_id(shopkeeper_actor_id)
			if shopkeeper_node != null and shopkeeper_node.has_method("buy_item"):
				var buy_success: bool = shopkeeper_node.buy_item(hero_node, item_index)
				if buy_success and _is_online_host():
					OnlineEventCodec.send_shop_refresh(NetworkManager, hero_node, shopkeeper_actor_id, shopkeeper_node)
			return true
		"shop_sell":
			var selling_item: Variant = action.get("item")
			var selling_shopkeeper_actor_id: int = int(action.get("shopkeeper_actor_id", -1))
			var selling_shopkeeper: Variant = _find_mob_by_actor_id(selling_shopkeeper_actor_id)
			if selling_item != null and selling_shopkeeper != null and selling_shopkeeper.has_method("sell_item"):
				var sell_gold: int = selling_shopkeeper.sell_item(hero_node, selling_item)
				if sell_gold > 0 and _is_online_host():
					OnlineEventCodec.send_shop_refresh(NetworkManager, hero_node, selling_shopkeeper_actor_id, selling_shopkeeper)
			return true
		"claim_quest_reward":
			var npc_actor_id: int = int(action.get("npc_actor_id", -1))
			var reward_index: int = int(action.get("reward_index", -1))
			var npc_node: Variant = _find_mob_by_actor_id(npc_actor_id)
			var reward_choices: Array = OnlineEventCodec.get_npc_reward_choices(npc_node)
			if npc_node == null or reward_index < 0 or reward_index >= reward_choices.size():
				return true
			var chosen_reward: Variant = reward_choices[reward_index]
			if belongings != null and chosen_reward != null and belongings.has_method("add_item"):
				belongings.add_item(chosen_reward)
				var chosen_name: String = ConstantsData.get_prop(chosen_reward, "item_name", "item")
				if chosen_reward.has_method("get_display_name"):
					chosen_name = chosen_reward.get_display_name()
				_deliver_hero_message(hero_node, "You receive the %s!" % chosen_name, "positive")
			if npc_node.has_method("_on_reward_window_closed"):
				npc_node._on_reward_window_closed(chosen_reward)
			elif npc_node.has_method("_on_reward_chosen"):
				npc_node._on_reward_chosen(chosen_reward)
			return true
		"identify_item":
			var identify_item: Variant = action.get("item")
			if identify_item == null:
				return true
			if identify_item.has_method("identify"):
				identify_item.identify()
			var identify_name: String = identify_item.get_display_name() if identify_item.has_method("get_display_name") else str(ConstantsData.get_prop(identify_item, "item_name", "item"))
			_deliver_hero_message(hero_node, "You identify the %s!" % identify_name, "positive")
			return true
		"upgrade_item":
			var upgrade_item: Variant = action.get("item")
			if upgrade_item == null:
				return true
			if upgrade_item.has_method("upgrade"):
				upgrade_item.upgrade()
			if upgrade_item.has_method("identify"):
				upgrade_item.identify()
			var upgrade_name: String = upgrade_item.get_display_name() if upgrade_item.has_method("get_display_name") else str(ConstantsData.get_prop(upgrade_item, "item_name", "item"))
			_deliver_hero_message(hero_node, "Your %s glows brightly!" % upgrade_name, "positive")
			if GameManager:
				GameManager.record_stat("scrolls_of_upgrade")
			return true
		"recycle_item":
			var recycle_item: Variant = action.get("item")
			if recycle_item == null or belongings == null:
				return true
			var recycle_script: GDScript = load("res://src/items/spells/spell.gd") as GDScript
			if recycle_script == null:
				return true
			var pool: Array[String] = recycle_script.call("_recycle_pool_for_item", recycle_item)
			var current_id: String = str(ConstantsData.get_prop(recycle_item, "item_id", ""))
			pool.erase(current_id)
			if pool.is_empty() and not current_id.is_empty():
				pool.append(current_id)
			if pool.is_empty():
				_deliver_hero_message(hero_node, "The spell cannot transmute that item.", "warning")
				return true
			var new_id: String = pool[randi() % pool.size()]
			var replacement: Variant = Generator.create_item(new_id)
			if replacement == null:
				_deliver_hero_message(hero_node, "The spell fizzles and fails to transmute the item.", "warning")
				return true
			if ConstantsData.get_prop(recycle_item, "stackable", false) and int(ConstantsData.get_prop(recycle_item, "quantity", 1)) > 1 and recycle_item.has_method("split"):
				recycle_item.split(1)
			else:
				belongings.remove_item(recycle_item)
			belongings.add_item(replacement)
			var old_name: String = recycle_item.get_display_name() if recycle_item.has_method("get_display_name") else str(ConstantsData.get_prop(recycle_item, "item_name", "item"))
			var new_name: String = replacement.get_display_name() if replacement.has_method("get_display_name") else str(ConstantsData.get_prop(replacement, "item_name", "item"))
			_deliver_hero_message(hero_node, "%s twists into %s!" % [old_name, new_name], "positive")
			return true
		"curse_infusion_item":
			var infusion_item: Variant = action.get("item")
			if infusion_item == null:
				return true
			if infusion_item.has_method("upgrade"):
				infusion_item.upgrade()
			infusion_item.cursed = true
			infusion_item.cursed_known = true
			if infusion_item is Weapon or infusion_item is Armor:
				infusion_item.curse_infusion_bonus = true
			if infusion_item.has_method("identify"):
				infusion_item.identify()
			var infusion_name: String = infusion_item.get_display_name() if infusion_item.has_method("get_display_name") else str(ConstantsData.get_prop(infusion_item, "item_name", "item"))
			_deliver_hero_message(hero_node, "Dark power seeps into your %s." % infusion_name, "negative")
			if EventBus:
				EventBus.hero_stats_changed.emit()
			return true
		"stone_enchant_item":
			var enchant_item: Variant = action.get("item")
			if enchant_item == null or not enchant_item.has_method("enchant"):
				return true
			enchant_item.enchant(WeaponEnchantment.random())
			if enchant_item.has_method("identify"):
				enchant_item.identify()
			var enchant_name: String = enchant_item.get_display_name() if enchant_item.has_method("get_display_name") else str(ConstantsData.get_prop(enchant_item, "item_name", "item"))
			_deliver_hero_message(hero_node, "Your %s glows with new enchantment!" % enchant_name, "positive")
			if EventBus:
				EventBus.hero_stats_changed.emit()
			return true
		"stone_augmentation_pick_item":
			var augment_pick_item: Variant = action.get("item")
			if augment_pick_item == null:
				return true
			if _is_online_host():
				OnlineEventCodec.send_augment_select_open(NetworkManager, hero_node, augment_pick_item, "stone_augmentation_apply")
			return true
		"stone_augmentation_apply":
			var augment_item: Variant = action.get("item")
			var augment_key: String = str(action.get("augment_key", ""))
			if augment_item == null or not augment_item.has_method("apply_augment"):
				return true
			if augment_item is Armor:
				var armor: Armor = augment_item as Armor
				match augment_key:
					"evasion":
						armor.apply_augment(Armor.Augment.EVASION)
					"defense":
						armor.apply_augment(Armor.Augment.DEFENSE)
					_:
						return true
			else:
				var weapon: Weapon = augment_item as Weapon
				match augment_key:
					"speed":
						weapon.apply_augment(Weapon.Augment.SPEED)
					"damage":
						weapon.apply_augment(Weapon.Augment.DAMAGE)
					_:
						return true
			if augment_item.has_method("identify"):
				augment_item.identify()
			var augment_name: String = augment_item.get_display_name() if augment_item.has_method("get_display_name") else str(ConstantsData.get_prop(augment_item, "item_name", "item"))
			_deliver_hero_message(hero_node, "%s is augmented for %s." % [augment_name, augment_key], "positive")
			if EventBus:
				EventBus.hero_stats_changed.emit()
			return true
		"transmute_item":
			var original_item: Variant = action.get("item")
			var source_scroll: Variant = action.get("source_item")
			if belongings == null or original_item == null or source_scroll == null:
				return true
			var transmute_script: GDScript = load("res://src/ui/windows/wnd_transmute.gd") as GDScript
			if transmute_script == null or not transmute_script.has_method("transmute_item"):
				_deliver_hero_message(hero_node, "The transmutation fizzles... nothing happens.", "warning")
				return true
			var result_item: Variant = transmute_script.call("transmute_item", original_item)
			if result_item == null:
				_deliver_hero_message(hero_node, "The transmutation fizzles... nothing happens.", "warning")
				return true
			var original_name: String = ConstantsData.get_prop(original_item, "item_name", "item")
			if original_item.has_method("get_display_name"):
				original_name = original_item.get_display_name()
			var original_level: int = int(ConstantsData.get_prop(original_item, "level", 0))
			if result_item.get("level") != null:
				result_item.level = original_level
			if result_item.has_method("identify"):
				result_item.identify()
			var was_equipped_slot: String = ""
			if belongings.weapon == original_item:
				was_equipped_slot = "weapon"
			elif belongings.armor == original_item:
				was_equipped_slot = "armor"
			elif belongings.artifact == original_item:
				was_equipped_slot = "artifact"
			elif belongings.ring_left == original_item:
				was_equipped_slot = "ring_left"
			elif belongings.ring_right == original_item:
				was_equipped_slot = "ring_right"
			elif belongings.misc == original_item:
				was_equipped_slot = "misc"
			if was_equipped_slot != "":
				belongings.unequip(was_equipped_slot)
				belongings.add_item(result_item)
			else:
				belongings.remove_item(original_item)
				belongings.add_item(result_item)
			if source_scroll.has_method("_consume"):
				source_scroll._consume(hero_node)
			else:
				var source_qty: int = int(ConstantsData.get_prop(source_scroll, "quantity", 1))
				if source_qty <= 1:
					belongings.remove_item(source_scroll)
				else:
					source_scroll.quantity = source_qty - 1
			var result_name: String = ConstantsData.get_prop(result_item, "item_name", "item")
			if result_item.has_method("get_display_name"):
				result_name = result_item.get_display_name()
			_deliver_hero_message(hero_node, "Your %s shimmers and transforms into a %s!" % [original_name, result_name], "positive")
			if EventBus:
				EventBus.item_used.emit("transmutation")
			if GameManager:
				GameManager.record_stat("items_transmuted")
			return true
		"alchemy_brew":
			var ingredient_items: Variant = action.get("ingredient_items", [])
			if belongings == null or not (ingredient_items is Array):
				return true
			var recipe_script: GDScript = load("res://src/items/recipe.gd") as GDScript
			if recipe_script == null or not recipe_script.has_method("find_recipe"):
				return true
			var recipe: Variant = recipe_script.find_recipe(ingredient_items)
			if recipe == null:
				_deliver_hero_message(hero_node, "Alchemy fails: no valid recipe.", "warning")
				return true
			var brew_result: Variant = recipe.craft(hero_node, ingredient_items)
			if brew_result == null:
				return true
			belongings.add_item(brew_result)
			var toolkit: Variant = belongings.get_equipped_artifact() if belongings.has_method("get_equipped_artifact") else null
			if toolkit != null and str(ConstantsData.get_prop(toolkit, "item_id", "")) == "alchemists_toolkit" and toolkit.has_method("on_craft"):
				toolkit.on_craft(int(ConstantsData.get_prop(recipe, "energy_cost", 0)))
			var craft_msg: String = "You brewed a %s!" % ConstantsData.get_prop(brew_result, "item_name", "item")
			var energy_cost: int = int(ConstantsData.get_prop(recipe, "energy_cost", 0))
			if energy_cost > 0:
				craft_msg += " (%d energy)" % energy_cost
			_deliver_hero_message(hero_node, craft_msg)
			if EventBus:
				EventBus.item_picked_up.emit(ConstantsData.get_prop(brew_result, "item_name", "item"))
			return true
		"blacksmith_reforge":
			var blacksmith_actor_id: int = int(action.get("blacksmith_actor_id", -1))
			var item_a: Variant = action.get("item_a")
			var item_b: Variant = action.get("item_b")
			var blacksmith_node: Variant = _find_mob_by_actor_id(blacksmith_actor_id)
			if blacksmith_node == null or not blacksmith_node.has_method("reforge"):
				return true
			var reforge_success: bool = blacksmith_node.reforge(hero_node, item_a, item_b)
			if not reforge_success and _is_online_host():
				OnlineEventCodec.reject_online_action(
					NetworkManager,
					int(ConstantsData.get_prop(hero_node, "owner_peer_id", 1)),
					int(ConstantsData.get_prop(hero_node, "hero_slot_index", -1)),
					"Blacksmith refused the reforge."
				)
			return true
	return false

func _animate_hero_action(action: Dictionary) -> void:
	var hero: Variant = _get_input_hero()
	_animate_action_for_hero(hero, action)

func _animate_action_for_hero(hero: Variant, action: Dictionary) -> void:
	if hero == null:
		return
	var hero_sprite: Variant = _hero_sprites.get(hero.actor_id)
	if hero_sprite == null:
		return

	var action_from_touch: bool = _last_action_from_touch
	_last_action_from_touch = false

	match action.get("type", ""):
		"move":
			# Animate to hero's actual position (may differ from clicked cell
			# due to one-step pathfinding)
			var move_duration: float = TOUCH_MOVE_DURATION if action_from_touch else 0.15
			hero_sprite.move_to(hero.pos, move_duration)
		"attack":
			var target: int = action.get("target_pos", -1)
			if target >= 0:
				hero_sprite.play_attack(target)
		"search":
			if effect_manager:
				effect_manager.show_status(hero.pos, "Search", Color(0.85, 0.9, 0.65))
				effect_manager.particle_burst(hero.pos, Color(0.85, 0.9, 0.65), 5)
		"throw_item":
			var target: int = action.get("target_pos", -1)
			if target >= 0:
				hero_sprite.play_attack(target)
		"zap_wand":
			var target: int = action.get("target_pos", -1)
			if target >= 0:
				hero_sprite.play_attack(target)

func _on_online_action_requested(peer_id: int, slot_index: int, action: Dictionary) -> void:
	var input_hero: Variant = _get_input_hero()
	var validation_error: String = OnlineEventCodec.validate_online_action_request(NetworkManager, input_hero, slot_index)
	if validation_error == "__not_host__":
		return
	if not validation_error.is_empty():
		OnlineEventCodec.reject_online_action(NetworkManager, peer_id, slot_index, validation_error)
		return
	_apply_action_for_hero(input_hero, action)

func _on_online_action_rejected(slot_index: int, reason: String) -> void:
	if not _is_online_client():
		return
	var trimmed_reason: String = reason.strip_edges()
	if trimmed_reason.is_empty():
		trimmed_reason = "Action rejected."
	if MessageLog:
		MessageLog.add_warning(trimmed_reason)
	var local_hero: Variant = _get_focused_hero()
	if local_hero != null and int(ConstantsData.get_prop(local_hero, "hero_slot_index", -1)) == slot_index and effect_manager != null:
		effect_manager.show_status(local_hero.pos, "Blocked", Color(1.0, 0.74, 0.38))

func _deliver_hero_message(hero_node: Variant, text: String, kind: String = "info") -> void:
	var trimmed_text: String = text.strip_edges()
	if trimmed_text.is_empty():
		return
	if _is_online_host() and OnlineEventCodec.send_remote_hero_message(NetworkManager, hero_node, trimmed_text, kind):
		return
	if MessageLog == null:
		return
	match kind:
		"positive":
			MessageLog.add_positive(trimmed_text)
		"warning":
			MessageLog.add_warning(trimmed_text)
		"negative":
			MessageLog.add_negative(trimmed_text)
		_:
			MessageLog.add_info(trimmed_text)

func _on_run_snapshot_received(snapshot: Dictionary) -> void:
	if not _is_online_client():
		return
	_apply_online_snapshot(snapshot)

func _refresh_client_visibility_preview() -> void:
	if _current_level == null:
		return
	for key: Variant in _mob_sprites.keys():
		var sprite: Variant = _mob_sprites[key]
		if sprite == null or not is_instance_valid(sprite):
			continue
		if not (sprite is Node2D) or not sprite.has_method("set_visible_state"):
			continue
		var preview_pos: int = int(ConstantsData.get_prop(sprite, "cell_pos", -1))
		if preview_pos >= 0 and preview_pos < _current_level.visible.size():
			sprite.set_visible_state(_current_level.visible[preview_pos])
		else:
			sprite.set_visible_state(false)
	for pos: int in _item_sprites.keys():
		var item_sprite: Variant = _item_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			item_sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	for pos: int in _plant_sprites.keys():
		var plant_sprite: Variant = _plant_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			plant_sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	for pos: int in _armed_bomb_sprites.keys():
		var bomb_sprite: Variant = _armed_bomb_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			bomb_sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	_refresh_blob_overlays()

func _on_online_world_event_received(event: Dictionary) -> void:
	OnlineSyncCoordinator.handle_world_event(self, event)

func _on_online_ui_event_received(event: Dictionary) -> void:
	OnlineSyncCoordinator.handle_ui_event(self, event)

func _on_online_level_transition_requested(config: Dictionary) -> void:
	if not _is_online_client():
		return
	_awaiting_hero_input = false
	_cancel_auto_walk()
	if _targeting_active:
		_cancel_targeting_mode()
	var target_depth: int = int(config.get("depth", GameManager.depth if GameManager else 1))
	if GameManager != null and target_depth != GameManager.depth:
		GameManager.depth = target_depth
		if GameManager.has_method("_on_depth_changed"):
			GameManager._on_depth_changed()
	if MessageLog:
		var transition_type: String = str(config.get("transition_type", "descend"))
		if transition_type == "ascend":
			MessageLog.add("The party is ascending...")
			_pending_online_arrival_feedback = "Ascended"
		else:
			MessageLog.add("The party is descending...")
			_pending_online_arrival_feedback = "Descended"

func _on_online_run_ended(victory: bool, payload: Dictionary) -> void:
	RunTransitionCoordinator.handle_online_run_ended(self, victory, payload)

func _on_network_disconnected(reason: String) -> void:
	if reason != "Disconnected from host." or not _is_online_client():
		return
	_game_ended = true
	_awaiting_hero_input = false
	_cancel_auto_walk()
	if _targeting_active:
		_cancel_targeting_mode()
	_detach_persistent_actors()
	if MessageLog:
		MessageLog.add_warning("Lost connection to host. Returning to title.")
	var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
	if title_script:
		SceneManager.go_to(title_script, "TitleScene")

func _on_input_actor_changed(actor_node: Variant) -> void:
	if actor_node == null:
		return
	if actor_node.get("hero_slot_index") != null:
		_network_input_slot = int(actor_node.get("hero_slot_index"))
	_queue_online_snapshot_sync()

# ---------------------------------------------------------------------------
# Item Pickup & Plant Activation
# ---------------------------------------------------------------------------

## Check for items at the given hero's position and auto-pickup.
func _check_item_pickup(hero_node: Variant, hero_pos: int) -> void:
	if _current_level == null or hero_node == null:
		return
	var hero_slot_index: int = int(ConstantsData.get_prop(hero_node, "hero_slot_index", -1))
	var pickup_actor_name: String = str(ConstantsData.get_prop(hero_node, "hero_name", "Hero"))
	# Collect all heaps at this position
	var heaps_here: Array[Dictionary] = _current_level.heaps_at(hero_pos)
	for heap: Dictionary in heaps_here:
		var item: Variant = heap.get("item")
		if item == null:
			continue
		# Auto-pickup gold
		var is_gold: bool = item is Object and item.get("item_id") == "gold"
		if is_gold:
			var amount: int = item.quantity if "quantity" in item else 1
			GameManager.add_gold(amount, hero_node)
			_current_level.pickup_item(hero_pos)
			if MessageLog:
				var hero_name: String = ConstantsData.get_prop(hero_node, "hero_name", "The hero")
				MessageLog.add("%s picks up %d gold." % [hero_name, amount])
			if EventBus:
				EventBus.item_picked_up.emit("gold")
			if _is_online_host():
				OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_pickup_world_event_payload(hero_pos, "gold", pickup_actor_name, hero_slot_index))
		elif item is Object and item.get("item_id") == "dewdrop":
			var dewdrop: Variant = _current_level.pickup_item(hero_pos)
			if dewdrop != null and dewdrop.has_method("on_pickup"):
				dewdrop.on_pickup(hero_node)
			if EventBus:
				EventBus.item_picked_up.emit("Dewdrop")
			if _is_online_host():
				OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_pickup_world_event_payload(hero_pos, "Dewdrop", pickup_actor_name, hero_slot_index))
		else:
			# Add non-gold items to hero inventory
			var picked: Variant = _current_level.pickup_item(hero_pos)
			if picked != null and hero_node.belongings:
				var added: bool = false
				if hero_node.belongings.has_method("add_item"):
					added = hero_node.belongings.add_item(picked)
				if not added:
					_current_level.drop_item(hero_pos, picked)
					continue
				var item_name: String = ConstantsData.get_prop(picked, "item_name", "item") if picked is Object else "item"
				if MessageLog:
					var hero_name: String = ConstantsData.get_prop(hero_node, "hero_name", "The hero")
					MessageLog.add("%s picks up %s." % [hero_name, item_name])
				if _is_online_host():
					OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_pickup_world_event_payload(hero_pos, item_name, pickup_actor_name, hero_slot_index))

## Check for plants at the given hero's position and activate them.
func _check_plant_activation(hero_node: Variant, hero_pos: int) -> void:
	if _current_level == null or hero_node == null:
		return
	var plant: Variant = _current_level.plants.get(hero_pos)
	if plant == null:
		return
	if plant.has_method("activate"):
		plant.activate(hero_node, _current_level)

# ---------------------------------------------------------------------------
# Signal Handlers
# ---------------------------------------------------------------------------

func _on_hero_moved(new_pos: int) -> void:
	# Camera follows hero — snap close for responsive feel
	if game_camera and tile_map:
		game_camera.set_target(tile_map.cell_to_world(new_pos))
	# Step sound
	if AudioManager:
		AudioManager.play_sfx("step")

func _on_hero_moved_detailed(hero_node: Variant, new_pos: int) -> void:
	_check_item_pickup(hero_node, new_pos)
	_check_plant_activation(hero_node, new_pos)
	if _is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_move_world_event_payload("hero_moved", hero_node, new_pos))
	_queue_online_snapshot_sync(true)
	var focused_hero: Variant = _get_focused_hero()
	if focused_hero != hero_node:
		return
	_on_hero_moved(new_pos)

func _on_mob_moved_detailed(mob_node: Variant, new_pos: int) -> void:
	if _is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_move_world_event_payload("mob_moved", mob_node, new_pos))
	_queue_online_snapshot_sync()

func _on_local_hero_changed(hero_node: Node, _hero_index: int) -> void:
	EnvironmentFeedbackCoordinator.on_local_hero_changed(self, hero_node, _hero_index)

func _on_mob_defeated(mob_pos: int, _mob_name: String, _mob_id: String) -> void:
	SceneFeedbackCoordinator.on_mob_defeated(self, mob_pos, _mob_name, _mob_id)
	return

	# Particle burst at death location
	if effect_manager:
		effect_manager.particle_burst(mob_pos, Color(0.8, 0.2, 0.1), 6)
	# Hit sound
	if AudioManager:
		AudioManager.play_sfx("hit")
	if _is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_mob_defeated_world_event_payload(mob_pos, _mob_name, _mob_id))

func _on_item_picked_up(_item_name: String) -> void:
	EnvironmentFeedbackCoordinator.on_item_picked_up(self, _item_name)

func _on_door_opened(pos: int) -> void:
	EnvironmentFeedbackCoordinator.on_door_opened(self, pos)

func _on_hero_damaged(amount: int, _source: Variant) -> void:
	SceneFeedbackCoordinator.on_hero_damaged(self, amount, _source)
	return

	var hero: Variant = _get_focused_hero()
	# Interrupt auto-walk on damage
	_cancel_auto_walk()
	if hero and hero.has_method("interrupt"):
		hero.interrupt()
	# Camera shake on damage
	if game_camera:
		var intensity: float = clampf(float(amount) / 10.0, 1.0, 5.0)
		game_camera.shake(intensity, 0.2)
	# Damage number
	if effect_manager and hero:
		effect_manager.show_damage(hero.pos, amount)
	# Audio — hit sound + health warnings matching original SPD
	if AudioManager:
		AudioManager.play_sfx("hit")
		# Health warning SFX (original plays health_warn < 50%, health_critical < 25%)
		if hero and hero.get("hp") != null and hero.get("ht") != null:
			var hp: int = hero.hp
			var ht: int = hero.ht
			if ht > 0:
				var hp_ratio: float = float(hp) / float(ht)
				if hp_ratio < 0.25:
					AudioManager.play_sfx("health_critical")
				elif hp_ratio < 0.5:
					AudioManager.play_sfx("health_warn")

func _on_hero_damaged_detailed(hero_node: Variant, amount: int, source: Variant) -> void:
	SceneFeedbackCoordinator.on_hero_damaged_detailed(self, hero_node, amount, source)
	return

	var focused_hero: Variant = _get_focused_hero()
	if focused_hero != hero_node:
		return
	_on_hero_damaged(amount, source)
	if source is Buff:
		OnlineEventCodec.show_status_effect_feedback(effect_manager, hero_node.pos, str((source as Buff).buff_id))

func _on_status_effect_applied(target: Variant, effect_id: String) -> void:
	SceneFeedbackCoordinator.on_status_effect_applied(self, target, effect_id)
	return

	if target == null or not is_instance_valid(target):
		return
	var normalized_effect: String = effect_id.to_lower()
	var target_pos: int = int(ConstantsData.get_prop(target, "pos", -1))
	if target_pos < 0:
		return
	var feedback: Dictionary = OnlineEventCodec.get_status_effect_feedback(normalized_effect)
	if feedback.is_empty():
		return
	OnlineEventCodec.show_status_effect_feedback(effect_manager, target_pos, normalized_effect)
	if _is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_status_effect_world_event_payload(target_pos, normalized_effect))

func _find_best_spectate_hero() -> Variant:
	if GameManager == null or not GameManager.has_method("get_living_heroes"):
		return null
	var living: Array[Node] = GameManager.get_living_heroes()
	if living.is_empty():
		return null
	var local_spectate_hero: Variant = OnlineEventCodec.choose_local_spectate_hero(NetworkManager, living)
	if local_spectate_hero != null:
		return local_spectate_hero
	return living[0]

func _handle_party_hero_death(hero_node: Variant) -> void:
	RunTransitionCoordinator.handle_party_hero_death(self, hero_node)

func _on_hero_died() -> void:
	RunTransitionCoordinator.handle_hero_died(self)

func _on_hero_died_detailed(hero_node: Variant) -> void:
	RunTransitionCoordinator.handle_hero_died_detailed(self, hero_node)

func _transition_to_death() -> void:
	RunTransitionCoordinator.transition_to_death(self)

func _on_mob_revealed(mob: Variant) -> void:
	# A previously hidden mob (mimic, sleeping mob) was revealed — add its sprite
	if mob is Object and mob.get("is_alive") == true:
		_spawn_single_mob_sprite(mob)
		if _is_online_host():
			OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_mob_revealed_world_event_payload(mob))

func _on_mob_damaged(mob_pos: int, amount: int) -> void:
	SceneFeedbackCoordinator.on_mob_damaged(self, mob_pos, amount)
	return

	# Show floating damage number over the mob
	if effect_manager:
		effect_manager.show_damage(mob_pos, amount)
	_queue_online_snapshot_sync(true)

func _on_hero_attack_missed(mob_pos: int) -> void:
	SceneFeedbackCoordinator.on_hero_attack_missed(self, mob_pos)
	return

	# Show "0" over the mob when attack does no damage (dodge or absorbed)
	if effect_manager:
		effect_manager.show_status(mob_pos, "0", Color(0.7, 0.7, 0.7))
	# Miss whoosh sound
	if AudioManager:
		AudioManager.play_sfx("miss")
	if _is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "hero_attack_missed", "pos": mob_pos})

func _on_gold_collected(_amount: int, _total: int) -> void:
	if AudioManager:
		AudioManager.play_sfx("gold")

func _on_toolbar_wait() -> void:
	if _awaiting_hero_input:
		_submit_hero_action({"type": "wait"})

func _on_toolbar_search() -> void:
	if _awaiting_hero_input:
		_submit_hero_action({"type": "search"})

func _on_request_hero_action(action: Dictionary) -> void:
	if action.is_empty():
		return
	_submit_hero_action(action)

func _on_round_completed(_round_number: int) -> void:
	SceneFeedbackCoordinator.on_round_completed(self, _round_number)
	return

	if _current_level == null:
		return
	if _current_level.has_method("tick_pending_bombs"):
		var detonated: bool = _current_level.tick_pending_bombs()
		if detonated:
			refresh_after_turn()
	_queue_online_snapshot_sync()

func _on_trap_triggered(_pos: int, _trap_name: String) -> void:
	SceneFeedbackCoordinator.on_trap_triggered(self, _pos, _trap_name)
	return

	if AudioManager:
		AudioManager.play_sfx("trap")
	if _current_level != null:
		if tile_map:
			tile_map.level = _current_level
			tile_map.render_changed()
		var hero: Variant = _get_focused_hero()
		if GameManager and hero and _current_level.has_method("update_fov"):
			var view_distance: int = hero.get_view_distance() if hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
			_current_level.update_fov(hero.pos, view_distance)
		if fog_of_war:
			fog_of_war.update_visibility()
		_update_entity_visibility()
	if _is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "trap_triggered", "pos": _pos, "trap_name": _trap_name})
	_queue_online_snapshot_sync(true)

func _on_item_used_sfx(item_name: String) -> void:
	EnvironmentFeedbackCoordinator.on_item_used_sfx(item_name)

func _on_grass_trampled_sfx(_pos: int) -> void:
	EnvironmentFeedbackCoordinator.on_grass_trampled()

func _on_seed_planted(pos: int, plant_type: String) -> void:
	EnvironmentFeedbackCoordinator.on_seed_planted(self, pos, plant_type)

func _on_plant_activated_vfx(pos: int, plant_name: String) -> void:
	EnvironmentFeedbackCoordinator.on_plant_activated_vfx(self, pos, plant_name)

func _plant_color_for(plant_name: String) -> Color:
	return EnvironmentFeedbackCoordinator.plant_color_for(plant_name)

func _on_badge_unlocked_sfx(_badge_id: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("badge")

func _on_item_equipped_sfx(_item_name: String, _slot: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("click")
	_refresh_hero_equipment_visuals()

func _on_item_unequipped_visuals(_item_name: String, _slot: String) -> void:
	_refresh_hero_equipment_visuals()

func _refresh_hero_equipment_visuals() -> void:
	if GameManager == null:
		return
	for hero_node: Variant in GameManager.heroes:
		if hero_node == null or not is_instance_valid(hero_node):
			continue
		var hero_key: int = int(ConstantsData.get_prop(hero_node, "actor_id", -1))
		if hero_key < 0:
			continue
		var hero_sprite: Variant = _hero_sprites.get(hero_key)
		if hero_sprite == null or not is_instance_valid(hero_sprite):
			continue
		_apply_hero_equipment_visuals(hero_sprite, hero_node)

func _on_enchantment_proc(enchant_id: String, attacker_pos: int, defender_pos: int) -> void:
	if effect_manager == null:
		return
	match enchant_id:
		"blazing":
			effect_manager.particle_burst(defender_pos, Color(1.0, 0.45, 0.1), 10)
			effect_manager.ring_effect(defender_pos, Color(1.0, 0.3, 0.0, 0.6), 24.0, 0.4)
		"chilling":
			effect_manager.particle_burst(defender_pos, Color(0.4, 0.75, 1.0), 8)
			effect_manager.ring_effect(defender_pos, Color(0.5, 0.8, 1.0, 0.5), 20.0, 0.5)
		"shocking":
			effect_manager.lightning(attacker_pos, defender_pos, Color(0.9, 0.9, 0.2))
		"lucky":
			effect_manager.show_status(defender_pos, "Lucky!", Color(0.2, 0.9, 0.3))
			effect_manager.particle_burst(defender_pos, Color(0.2, 0.9, 0.3), 6)
		"grim":
			effect_manager.screen_flash(Color(0.1, 0.0, 0.0, 0.6), 0.4)
			effect_manager.particle_burst(defender_pos, Color(0.15, 0.15, 0.15), 12)
			effect_manager.ring_effect(defender_pos, Color(0.3, 0.0, 0.3, 0.7), 32.0, 0.6)
		"vampiric":
			effect_manager.shoot_projectile(defender_pos, attacker_pos, Color(0.8, 0.0, 0.0), 200.0)
			effect_manager.show_heal(attacker_pos, 0)  # Visual only, actual heal already applied
		"elastic":
			effect_manager.particle_burst(defender_pos, Color(0.6, 0.85, 0.6), 6)
			effect_manager.show_status(defender_pos, "Knockback!", Color(0.6, 0.85, 0.6))

func _on_glyph_proc(glyph_id: String, wearer_pos: int, attacker_pos: int) -> void:
	if effect_manager == null:
		return
	match glyph_id:
		"obfuscation":
			effect_manager.ring_effect(wearer_pos, Color(0.5, 0.5, 0.8, 0.5), 20.0, 0.4)
		"swiftness":
			effect_manager.particle_burst(wearer_pos, Color(0.9, 0.9, 0.3), 4)
		"viscosity":
			effect_manager.show_status(wearer_pos, "Deferred!", Color(0.6, 0.3, 0.6))
		"stone":
			effect_manager.ring_effect(wearer_pos, Color(0.6, 0.6, 0.6, 0.6), 16.0, 0.3)
		"repulsion":
			effect_manager.shoot_projectile(wearer_pos, attacker_pos, Color(0.7, 0.7, 1.0), 250.0)
		"affection":
			effect_manager.particle_burst(attacker_pos, Color(1.0, 0.4, 0.6), 6)
			effect_manager.show_status(attacker_pos, "Charmed!", Color(1.0, 0.4, 0.6))
		"anti_magic":
			effect_manager.ring_effect(wearer_pos, Color(0.3, 0.8, 0.3, 0.5), 24.0, 0.3)
		"thorns":
			effect_manager.shoot_projectile(wearer_pos, attacker_pos, Color(0.8, 0.2, 0.2), 200.0)
		"potential":
			effect_manager.lightning(wearer_pos, attacker_pos, Color(0.5, 0.5, 1.0))
		"brimstone":
			effect_manager.particle_burst(wearer_pos, Color(1.0, 0.3, 0.0), 8)
		"flow":
			effect_manager.particle_burst(wearer_pos, Color(0.3, 0.5, 1.0), 6)

# ---------------------------------------------------------------------------
# Level Transitions (Stairs)
# ---------------------------------------------------------------------------

## Handle descending to the next depth via stairs down.
func _handle_descend() -> void:
	FloorTransitionCoordinator.handle_descend(self)

## Handle ascending to the previous depth via stairs up.
func _handle_ascend() -> void:
	FloorTransitionCoordinator.handle_ascend(self)

func _party_ready_for_stairs(stair_pos: int, failure_message: String) -> bool:
	return FloorTransitionCoordinator.party_ready_for_stairs(self, stair_pos, failure_message)

func _notify_party_floor_change() -> void:
	FloorTransitionCoordinator.notify_party_floor_change(self)

## Transition to the LoadingScene for level generation.
func _transition_to_loading(transition_type: String = "descend") -> void:
	FloorTransitionCoordinator.transition_to_loading(self, transition_type)

## Transition to the victory scene (Amulet of Yendor).
func _transition_to_victory() -> void:
	RunTransitionCoordinator.transition_to_victory(self)

# ---------------------------------------------------------------------------
# Actor Management for Scene Transitions
# ---------------------------------------------------------------------------

## Detach persistent actors (hero) from this scene before freeing it.
## Without this, queue_free() would also free the hero Node, which
## must persist across level transitions.
func _detach_persistent_actors() -> void:
	# Detach hero(es) - they persist across levels
	if GameManager.hero is Node and is_instance_valid(GameManager.hero):
		if GameManager.hero.get_parent() == self:
			remove_child(GameManager.hero)
	for h: Variant in GameManager.heroes:
		if h is Node and h != GameManager.hero and is_instance_valid(h):
			if (h as Node).get_parent() == self:
				remove_child(h as Node)
	# Mobs don't need detaching - GameManager._cache_current_level() frees them

# ---------------------------------------------------------------------------
# Auto-Walk System
# ---------------------------------------------------------------------------

## Start auto-walking toward a target cell. The hero will move one step per
## turn until reaching the destination or being interrupted.
func _start_auto_walk(target: int) -> void:
	AutoWalkCoordinator.start(self, target)

## Cancel auto-walk (enemy spotted, damage taken, manual input, etc.).
func _cancel_auto_walk() -> void:
	AutoWalkCoordinator.cancel(self)

## Process one auto-walk step. Called from _process when it's the hero's turn
## and auto-walk is active.
func _process_auto_walk() -> void:
	AutoWalkCoordinator.process_step(self, AUTO_WALK_STEP_DELAY)

## Return a dictionary of currently visible mob positions (for interrupt detection).
func _get_visible_mob_positions() -> Dictionary[int, bool]:
	return AutoWalkCoordinator.get_visible_mob_positions(self)

func _interrupt_rest_if_needed() -> void:
	AutoWalkCoordinator.interrupt_rest_if_needed(self)

# ---------------------------------------------------------------------------
# Targeting Mode
# ---------------------------------------------------------------------------

## Enter targeting mode via signal from inventory/item windows.
func _on_enter_targeting(item: Variant, max_range: int, callback: Callable) -> void:
	TargetingCoordinator.enter(self, item, max_range, callback)

## Cancel targeting mode via signal.
func _on_cancel_targeting() -> void:
	TargetingCoordinator.cancel(self)

## Cancel targeting and inform the player.
func _cancel_targeting_mode() -> void:
	TargetingCoordinator.cancel(self)

## Resolve targeting — the player clicked a cell while in targeting mode.
func _resolve_targeting(cell: int) -> void:
	TargetingCoordinator.resolve(self, cell)
	return

	if not _targeting_active:
		return

	var hero: Variant = _get_input_hero()
	if hero == null:
		_cancel_targeting_mode()
		return

	# Range check
	if _targeting_max_range > 0:
		var dist: int = hero.distance_to(cell) if hero.has_method("distance_to") else 999
		if dist > _targeting_max_range:
			if MessageLog:
				MessageLog.add_warning("Out of range!")
			return

	# Visibility check — can't target unseen cells
	if _current_level and cell >= 0 and cell < _current_level.visible.size():
		if not _current_level.visible[cell]:
			if MessageLog:
				MessageLog.add_warning("You can't see that cell!")
			return

	# Save and clear targeting state BEFORE calling callback (prevents re-entrancy)
	var callback: Callable = _targeting_callback
	var item: Variant = _targeting_item
	_targeting_active = false
	_targeting_item = null
	_targeting_max_range = 0
	_targeting_callback = Callable()

	# Execute the callback
	if item != null and (
		(item is Object and item.get("item_id") == "spirit_bow") or
		(item != null and item.has_method("proc")) or
		(item != null and item.has_method("explode")) or
		(item != null and item.has_method("zap"))
	):
		var acting_hero: Variant = _get_input_hero()
		var hero_sprite: Variant = _hero_sprites.get(acting_hero.actor_id) if acting_hero != null else null
		if hero_sprite != null:
			hero_sprite.play_attack(cell)
	if callback.is_valid():
		callback.call(cell)
	call_deferred("refresh_after_turn")
