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
var _is_continue: bool = false
var _transition_type: String = "descend"  # "descend" or "ascend"

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
	# Read metadata set by the calling scene
	if has_meta("chosen_class"):
		_chosen_class = get_meta("chosen_class") as int
	if has_meta("is_continue"):
		_is_continue = get_meta("is_continue") as bool
	if has_meta("transition_type"):
		_transition_type = get_meta("transition_type") as String

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
		# Just generate the level for current depth
		_generate_current_level()
	else:
		# New game flow — free the old hero to prevent memory leak
		if GameManager.hero != null and GameManager.hero is Node:
			GameManager.hero.free()
			GameManager.hero = null
			GameManager.heroes.clear()

		# Reset quest state for the new run
		QuestHandler.reset()

		GameManager.new_game(_chosen_class)

		# Create hero
		var hero_scene: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
		if hero_scene:
			var hero: Node = hero_scene.new()
			if hero.has_method("init_class"):
				hero.init_class(GameManager.hero_class)
			# Give starting items based on class
			if hero.has_method("give_starting_items"):
				hero.give_starting_items()
			hero.set("pos", -1)
			GameManager.hero = hero
			GameManager.heroes = [hero]

		_generate_current_level()

	# Play descend sound for level transitions
	if AudioManager:
		AudioManager.play_sfx("descend")

	_generation_complete = true

func _generate_current_level() -> void:
	var depth: int = GameManager.depth
	var level: Level = null

	# If current_level is already loaded (e.g. from a save file) and matches
	# the target depth, use it directly instead of regenerating.
	if GameManager.current_level != null and GameManager.current_level.depth == depth:
		if GameManager.current_level.map.size() == Level.LEN:
			level = GameManager.current_level

	# Check if we have a cached version of this level (backtracking)
	if level == null and GameManager.has_cached_level(depth):
		var cached_data: Variant = GameManager.get_cached_level(depth)
		if cached_data is Dictionary:
			level = RegularLevel.new()
			level.deserialize(cached_data)

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

		# Spawn quest NPCs and shopkeepers
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

		# Place hero at the correct staircase:
		# - Descending (or new game): hero appears at entrance (stairs up)
		# - Ascending: hero appears at exit (stairs down, where they came from)
		if GameManager.hero:
			if _transition_type == "ascend" and level.exit_pos >= 0:
				GameManager.hero.set("pos", level.exit_pos)
			elif level.entrance >= 0:
				GameManager.hero.set("pos", level.entrance)
	else:
		# Level already loaded from save — just ensure hero references are set
		if GameManager.hero:
			GameManager.hero.level = level
		for h in GameManager.heroes:
			if h is Node:
				h.level = level

# ---------------------------------------------------------------------------
# Transition
# ---------------------------------------------------------------------------

func _transition_to_game() -> void:
	# --- Register actors with TurnManager ---
	TurnManager.clear_actors()

	# Register hero(es)
	if GameManager.hero:
		GameManager.hero.active = false
		GameManager.hero.activate()
	for h in GameManager.heroes:
		if h is Node and h != GameManager.hero:
			h.active = false
			h.activate()

	# Register mobs
	var level: Level = GameManager.current_level
	if level:
		for mob: Variant in level.mobs:
			if mob is Node:
				mob.active = false
				mob.activate()

	# --- Create and show the GameScene ---
	var game_script: GDScript = load("res://src/scenes/game_scene.gd") as GDScript
	if game_script:
		var game_scene: Variant = game_script.new()
		game_scene.name = "GameScene"
		get_tree().root.add_child(game_scene)

		# Load level visuals
		var region: int = ConstantsData.region_for_depth(GameManager.depth)
		game_scene.load_level(level, region)

		# Start the turn loop
		TurnManager.process_until_hero()

	queue_free()
