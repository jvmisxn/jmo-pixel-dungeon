class_name LoadingScene
extends Control
## Brief loading/transition screen shown between level generations.
## Uses original SPD region splash art as background.
## Handles initial game setup: creates hero, calls GameManager.new_game(), generates level.
## Also used when continuing a saved game.

# --- State ---
var _dots_count: int = 0
var _dot_timer: float = 0.0
var _generation_started: bool = false
var _generation_complete: bool = false
var _transition_delay: float = 0.0
var _chosen_class: int = ConstantsData.HeroClass.WARRIOR
var _party_classes: Array[int] = []
var _player_infos: Array[Dictionary] = []
var _run_seed: int = -1
var _is_continue: bool = false
var _transition_type: String = "descend"  # "descend" or "ascend"
var _autosave_after_generation: bool = false
var _fall_actor_id: int = -1
var _fall_into_pit: bool = false

# --- UI References ---
var _depth_label: Label = null
var _region_label: Label = null
var _flavor_label: Label = null
var _dots_label: Label = null

# --- Constants ---
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.3)

# Region splash art paths (800x450 JPGs from original SPD)
const REGION_SPLASHES: Dictionary = {
	ConstantsData.Region.SEWERS: "res://assets/spd/splashes/sewers.jpg",
	ConstantsData.Region.PRISON: "res://assets/spd/splashes/prison.jpg",
	ConstantsData.Region.CAVES:  "res://assets/spd/splashes/caves.jpg",
	ConstantsData.Region.CITY:   "res://assets/spd/splashes/city.jpg",
	ConstantsData.Region.HALLS:  "res://assets/spd/splashes/halls.jpg",
}

# --- Flavor Text ---
const REGION_FLAVOR: Dictionary = {
	"Sewers": "Dark waters flow beneath the city...",
	"Prison": "The clanking of chains echoes endlessly...",
	"Caves": "Crystals gleam in the oppressive darkness...",
	"Dwarf City": "Ancient halls of a forgotten civilization...",
	"Demon Halls": "The air burns with infernal heat...",
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if NetworkManager and NetworkManager.has_signal("disconnected"):
		NetworkManager.disconnected.connect(_on_network_disconnected)
	# Read metadata set by the calling scene
	if has_meta("chosen_class"):
		_chosen_class = get_meta("chosen_class") as int
	if has_meta("party_classes"):
		var raw_party: Variant = get_meta("party_classes")
		if raw_party is Array:
			for class_id: Variant in raw_party:
				_party_classes.append(int(class_id))
	if has_meta("player_infos"):
		var raw_players: Variant = get_meta("player_infos")
		if raw_players is Array:
			for entry: Variant in raw_players:
				if entry is Dictionary:
					_player_infos.append((entry as Dictionary).duplicate(true))
	if has_meta("run_seed"):
		_run_seed = int(get_meta("run_seed"))
	if has_meta("is_continue"):
		_is_continue = get_meta("is_continue") as bool
	if has_meta("transition_type"):
		_transition_type = get_meta("transition_type") as String
		_autosave_after_generation = _is_continue
	if has_meta("fall_actor_id"):
		_fall_actor_id = int(get_meta("fall_actor_id"))
	if has_meta("fall_into_pit"):
		_fall_into_pit = bool(get_meta("fall_into_pit"))

	_build_ui()
	# Defer generation to next frame so UI is visible
	_generation_started = false

func _process(delta: float) -> void:
	_dot_timer += delta

	# Animate loading dots
	if _dot_timer >= 0.4:
		_dot_timer = 0.0
		_dots_count = (_dots_count + 1) % 4
		_dots_label.text = ".".repeat(_dots_count)

	# Start generation on second frame
	if not _generation_started:
		_generation_started = true
		call_deferred("_perform_generation")
		return

	# After generation, wait briefly then transition
	if _generation_complete:
		_transition_delay += delta
		if _transition_delay >= 0.5:
			_transition_to_game()

func _on_network_disconnected(reason: String) -> void:
	if reason != "Disconnected from host.":
		return
	if MessageLog:
		MessageLog.add_warning("Lost connection to host during loading.")
	var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
	if title_script:
		SceneManager.go_to(title_script, "TitleScene")

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var depth: int = GameManager.depth if _is_continue else 1
	var region: ConstantsData.Region = ConstantsData.region_for_depth(depth)
	var region_name: String = ConstantsData.region_name(region)

	# --- Dark background base ---
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# --- Region splash art background ---
	var splash_path: String = REGION_SPLASHES.get(region, REGION_SPLASHES[ConstantsData.Region.SEWERS])
	if ResourceLoader.exists(splash_path):
		var splash_tex: Texture2D = load(splash_path) as Texture2D
		if splash_tex:
			var splash_rect: TextureRect = TextureRect.new()
			splash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			splash_rect.texture = splash_tex
			splash_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			splash_rect.modulate = Color(0.5, 0.5, 0.5, 0.7)
			splash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(splash_rect)

	# --- Dark vignette overlay for text readability ---
	var vignette: ColorRect = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float vignette = smoothstep(0.2, 0.9, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * 0.7);
}
"""
	shader_material.shader = shader
	vignette.material = shader_material
	add_child(vignette)

	# --- Centered text container ---
	var text_container: VBoxContainer = VBoxContainer.new()
	text_container.add_theme_constant_override("separation", 8)
	text_container.anchor_left = 0.5
	text_container.anchor_right = 0.5
	text_container.anchor_top = 0.5
	text_container.anchor_bottom = 0.5
	text_container.offset_left = -200
	text_container.offset_right = 200
	text_container.offset_top = -80
	text_container.offset_bottom = 80
	add_child(text_container)

	# Depth label
	_depth_label = Label.new()
	_depth_label.text = "Depth %d" % depth
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_label.add_theme_font_size_override("font_size", 32)
	_depth_label.add_theme_color_override("font_color", GOLD_COLOR)
	text_container.add_child(_depth_label)

	# Region label
	_region_label = Label.new()
	_region_label.text = region_name
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_font_size_override("font_size", 20)
	_region_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	text_container.add_child(_region_label)

	# Flavor text
	_flavor_label = Label.new()
	_flavor_label.text = REGION_FLAVOR.get(region_name, "Deeper into the dungeon...")
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.add_theme_font_size_override("font_size", 14)
	_flavor_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	text_container.add_child(_flavor_label)

	# Loading dots
	_dots_label = Label.new()
	_dots_label.text = "."
	_dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots_label.add_theme_font_size_override("font_size", 28)
	_dots_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	text_container.add_child(_dots_label)

# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

func _perform_generation() -> void:
	if _is_continue:
		# For continue, the GameManager already has state loaded
		if _party_classes.is_empty() and GameManager and GameManager.has_method("get_party_classes"):
			_party_classes = GameManager.get_party_classes()
		# Just generate the level for current depth
		_generate_current_level()
	else:
		# New game flow
		# Reset quest state for the new run
		QuestHandler.reset()

		GameManager.new_game(_chosen_class, _run_seed)
		if _party_classes.is_empty():
			_party_classes = [_chosen_class]
		GameManager.set_party_classes(_party_classes)

		# Create party heroes
		GameManager.replace_party(GameManager.create_party_heroes())
		_apply_online_party_assignments()

		_generate_current_level()

	# Play descend sound for level transitions
	if AudioManager:
		AudioManager.play_sfx("descend")

	if _autosave_after_generation and SaveManager and SaveManager.has_method("autosave_if_active"):
		SaveManager.autosave_if_active()

	_generation_complete = true

func _generate_current_level() -> void:
	var depth: int = GameManager.depth
	var level: Level = null
	var reused_existing_state: bool = false

	# If current_level is already loaded (e.g. from a save file) and matches
	# the target depth, use it directly instead of regenerating.
	if GameManager.current_level != null and GameManager.current_level.depth == depth:
		if GameManager.current_level.map.size() == Level.LEN:
			level = GameManager.current_level
			reused_existing_state = true

	# Check if we have a cached version of this level (backtracking)
	if level == null and GameManager.has_cached_level(depth):
		var cached_data: Variant = GameManager.get_cached_level(depth)
		if cached_data is Dictionary:
			level = LevelFactory.instantiate_for_depth(depth)
			level.deserialize(cached_data)
			reused_existing_state = true

	# Generate a fresh level using LevelFactory
	if level == null:
		level = LevelFactory.create_for_depth(depth)

	if level != GameManager.current_level:
		GameManager.current_level = level

		# Assign level reference to hero(es) so Actor.level is set
		if GameManager.hero:
			GameManager.hero.level = level
		for h in GameManager.heroes:
			if h is Node:
				h.level = level

		# Spawn quest NPCs and shopkeepers only for freshly generated levels.
		if not reused_existing_state:
			if QuestHandler.is_quest_depth(depth):
				var npc: Variant = QuestHandler.spawn_quest_npc(level, depth)
				if npc != null and npc is Object:
					var npc_pos: int = QuestHandler._find_spawn_pos(level)
					if npc_pos >= 0:
						npc.set("pos", npc_pos)
						level.add_mob(npc)

			if QuestHandler.is_shop_depth(depth):
				var keeper: Shopkeeper = QuestHandler.spawn_shopkeeper(level, depth)
				if keeper != null:
					var shop_pos: int = QuestHandler._find_spawn_pos(level)
					if shop_pos >= 0:
						keeper.pos = shop_pos
						level.add_mob(keeper)

		# Place party at the correct staircase:
		# - Descending (or new game): appear at entrance (stairs up)
		# - Ascending: appear at exit (stairs down, where they came from)
		var anchor_pos: int = _landing_anchor_for_transition(level)
		_assign_party_positions(level, anchor_pos)
		if _transition_type == "fall":
			_apply_fall_arrival_effects(level)
	else:
		# Level already loaded from save — just ensure hero references are set
		if GameManager.hero:
			GameManager.hero.level = level
		for h in GameManager.heroes:
			if h is Node:
				h.level = level
		if _transition_type == "fall":
			_apply_fall_arrival_effects(level)

func _landing_anchor_for_transition(level: Level) -> int:
	if level == null:
		return -1
	if _transition_type == "ascend" and level.exit_pos >= 0:
		return level.exit_pos
	if _transition_type == "fall":
		if _fall_into_pit:
			var pit_landing: int = _pit_room_landing_cell(level)
			if pit_landing >= 0:
				return pit_landing
		var landing: int = level.random_passable_cell()
		if landing >= 0:
			return landing
	return level.entrance

func _pit_room_landing_cell(level: Level) -> int:
	if level == null:
		return -1
	for room: Room in level.rooms:
		if not room is PitRoom:
			continue
		var center: int = room.center()
		if _can_spawn_party_member(level, center, []):
			return center
		var candidates: Array[int] = room.interior_cells()
		candidates.sort_custom(func(a: int, b: int) -> bool:
			return _cell_distance(a, center) < _cell_distance(b, center)
		)
		for cell: int in candidates:
			if _can_spawn_party_member(level, cell, []):
				return cell
	return -1

func _cell_distance(a: int, b: int) -> int:
	var ax: int = ConstantsData.pos_to_x(a)
	var ay: int = ConstantsData.pos_to_y(a)
	var bx: int = ConstantsData.pos_to_x(b)
	var by: int = ConstantsData.pos_to_y(b)
	return maxi(absi(ax - bx), absi(ay - by))

func _apply_fall_arrival_effects(level: Level) -> void:
	var fallen_hero: Variant = _find_hero_by_actor_id(_fall_actor_id)
	if fallen_hero == null:
		fallen_hero = GameManager.get_primary_hero() if GameManager and GameManager.has_method("get_primary_hero") else GameManager.hero
	if fallen_hero != null:
		Chasm.apply_landing_damage(fallen_hero, level)

func _find_hero_by_actor_id(actor_id: int) -> Variant:
	if actor_id < 0 or GameManager == null:
		return null
	for hero_node: Variant in GameManager.heroes:
		if hero_node != null and is_instance_valid(hero_node) and int(hero_node.get("actor_id")) == actor_id:
			return hero_node
	return null

func _apply_online_party_assignments() -> void:
	if _player_infos.is_empty() or GameManager == null:
		return
	var local_peer_id: int = multiplayer.get_unique_id() if multiplayer != null and multiplayer.has_multiplayer_peer() else 1
	for idx: int in range(mini(GameManager.heroes.size(), _player_infos.size())):
		var hero_node: Variant = GameManager.heroes[idx]
		if hero_node == null or not (hero_node is Node):
			continue
		var player_info: Dictionary = _player_infos[idx]
		var player_name: String = str(player_info.get("name", "Player %d" % (idx + 1)))
		hero_node.set("hero_name", player_name)
		hero_node.set("owner_peer_id", int(player_info.get("peer_id", 1)))
		hero_node.set("hero_slot_index", idx)
		hero_node.name = player_name
		if int(player_info.get("peer_id", -1)) == local_peer_id and GameManager.has_method("set_local_hero_index"):
			GameManager.set_local_hero_index(idx)

func _assign_party_positions(level: Level, anchor_pos: int) -> void:
	if level == null or anchor_pos < 0:
		return
	var party: Array[Node] = GameManager.get_active_heroes() if GameManager and GameManager.has_method("get_active_heroes") else []
	if party.is_empty():
		return
	var spawn_positions: Array[int] = _find_party_spawn_positions(level, anchor_pos, party.size())
	for idx: int in range(mini(party.size(), spawn_positions.size())):
		party[idx].set("pos", spawn_positions[idx])

func _find_party_spawn_positions(level: Level, anchor_pos: int, party_size: int) -> Array[int]:
	var found: Array[int] = []
	var queue: Array[int] = [anchor_pos]
	var visited: Dictionary[int, bool] = {anchor_pos: true}
	while not queue.is_empty() and found.size() < party_size:
		var pos: int = queue.pop_front()
		if _can_spawn_party_member(level, pos, found):
			found.append(pos)
		for next_pos: int in _get_adjacent_spawn_cells(pos):
			if visited.has(next_pos):
				continue
			visited[next_pos] = true
			if level.passable[next_pos]:
				queue.append(next_pos)
	if found.is_empty():
		found.append(anchor_pos)
	return found

func _get_adjacent_spawn_cells(pos: int) -> Array[int]:
	var neighbors: Array[int] = []
	var x: int = ConstantsData.pos_to_x(pos)
	var y: int = ConstantsData.pos_to_y(pos)
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var nx: int = x + ox
			var ny: int = y + oy
			if nx < 0 or nx >= ConstantsData.WIDTH or ny < 0 or ny >= ConstantsData.HEIGHT:
				continue
			neighbors.append(ConstantsData.xy_to_pos(nx, ny))
	return neighbors

func _can_spawn_party_member(level: Level, pos: int, reserved_positions: Array[int]) -> bool:
	if not ConstantsData.is_valid_pos(pos):
		return false
	if reserved_positions.has(pos):
		return false
	if not level.passable[pos] and pos != level.entrance and pos != level.exit_pos:
		return false
	if level.has_method("find_char_at") and level.find_char_at(pos) != null:
		return false
	return true

# ---------------------------------------------------------------------------
# Transition
# ---------------------------------------------------------------------------

func _transition_to_game() -> void:
	# --- Register actors with TurnManager ---
	TurnManager.clear_actors()
	var online_client: bool = NetworkManager != null and NetworkManager.has_method("is_client") and NetworkManager.is_client()
	var level: Level = GameManager.current_level

	if not online_client:
		# Register hero(es)
		if GameManager.hero:
			GameManager.hero.active = false
			GameManager.hero.activate()
		for h in GameManager.heroes:
			if h is Node and h != GameManager.hero:
				h.active = false
				h.activate()

		# Register mobs
		if level:
			for mob: Variant in level.mobs:
				if mob is Node:
					mob.active = false
					mob.activate()
			if level.has_method("activate_respawner"):
				level.activate_respawner()

		# All actors for the restored level are registered again — re-link the
		# saved scheduler timeline so cooldowns/turn counters survive the reload.
		if TurnManager.has_method("apply_pending_schedule"):
			TurnManager.apply_pending_schedule()

	# --- Create and show the GameScene ---
	var game_script: GDScript = load("res://src/scenes/game_scene.gd") as GDScript
	if game_script:
		var game_scene: Variant = game_script.new()
		game_scene.name = "GameScene"
		game_scene._pending_level = level
		game_scene._pending_region = ConstantsData.region_for_depth(GameManager.depth)
		SceneManager.go_to_node(game_scene)
