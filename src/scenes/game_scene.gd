class_name GameScene
extends Node2D
## Main gameplay scene. Assembles the visual layers (tiles, fog, sprites, effects),
## handles input (click to move/attack, keyboard), and bridges game logic to visuals.
## Orchestrates level loading, hero placement, and the turn loop.

# --- Layer References ---
var tile_map: TileMapManager = null
var fog_of_war: FogOfWar = null
var effect_manager: EffectManager = null
var game_camera: GameCamera = null

# --- Sprite Tracking ---
## Hero sprite instances. Key: actor_id (int) -> HeroSprite
var _hero_sprites: Dictionary[int, HeroSprite] = {}
## Mob sprite instances. Key: actor_id (int or mob ref) -> MobSprite
var _mob_sprites: Dictionary[int, MobSprite] = {}
## Item sprites on the ground. Key: pos (int) -> ItemSprite
var _item_sprites: Dictionary[int, ItemSprite] = {}
## Armed bomb sprites on the ground. Key: pos (int) -> ItemSprite
var _armed_bomb_sprites: Dictionary[int, ItemSprite] = {}

# --- Sprite Layers (Node2D containers for z-ordering) ---
var _entity_layer: Node2D = null

# --- Input State ---
var _awaiting_hero_input: bool = false
var _game_ended: bool = false  # Set on hero death/victory to stop _process loop
var _hover_cell: int = -1

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
var _hud: HUD = null

# --- Level Reference ---
var _current_level: Level = null

# --- Pending level load (set before _ready, consumed in _ready) ---
var _pending_level: Level = null
var _pending_region: int = -1

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
		TurnManager.process_until_hero()

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

	# Sync with TurnManager — if it's waiting for input, we should be too.
	# Don't interfere while the async mob-processing coroutine is running.
	if not _awaiting_hero_input and TurnManager and not TurnManager.processing_mobs:
		if TurnManager.waiting_for_input:
			# TurnManager is already waiting (e.g. from level load) — accept input
			_awaiting_hero_input = true
		else:
			# Process AI turns until hero's turn comes
			TurnManager.process_until_hero()
			if TurnManager.waiting_for_input:
				_awaiting_hero_input = true

	# --- Auto-walk: if hero's turn and auto-walking, take the next step ---
	if _awaiting_hero_input and _auto_walk_target >= 0 and GameManager.hero:
		# Wait for the step animation to finish before taking the next step
		if _auto_walk_cooldown > 0.0:
			_auto_walk_cooldown -= _delta
		else:
			_process_auto_walk()

func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_hero_input:
		return

	# --- Mouse Click ---
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
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
		if key.pressed and not key.echo:
			var handled: bool = _handle_key_input(key.keycode)
			if handled:
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load and display a level. Called by game flow when entering a new depth.
func load_level(level: Level, region: int) -> void:
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

	# Camera bounds
	game_camera.set_map_bounds(tile_map.get_map_pixel_size())

	# Spawn hero sprites
	_clear_entity_sprites()
	_spawn_hero_sprites()
	_spawn_mob_sprites()
	_spawn_item_sprites()
	_refresh_armed_bomb_sprites()

	# Initial FOV from hero position
	if GameManager.hero:
		# Debug: log level state
		var non_wall: int = 0
		for i: int in range(Level.LEN):
			if level.map[i] != ConstantsData.Terrain.WALL:
				non_wall += 1
		if MessageLog:
			MessageLog.add("Level loaded: entrance=%d, exit=%d, hero=%d, non-wall=%d, mobs=%d" % [
				level.entrance, level.exit_pos, GameManager.hero.pos, non_wall, level.mobs.size()])

		var _vd: int = GameManager.hero.get_view_distance() if GameManager.hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		level.update_fov(GameManager.hero.pos, _vd)

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
		var hero_world: Vector2 = tile_map.cell_to_world(GameManager.hero.pos)
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
	if _current_level == null or GameManager.hero == null:
		return

	_ensure_mob_sprites()

	# Update FOV (use hero's actual view distance for Huntress bonus, MindVision, etc.)
	var _vd: int = GameManager.hero.get_view_distance() if GameManager.hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
	_current_level.update_fov(GameManager.hero.pos, _vd)
	fog_of_war.update_visibility()

	# Update terrain changes
	tile_map.render_changed()
	tile_map.update_tile_visibility()

	# Update entity visibility
	_update_entity_visibility()

	# Update camera target
	var hero_world: Vector2 = tile_map.cell_to_world(GameManager.hero.pos)
	game_camera.set_target(hero_world)

	# Check for dead mobs and remove their sprites
	_cleanup_dead_mobs()

	# Refresh item sprites
	_refresh_item_sprites()
	_refresh_armed_bomb_sprites()
	_interrupt_rest_if_needed()

## Called by TurnManager after each visible mob action (move, attack) so the
## player can see the mob act in real time. Updates the mob's sprite position,
## plays attack animation if it attacked the hero, and refreshes FOV/visibility.
func on_mob_action(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var actor_id: int = actor.get("actor_id") if actor.get("actor_id") != null else -1
	var sprite: MobSprite = _mob_sprites.get(actor_id) as MobSprite if actor_id >= 0 else null

	if sprite and is_instance_valid(sprite):
		var mob_pos: int = actor.get("pos") if actor.get("pos") != null else -1
		var action_name: String = str(actor.get("last_visible_action"))
		var action_target_pos: int = int(actor.get("last_visible_target_pos")) if actor.get("last_visible_target_pos") != null else -1
		# Sync sprite to mob's current logical position (animate move)
		if mob_pos >= 0 and mob_pos != sprite.cell_pos:
			sprite.move_to(mob_pos)
		# Attack animation must use explicit action data; inferring from the
		# mob's current target after resolution is unreliable.
		if action_name == "attack" and action_target_pos >= 0:
			sprite.play_attack(action_target_pos)
		# Update HP bar
		if actor.get("hp") != null and actor.get("ht") != null:
			sprite.update_hp_bar(actor.hp, actor.ht)

	# Refresh FOV and visibility so the player sees the mob and terrain updates
	if _current_level and GameManager.hero:
		var _vd: int = GameManager.hero.get_view_distance() if GameManager.hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		_current_level.update_fov(GameManager.hero.pos, _vd)
		fog_of_war.update_visibility()
		_update_entity_visibility()
		_interrupt_rest_if_needed()


## Get the EffectManager for external systems to trigger effects.
func get_effects() -> EffectManager:
	return effect_manager

# ---------------------------------------------------------------------------
# Layer Setup
# ---------------------------------------------------------------------------

func _create_layers() -> void:
	# Tile map layer (z = -10)
	tile_map = TileMapManager.new()
	tile_map.name = "TileMap"
	add_child(tile_map)

	# Entity layer (z = 0, contains hero/mob/item sprites)
	_entity_layer = Node2D.new()
	_entity_layer.name = "EntityLayer"
	_entity_layer.z_index = 0
	add_child(_entity_layer)

	# Effect layer (z = 50)
	effect_manager = EffectManager.new()
	effect_manager.name = "EffectManager"
	add_child(effect_manager)

	# Fog of war layer (z = 100)
	fog_of_war = FogOfWar.new()
	fog_of_war.name = "FogOfWar"
	add_child(fog_of_war)

	# Camera
	game_camera = GameCamera.new()
	game_camera.name = "GameCamera"
	add_child(game_camera)
	game_camera.make_current()

	# HUD (CanvasLayer, renders above everything)
	_hud = HUD.new()
	_hud.name = "HUD"
	add_child(_hud)

func _connect_signals() -> void:
	if EventBus:
		EventBus.hero_moved.connect(_on_hero_moved)
		EventBus.mob_defeated.connect(_on_mob_defeated)
		EventBus.item_picked_up.connect(_on_item_picked_up)
		EventBus.door_opened.connect(_on_door_opened)
		EventBus.hero_damaged.connect(_on_hero_damaged)
		EventBus.hero_died.connect(_on_hero_died)
		if EventBus.has_signal("mob_revealed"):
			EventBus.mob_revealed.connect(_on_mob_revealed)
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
		if EventBus.has_signal("badge_unlocked"):
			EventBus.badge_unlocked.connect(_on_badge_unlocked_sfx)
		if EventBus.has_signal("item_equipped"):
			EventBus.item_equipped.connect(_on_item_equipped_sfx)

		if EventBus.has_signal("enter_targeting"):
			EventBus.enter_targeting.connect(_on_enter_targeting)
		if EventBus.has_signal("cancel_targeting"):
			EventBus.cancel_targeting.connect(_on_cancel_targeting)

	if TurnManager and not TurnManager.round_completed.is_connected(_on_round_completed):
		TurnManager.round_completed.connect(_on_round_completed)

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
		var sprite: HeroSprite = HeroSprite.new()
		sprite.setup_for_class(hero.hero_class)
		# Update armor visuals to match equipped armor tier
		if hero.belongings != null:
			var equipped_armor: Variant = hero.belongings.get_equipped_armor()
			if equipped_armor != null and equipped_armor.get("tier") != null:
				sprite.update_armor(equipped_armor.tier)
		sprite.place_at(hero.pos)
		sprite.character = hero
		_entity_layer.add_child(sprite)
		_hero_sprites[hero.actor_id] = sprite
		hero.sprite = sprite

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
		var item_sprite: ItemSprite = ItemSprite.new()
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

	var sprite: MobSprite = MobSprite.new()
	var mob_id: String = mob.get("mob_id") if mob.get("mob_id") else "rat"
	sprite.setup_for_mob(mob_id)
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
		var sprite: ItemSprite = ItemSprite.new()
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
	for sprite: Variant in _armed_bomb_sprites.values():
		if sprite is Node and is_instance_valid(sprite):
			sprite.queue_free()
	_armed_bomb_sprites.clear()

func _cleanup_dead_mobs() -> void:
	var to_remove: Array[int] = []
	for key: int in _mob_sprites.keys():
		var sprite: MobSprite = _mob_sprites[key]
		if sprite == null:
			continue  # Disguised mimic placeholder
		if not sprite is MobSprite:
			continue
		if not is_instance_valid(sprite.character):
			# Character was freed (died and call_deferred("free") ran)
			to_remove.append(key)
		elif sprite.character is Object:
			if sprite.character.get("is_alive") == false:
				sprite.play_death()
				to_remove.append(key)
	for key: Variant in to_remove:
		_mob_sprites.erase(key)

func _refresh_item_sprites() -> void:
	if _current_level == null:
		return
	# Remove sprites for picked-up items
	var valid_positions: Dictionary[int, bool] = {}
	for heap: Dictionary in _current_level.heaps:
		valid_positions[heap.get("pos", -1)] = true
	var to_remove: Array[int] = []
	for pos: int in _item_sprites.keys():
		if not valid_positions.has(pos):
			var sprite: ItemSprite = _item_sprites[pos]
			if is_instance_valid(sprite):
				sprite.play_pickup()
			to_remove.append(pos)
	for pos: int in to_remove:
		_item_sprites.erase(pos)
	# Add sprites for new items
	for heap: Dictionary in _current_level.heaps:
		var pos: int = heap.get("pos", -1)
		if pos >= 0 and not _item_sprites.has(pos):
			var sprite: ItemSprite = ItemSprite.new()
			sprite.setup_from_item(heap.get("item"))
			sprite.place_at(pos)
			sprite.play_drop()
			_entity_layer.add_child(sprite)
			_item_sprites[pos] = sprite

func _refresh_armed_bomb_sprites() -> void:
	if _current_level == null:
		return
	var valid_positions: Dictionary[int, bool] = {}
	for bomb_entry: Dictionary in _current_level.pending_bombs:
		var bomb_pos: int = bomb_entry.get("pos", -1)
		valid_positions[bomb_pos] = true
	var to_remove: Array[int] = []
	for pos: int in _armed_bomb_sprites.keys():
		if not valid_positions.has(pos):
			var stale_sprite: ItemSprite = _armed_bomb_sprites[pos]
			if is_instance_valid(stale_sprite):
				stale_sprite.play_pickup(0.15)
			to_remove.append(pos)
	for pos: int in to_remove:
		_armed_bomb_sprites.erase(pos)
	for bomb_entry: Dictionary in _current_level.pending_bombs:
		var bomb_pos: int = bomb_entry.get("pos", -1)
		if bomb_pos < 0 or _armed_bomb_sprites.has(bomb_pos):
			continue
		var bomb: Variant = bomb_entry.get("bomb")
		var sprite: ItemSprite = ItemSprite.new()
		if bomb is Object:
			sprite.setup_from_item(bomb)
		else:
			sprite.setup_manual(ConstantsData.ItemCategory.MISC, Color(0.8, 0.3, 0.2))
		sprite.place_at(bomb_pos)
		sprite.play_drop()
		_entity_layer.add_child(sprite)
		_armed_bomb_sprites[bomb_pos] = sprite
		if effect_manager:
			effect_manager.show_status(bomb_pos, "Fuse", Color(1.0, 0.7, 0.2))

func _update_entity_visibility() -> void:
	if _current_level == null:
		return
	# Hero sprites always visible (they're the player)
	# Mob sprites: sync position AND visibility after mob turns
	for key: Variant in _mob_sprites.keys():
		var sprite: Variant = _mob_sprites[key]
		if sprite == null:
			continue  # Disguised mimic placeholder
		if not sprite is MobSprite:
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
		var sprite: ItemSprite = _item_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]
	for pos: int in _armed_bomb_sprites.keys():
		var bomb_sprite: ItemSprite = _armed_bomb_sprites[pos]
		if pos >= 0 and pos < _current_level.visible.size():
			bomb_sprite.visible = _current_level.visible[pos] or _current_level.visited[pos]

# ---------------------------------------------------------------------------
# Input Handling
# ---------------------------------------------------------------------------

func _handle_cell_click(cell: int) -> void:
	if GameManager.hero == null:
		return

	# --- Targeting mode: select target cell ---
	if _targeting_active:
		_resolve_targeting(cell)
		return

	# Any manual click cancels auto-walk
	_cancel_auto_walk()

	var hero: Node = GameManager.hero
	var hero_pos: int = hero.pos

	# Check what's at the clicked cell
	var char_at: Variant = _current_level.find_char_at(cell) if _current_level else null

	if char_at != null and char_at != hero:
		# Interact with adjacent NPCs instead of attacking them.
		if _current_level.adjacent(hero_pos, cell):
			if char_at is NPC:
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
	# ESC cancels targeting mode
	if _targeting_active and keycode == KEY_ESCAPE:
		_cancel_targeting_mode()
		return true

	# Any keyboard input cancels auto-walk
	_cancel_auto_walk()
	match keycode:
		KEY_SPACE:
			_submit_hero_action({"type": "wait"})
			return true
		KEY_PERIOD:
			_submit_hero_action({"type": "wait"})
			return true
		KEY_S:
			_submit_hero_action({"type": "search"})
			return true
		# Numpad / Vi keys for movement
		KEY_KP_8, KEY_K, KEY_UP:
			_move_direction(ConstantsData.DIR_N)
			return true
		KEY_KP_2, KEY_J, KEY_DOWN:
			_move_direction(ConstantsData.DIR_S)
			return true
		KEY_KP_4, KEY_H, KEY_LEFT:
			_move_direction(ConstantsData.DIR_W)
			return true
		KEY_KP_6, KEY_L, KEY_RIGHT:
			_move_direction(ConstantsData.DIR_E)
			return true
		KEY_KP_7, KEY_Y:
			_move_direction(ConstantsData.DIR_NW)
			return true
		KEY_KP_9, KEY_U:
			_move_direction(ConstantsData.DIR_NE)
			return true
		KEY_KP_1, KEY_B:
			_move_direction(ConstantsData.DIR_SW)
			return true
		KEY_KP_3, KEY_N:
			_move_direction(ConstantsData.DIR_SE)
			return true
		KEY_LESS:
			_submit_hero_action({"type": "ascend"})
			return true
		KEY_GREATER:
			_submit_hero_action({"type": "descend"})
			return true
	return false

func _move_direction(dir_offset: int) -> void:
	if GameManager.hero == null:
		return
	var target: int = GameManager.hero.pos + dir_offset
	if not ConstantsData.is_valid_pos(target):
		return

	# Check for enemy at target
	var char_at: Variant = _current_level.find_char_at(target) if _current_level else null
	if char_at != null and char_at != GameManager.hero:
		_submit_hero_action({"type": "attack", "target": char_at, "target_pos": target})
	else:
		var terrain: int = _current_level.terrain_at(target)
		if terrain == ConstantsData.Terrain.DOOR or terrain == ConstantsData.Terrain.LOCKED_DOOR or terrain == ConstantsData.Terrain.CRYSTAL_DOOR:
			_submit_hero_action({"type": "interact", "target_pos": target})
		elif not _current_level.passable[target]:
			_submit_hero_action({"type": "search"})
		else:
			_submit_hero_action({"type": "move", "target_pos": target})

func _submit_hero_action(action: Dictionary) -> void:
	if GameManager.hero == null:
		return
	_awaiting_hero_input = false

	var action_type: String = action.get("type", "")

	# Handle level transitions before submitting to hero
	if action_type == "descend":
		_handle_descend()
		return
	if action_type == "ascend":
		_handle_ascend()
		return

	# Check for victory (Amulet of Yendor use)
	if action_type == "use_item":
		var item: Variant = action.get("item")
		if item is Object and item.get("item_id") == "amulet_of_yendor":
			_transition_to_victory()
			return

	# Submit action to hero via command pattern.
	# hero.submit_action() calls execute_action() which handles:
	#   - process_buffs(), the action itself, spend_turn(), and hero_action_complete()
	# Do NOT call spend_energy or hero_action_complete again here.
	if GameManager.hero.has_method("submit_action"):
		GameManager.hero.submit_action(action)

	# Animate the action
	_animate_hero_action(action)

	# After action executes, refresh visuals
	call_deferred("refresh_after_turn")

func _animate_hero_action(action: Dictionary) -> void:
	var hero_sprite: HeroSprite = _hero_sprites.get(GameManager.hero.actor_id)
	if hero_sprite == null:
		return

	match action.get("type", ""):
		"move":
			# Animate to hero's actual position (may differ from clicked cell
			# due to one-step pathfinding)
			if GameManager.hero:
				hero_sprite.move_to(GameManager.hero.pos)
		"attack":
			var target: int = action.get("target_pos", -1)
			if target >= 0:
				hero_sprite.play_attack(target)
		"search":
			if GameManager.hero and effect_manager:
				effect_manager.show_status(GameManager.hero.pos, "Search", Color(0.85, 0.9, 0.65))
				effect_manager.particle_burst(GameManager.hero.pos, Color(0.85, 0.9, 0.65), 5)
		"throw_item":
			var target: int = action.get("target_pos", -1)
			if target >= 0:
				hero_sprite.play_attack(target)
		"zap_wand":
			var target: int = action.get("target_pos", -1)
			if target >= 0:
				hero_sprite.play_attack(target)

# ---------------------------------------------------------------------------
# Item Pickup & Plant Activation
# ---------------------------------------------------------------------------

## Check for items at the hero's position and auto-pickup.
func _check_item_pickup(hero_pos: int) -> void:
	if _current_level == null or GameManager.hero == null:
		return
	# Collect all heaps at this position
	var heaps_here: Array[Dictionary] = _current_level.heaps_at(hero_pos)
	for heap: Dictionary in heaps_here:
		var item: Variant = heap.get("item")
		if item == null:
			continue
		# Auto-pickup gold
		var is_gold: bool = item is Gold or (item is Object and item.get("item_id") == "gold")
		if is_gold:
			var amount: int = item.quantity if "quantity" in item else 1
			GameManager.add_gold(amount)
			_current_level.pickup_item(hero_pos)
			if MessageLog:
				MessageLog.add("You pick up %d gold." % amount)
			if EventBus:
				EventBus.item_picked_up.emit("gold")
		else:
			# Add non-gold items to hero inventory
			var picked: Variant = _current_level.pickup_item(hero_pos)
			if picked != null and GameManager.hero.belongings:
				if GameManager.hero.belongings.has_method("add_item"):
					GameManager.hero.belongings.add_item(picked)
				var item_name: String = ConstantsData.get_prop(picked, "item_name", "item") if picked is Object else "item"
				if MessageLog:
					MessageLog.add("You pick up %s." % item_name)
				if EventBus:
					EventBus.item_picked_up.emit(item_name)
				if GameManager:
					GameManager.record_stat("items_collected")

## Check for plants at the hero's position and activate them.
func _check_plant_activation(hero_pos: int) -> void:
	if _current_level == null or GameManager.hero == null:
		return
	var plant: Variant = _current_level.plants.get(hero_pos)
	if plant == null:
		return
	if plant.has_method("activate"):
		plant.activate(GameManager.hero, _current_level)
	# Remove the plant after activation
	_current_level.plants.erase(hero_pos)

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
	# Item pickup check at new position
	_check_item_pickup(new_pos)
	# Plant activation check
	_check_plant_activation(new_pos)

func _on_mob_defeated(mob_pos: int, _mob_name: String) -> void:
	# Particle burst at death location
	if effect_manager:
		effect_manager.particle_burst(mob_pos, Color(0.8, 0.2, 0.1), 6)
	# Hit sound
	if AudioManager:
		AudioManager.play_sfx("hit")

func _on_item_picked_up(_item_name: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("item_pickup")

func _on_door_opened(pos: int) -> void:
	# Update the tile at door position
	if tile_map:
		tile_map.update_tile_at(pos)
	if AudioManager:
		AudioManager.play_sfx("door_open")

func _on_hero_damaged(amount: int, _source: Variant) -> void:
	# Interrupt auto-walk on damage
	_cancel_auto_walk()
	if GameManager.hero and GameManager.hero.has_method("interrupt"):
		GameManager.hero.interrupt()
	# Camera shake on damage
	if game_camera:
		var intensity: float = clampf(float(amount) / 10.0, 1.0, 5.0)
		game_camera.shake(intensity, 0.2)
	# Damage number
	if effect_manager and GameManager.hero:
		effect_manager.show_damage(GameManager.hero.pos, amount)
	# Audio — hit sound + health warnings matching original SPD
	if AudioManager:
		AudioManager.play_sfx("hit")
		# Health warning SFX (original plays health_warn < 50%, health_critical < 25%)
		if GameManager.hero and GameManager.hero.get("hp") != null and GameManager.hero.get("ht") != null:
			var hp: int = GameManager.hero.hp
			var ht: int = GameManager.hero.ht
			if ht > 0:
				var hp_ratio: float = float(hp) / float(ht)
				if hp_ratio < 0.25:
					AudioManager.play_sfx("health_critical")
				elif hp_ratio < 0.5:
					AudioManager.play_sfx("health_warn")

func _on_hero_died() -> void:
	_game_ended = true
	_cancel_auto_walk()
	if TurnManager:
		TurnManager.processing_mobs = false
		TurnManager.waiting_for_input = false
	if GameManager.hero != null:
		var hero_key: int = GameManager.hero.get("actor_id") if GameManager.hero.get("actor_id") != null else -1
		var hero_sprite: Variant = _hero_sprites.get(hero_key) if hero_key >= 0 else null
		if hero_sprite is HeroSprite and is_instance_valid(hero_sprite):
			hero_sprite.play_hero_death()
	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("death")
		AudioManager.stop_music()
	# Transition to DeathScene after a brief delay
	var timer: SceneTreeTimer = get_tree().create_timer(1.15)
	timer.timeout.connect(_transition_to_death)

func _transition_to_death() -> void:
	_detach_persistent_actors()
	var death_script: GDScript = load("res://src/scenes/death_scene.gd") as GDScript
	if death_script:
		var cause: String = "the dungeon"
		if GameManager.hero and GameManager.hero.get("last_damage_source") != null:
			var src: Variant = GameManager.hero.last_damage_source
			if src is Object and src.get("mob_name"):
				cause = src.mob_name
			elif src is String:
				cause = src
			else:
				cause = str(src)
		SceneManager.go_to(death_script, "DeathScene", {"cause_of_death": cause})

func _on_mob_revealed(mob: Variant) -> void:
	# A previously hidden mob (mimic, sleeping mob) was revealed — add its sprite
	if mob is Object and mob.get("is_alive") == true:
		_spawn_single_mob_sprite(mob)

func _on_mob_damaged(mob_pos: int, amount: int) -> void:
	# Show floating damage number over the mob
	if effect_manager:
		effect_manager.show_damage(mob_pos, amount)

func _on_hero_attack_missed(mob_pos: int) -> void:
	# Show "0" over the mob when attack does no damage (dodge or absorbed)
	if effect_manager:
		effect_manager.show_status(mob_pos, "0", Color(0.7, 0.7, 0.7))
	# Miss whoosh sound
	if AudioManager:
		AudioManager.play_sfx("miss")

func _on_gold_collected(_amount: int, _total: int) -> void:
	if AudioManager:
		AudioManager.play_sfx("gold")

func _on_toolbar_wait() -> void:
	if _awaiting_hero_input:
		_submit_hero_action({"type": "wait"})

func _on_toolbar_search() -> void:
	if _awaiting_hero_input:
		_submit_hero_action({"type": "search"})

func _on_round_completed(_round_number: int) -> void:
	if _current_level == null:
		return
	if _current_level.has_method("tick_pending_bombs"):
		var detonated: bool = _current_level.tick_pending_bombs()
		if detonated:
			refresh_after_turn()

func _on_trap_triggered(_pos: int, _trap_name: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("trap")

func _on_item_used_sfx(item_name: String) -> void:
	if AudioManager == null:
		return
	# Map item types to appropriate SFX
	var lower: String = item_name.to_lower()
	if "potion" in lower:
		AudioManager.play_sfx("drink")
	elif "scroll" in lower:
		AudioManager.play_sfx("read")
	elif "food" in lower or "ration" in lower or "pasty" in lower or "meat" in lower:
		AudioManager.play_sfx("eat")
	elif "bomb" in lower:
		AudioManager.play_sfx("blast")
	elif "honeypot" in lower:
		AudioManager.play_sfx("shatter")
	else:
		AudioManager.play_sfx("click")

func _on_grass_trampled_sfx(_pos: int) -> void:
	if AudioManager:
		AudioManager.play_sfx("trample")

func _on_badge_unlocked_sfx(_badge_id: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("badge")

func _on_item_equipped_sfx(_item_name: String, _slot: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("click")

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
	if GameManager.hero == null:
		return
	# Check we're actually on the exit
	if _current_level and GameManager.hero.pos != _current_level.exit_pos:
		if MessageLog:
			MessageLog.add_warning("You need to be on the stairs down to descend.")
		_awaiting_hero_input = true
		return

	if MessageLog:
		MessageLog.add("You descend deeper into the dungeon...")
	if AudioManager:
		AudioManager.play_sfx("descend")

	var belongings: Variant = GameManager.hero.get("belongings")
	if belongings != null and belongings.has_method("get_equipped_artifact"):
		var artifact: Variant = belongings.get_equipped_artifact()
		if artifact != null and artifact.has_method("on_floor_change"):
			artifact.on_floor_change()

	# Cache current level before leaving
	GameManager._cache_current_level()
	GameManager.depth += 1
	GameManager._on_depth_changed()

	_transition_to_loading("descend")

## Handle ascending to the previous depth via stairs up.
func _handle_ascend() -> void:
	if GameManager.hero == null:
		return
	# Check we're actually on the entrance
	if _current_level and GameManager.hero.pos != _current_level.entrance:
		if MessageLog:
			MessageLog.add_warning("You need to be on the stairs up to ascend.")
		_awaiting_hero_input = true
		return

	# Can't ascend from depth 1 (surface)
	if GameManager.depth <= 1:
		if MessageLog:
			MessageLog.add_warning("The way to the surface is sealed.")
		_awaiting_hero_input = true
		return

	if MessageLog:
		MessageLog.add("You ascend the staircase...")
	if AudioManager:
		AudioManager.play_sfx("descend")

	var belongings: Variant = GameManager.hero.get("belongings")
	if belongings != null and belongings.has_method("get_equipped_artifact"):
		var artifact: Variant = belongings.get_equipped_artifact()
		if artifact != null and artifact.has_method("on_floor_change"):
			artifact.on_floor_change()

	# Cache current level before leaving
	GameManager._cache_current_level()
	GameManager.depth -= 1
	GameManager._on_depth_changed()

	_transition_to_loading("ascend")

## Transition to the LoadingScene for level generation.
func _transition_to_loading(transition_type: String = "descend") -> void:
	_game_ended = true
	_cancel_auto_walk()
	_detach_persistent_actors()

	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script:
		SceneManager.go_to(loading_script, "LoadingScene", {
			"is_continue": true,
			"transition_type": transition_type,
		})

## Transition to the victory scene (Amulet of Yendor).
func _transition_to_victory() -> void:
	_game_ended = true
	_cancel_auto_walk()
	_detach_persistent_actors()

	if AudioManager:
		AudioManager.play_sfx("victory")
		AudioManager.stop_music()

	# Try to load a victory scene; fall back to a simple message
	var victory_script: GDScript = load("res://src/scenes/victory_scene.gd") as GDScript
	if victory_script:
		SceneManager.go_to(victory_script, "VictoryScene")
	else:
		if MessageLog:
			MessageLog.add_positive("You obtained the Amulet of Yendor! You win!")
		var timer: SceneTreeTimer = get_tree().create_timer(3.0)
		timer.timeout.connect(func() -> void:
			var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
			if title_script:
				SceneManager.go_to(title_script, "TitleScene")
		)

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
	_auto_walk_target = target
	_auto_walk_known_mobs = _get_visible_mob_positions()
	_auto_walk_prev_hp = GameManager.hero.hp if GameManager.hero else -1

## Cancel auto-walk (enemy spotted, damage taken, manual input, etc.).
func _cancel_auto_walk() -> void:
	_auto_walk_target = -1
	_auto_walk_known_mobs.clear()
	_auto_walk_prev_hp = -1
	_auto_walk_cooldown = 0.0

## Process one auto-walk step. Called from _process when it's the hero's turn
## and auto-walk is active.
func _process_auto_walk() -> void:
	var hero: Variant = GameManager.hero
	if hero == null or not hero.is_alive:
		_cancel_auto_walk()
		return

	# --- Check interrupt conditions ---

	# 1. Reached destination
	if hero.pos == _auto_walk_target:
		_cancel_auto_walk()
		return

	# 2. Hero took damage since last step
	if _auto_walk_prev_hp >= 0 and hero.hp < _auto_walk_prev_hp:
		_cancel_auto_walk()
		return

	# 3. New enemy came into view
	var current_mobs: Dictionary = _get_visible_mob_positions()
	for mob_key: Variant in current_mobs.keys():
		if not _auto_walk_known_mobs.has(mob_key):
			_cancel_auto_walk()
			return

	# 4. Hero is standing on an item (auto-walk pauses so player notices)
	if _current_level:
		var heaps_here: Array[Dictionary] = _current_level.heaps_at(hero.pos)
		if not heaps_here.is_empty():
			_cancel_auto_walk()
			return

	# 5. Hero is on stairs
	if _current_level:
		var terrain: int = _current_level.terrain_at(hero.pos)
		if terrain == ConstantsData.Terrain.EXIT or terrain == ConstantsData.Terrain.ENTRANCE:
			_cancel_auto_walk()
			return

	# 6. Check if adjacent to any enemy
	if _current_level:
		for dir: int in ConstantsData.DIRS_8:
			var adj_pos: int = hero.pos + dir
			var char_at: Variant = _current_level.find_char_at(adj_pos)
			if char_at != null and char_at != hero:
				_cancel_auto_walk()
				return

	# --- Take the next step ---
	_auto_walk_known_mobs = current_mobs
	_auto_walk_prev_hp = hero.hp

	var pre_move_pos: int = hero.pos
	_submit_hero_action({"type": "move", "target_pos": _auto_walk_target})

	# If hero didn't move (blocked or no path), cancel auto-walk
	if hero.pos == pre_move_pos:
		_cancel_auto_walk()
	else:
		# Pace auto-walk so the movement tween is visible
		_auto_walk_cooldown = AUTO_WALK_STEP_DELAY

## Return a dictionary of currently visible mob positions (for interrupt detection).
func _get_visible_mob_positions() -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	if _current_level == null:
		return result
	for mob: Node in _current_level.mobs:
		if is_instance_valid(mob) and mob.get("is_alive") == true:
			var mob_pos: int = mob.get("pos") as int
			if mob_pos >= 0 and mob_pos < _current_level.visible.size():
				if _current_level.visible[mob_pos]:
					result[mob_pos] = true
	return result

func _interrupt_rest_if_needed() -> void:
	if GameManager.hero == null or not GameManager.hero.get("resting"):
		return
	var visible_mobs: Dictionary[int, bool] = _get_visible_mob_positions()
	if not visible_mobs.is_empty() and GameManager.hero.has_method("interrupt"):
		GameManager.hero.interrupt()

# ---------------------------------------------------------------------------
# Targeting Mode
# ---------------------------------------------------------------------------

## Enter targeting mode via signal from inventory/item windows.
func _on_enter_targeting(item: Variant, max_range: int, callback: Callable) -> void:
	_targeting_active = true
	_targeting_item = item
	_targeting_max_range = max_range
	_targeting_callback = callback
	_cancel_auto_walk()
	if MessageLog:
		var item_name: String = ConstantsData.get_prop(item, "item_name", "item") if item is Object else "item"
		MessageLog.add("Select a target for the %s. (Press Escape to cancel)" % item_name)

## Cancel targeting mode via signal.
func _on_cancel_targeting() -> void:
	_cancel_targeting_mode()

## Cancel targeting and inform the player.
func _cancel_targeting_mode() -> void:
	if not _targeting_active:
		return
	_targeting_active = false
	_targeting_item = null
	_targeting_max_range = 0
	_targeting_callback = Callable()
	_awaiting_hero_input = true
	if MessageLog:
		MessageLog.add("Targeting cancelled.")

## Resolve targeting — the player clicked a cell while in targeting mode.
func _resolve_targeting(cell: int) -> void:
	if not _targeting_active:
		return

	var hero: Variant = GameManager.hero
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
	if item is MissileWeapon or item is SpiritBow or item is Bomb or item is Wand:
		var hero_sprite: HeroSprite = _hero_sprites.get(GameManager.hero.actor_id) if GameManager.hero else null
		if hero_sprite != null:
			hero_sprite.play_attack(cell)
	if callback.is_valid():
		callback.call(cell)
	call_deferred("refresh_after_turn")
