class_name FloorTransitionCoordinator
extends RefCounted

static func handle_descend(scene: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	if scene._current_level and hero.pos != scene._current_level.exit_pos:
		if MessageLog:
			MessageLog.add_warning("You need to be on the stairs down to descend.")
		scene._awaiting_hero_input = true
		return
	if scene._current_level and scene._current_level.locked:
		if MessageLog:
			MessageLog.add_warning(
				"You cannot leave this floor while its guardian still lives!"
			)
		scene._awaiting_hero_input = true
		return
	if not party_ready_for_stairs(
		scene,
		scene._current_level.exit_pos,
		"All party members must be on the stairs down to descend."
	):
		scene._awaiting_hero_input = true
		return
	if GameManager == null or GameManager.depth >= ConstantsData.MAX_DEPTH:
		if MessageLog:
			MessageLog.add_warning("The way deeper is sealed.")
		scene._awaiting_hero_input = true
		return
	if not _consume_skeleton_key_for_boss_exit(scene, hero):
		return
	if MessageLog:
		MessageLog.add("You descend deeper into the dungeon...")
	if AudioManager:
		AudioManager.play_sfx("descend")
	notify_party_floor_change(scene)
	var new_depth: int = GameManager.descend()
	if new_depth < 0:
		scene._awaiting_hero_input = true
		return
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "descend")
	transition_to_loading(scene, "descend")

## Upstream GameScene.create ROGUES_FORESIGHT block: on arriving at a regular
## floor holding at least one secret room (two when the level feeling is
## SECRETS), a hero with Rogue's Foresight has a 2+points in 4 (75%/100%)
## chance to sense it. Upstream seeds the roll with the level seed so every
## visit agrees; the port rolls once and persists the roll on the level.
static func rogues_foresight_secret_hint(level: Variant, hero: Variant) -> bool:
	if level == null or hero == null or not (level is RegularLevel):
		return false
	var points: int = 0
	if hero.has_method("get_talent_level"):
		points = hero.get_talent_level("rogue_rogues_foresight")
	if points <= 0:
		return false
	var req_secrets: int = 2 if level.feeling == Level.Feeling.SECRETS else 1
	if level.secret_room_count < req_secrets:
		return false
	if level.foresight_roll < 0:
		level.foresight_roll = randi() % 4
	return level.foresight_roll < 2 + points

static func handle_ascend(scene: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	if scene._current_level and hero.pos != scene._current_level.entrance:
		if MessageLog:
			MessageLog.add_warning("You need to be on the stairs up to ascend.")
		scene._awaiting_hero_input = true
		return
	if scene._current_level and scene._current_level.locked:
		if MessageLog:
			MessageLog.add_warning(
				"You cannot leave this floor while its guardian still lives!"
			)
		scene._awaiting_hero_input = true
		return
	if not party_ready_for_stairs(
		scene,
		scene._current_level.entrance,
		"All party members must be on the stairs up to ascend."
	):
		scene._awaiting_hero_input = true
		return
	if GameManager.depth <= 1:
		# Upstream Hero.actAscend depth-1 gate: with the Amulet of Yendor the
		# run ends in victory (Dungeon.win + surface); without it the hero
		# cannot leave (hero.properties "leave" text).
		if party_has_amulet(hero):
			if MessageLog:
				MessageLog.add_positive("You ascend into the sunlight, the Amulet of Yendor in hand!")
			RunTransitionCoordinator.transition_to_victory(scene)
			return
		if MessageLog:
			MessageLog.add_warning("You can't leave yet, the Amulet of Yendor must be retrieved first!")
		scene._awaiting_hero_input = true
		return
	if MessageLog:
		MessageLog.add("You ascend the staircase...")
	if AudioManager:
		AudioManager.play_sfx("descend")
	notify_party_floor_change(scene)
	var new_depth: int = GameManager.ascend()
	if new_depth < 0:
		scene._awaiting_hero_input = true
		return
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "ascend")
	transition_to_loading(scene, "ascend")

static func handle_fall(scene: Variant, hero_node: Variant) -> void:
	if scene == null or hero_node == null:
		return
	if scene.get("_game_ended") == true:
		return
	if GameManager == null or GameManager.depth >= ConstantsData.MAX_DEPTH:
		_relocate_faller_on_current_level(scene, hero_node)
		Chasm.apply_landing_damage(hero_node, scene._current_level)
		scene.refresh_after_turn()
		return
	if AudioManager:
		AudioManager.play_sfx("falling")
	notify_party_floor_change(scene)
	var fall_actor_id: int = int(hero_node.get("actor_id")) if hero_node.get("actor_id") != null else -1
	var fall_source_pos: int = int(hero_node.get("pos")) if hero_node.get("pos") != null else -1
	var fall_into_pit: bool = _is_weak_floor_room(scene._current_level, fall_source_pos)
	var new_depth: int = GameManager.descend()
	if new_depth < 0:
		_relocate_faller_on_current_level(scene, hero_node)
		Chasm.apply_landing_damage(hero_node, scene._current_level)
		scene.refresh_after_turn()
		return
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "fall")
	transition_to_loading(scene, "fall", {
		"fall_actor_id": fall_actor_id,
		"fall_into_pit": fall_into_pit,
	})

## Any active party hero (or the acting hero as fallback) carrying the
## Amulet of Yendor unlocks the depth-1 victory ascent.
static func party_has_amulet(fallback_hero: Variant) -> bool:
	if GameManager != null and GameManager.has_method("get_active_heroes"):
		for party_hero: Variant in GameManager.get_active_heroes():
			if _hero_has_amulet(party_hero):
				return true
	return _hero_has_amulet(fallback_hero)

static func _hero_has_amulet(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings") if hero is Object else null
	var backpack: Variant = belongings.get("backpack") if belongings != null else null
	if backpack is Array:
		for item: Variant in backpack:
			if item != null and ConstantsData.get_prop(item, "item_id", "") == "amulet_of_yendor":
				return true
	return false

static func _consume_skeleton_key_for_boss_exit(scene: Variant, hero: Variant) -> bool:
	if GameManager == null or not _is_skeleton_key_depth(GameManager.depth):
		return true
	var key_holder: Variant = _find_skeleton_key_holder(hero)
	if key_holder != null:
		if _consume_skeleton_key(key_holder):
			return true
		if key_holder.has_method("use_key"):
			key_holder.use_key("skeleton")
		return true
	if MessageLog:
		MessageLog.add_warning("You need the skeleton key to unlock the way forward.")
	if scene != null:
		scene._awaiting_hero_input = true
	return false

static func _find_skeleton_key_holder(fallback_hero: Variant) -> Variant:
	if GameManager != null and GameManager.has_method("get_active_heroes"):
		for party_hero: Variant in GameManager.get_active_heroes():
			if _has_skeleton_key_for_current_depth(party_hero):
				return party_hero
	if _has_skeleton_key_for_current_depth(fallback_hero):
		return fallback_hero
	return null

static func _has_skeleton_key_for_current_depth(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings") if hero is Object else null
	var backpack: Variant = belongings.get("backpack") if belongings != null else null
	if backpack is Array:
		for item: Variant in backpack:
			if _is_current_depth_skeleton_key(item):
				return true
		return false
	return hero.has_method("has_key") and hero.has_key("skeleton")

static func _consume_skeleton_key(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings") if hero is Object else null
	var backpack: Variant = belongings.get("backpack") if belongings != null else null
	if not (backpack is Array):
		return false
	for item: Variant in backpack:
		if not _is_current_depth_skeleton_key(item):
			continue
		if belongings.has_method("remove_item"):
			belongings.remove_item(item)
			if MessageLog:
				MessageLog.add("You use the %s." % ConstantsData.get_prop(item, "item_name", "key"))
			return true
	return false

static func _is_current_depth_skeleton_key(item: Variant) -> bool:
	return item != null \
			and ConstantsData.get_prop(item, "item_id", "") == "skeleton_key" \
			and int(ConstantsData.get_prop(item, "depth", -1)) == GameManager.depth

static func _is_skeleton_key_depth(depth: int) -> bool:
	return depth > 0 and depth % 5 == 0 and depth < ConstantsData.MAX_DEPTH

static func party_ready_for_stairs(scene: Variant, stair_pos: int, failure_message: String) -> bool:
	if scene == null or GameManager == null or not GameManager.has_method("get_active_heroes"):
		return true
	var party: Array[Node] = GameManager.get_active_heroes()
	if party.size() <= 1:
		return true
	var missing_count: int = 0
	for party_hero: Variant in party:
		if party_hero == null or not party_hero.get("is_alive"):
			continue
		if int(party_hero.get("pos")) != stair_pos:
			missing_count += 1
	if missing_count <= 0:
		return true
	if MessageLog:
		MessageLog.add_warning("%s (%d missing)" % [failure_message, missing_count])
	return false

static func notify_party_floor_change(scene: Variant) -> void:
	if scene == null or GameManager == null or not GameManager.has_method("get_active_heroes"):
		return
	for party_hero: Variant in GameManager.get_active_heroes():
		if party_hero == null:
			continue
		var belongings: Variant = party_hero.get("belongings")
		if belongings != null and belongings.has_method("get_equipped_artifact"):
			var artifact: Variant = belongings.get_equipped_artifact()
			if artifact != null and artifact.has_method("on_floor_change"):
				artifact.on_floor_change()
	hold_party_allies()

## Upstream Mob.holdAllies: pull follower allies (Dried Rose ghost) off the
## departing level — before GameManager caches/frees its mobs — so they can
## be restored beside the party on the next floor.
static func hold_party_allies() -> void:
	if GameManager == null or GameManager.current_level == null:
		return
	var level: Variant = GameManager.current_level
	if level.get("mobs") == null:
		return
	for mob: Variant in level.mobs.duplicate():
		if mob == null or not is_instance_valid(mob):
			continue
		if not bool(mob.get("follows_hero")) or not bool(mob.get("is_alive")):
			continue
		if mob.has_method("serialize"):
			GameManager.held_allies.append(mob.serialize())
		if level.has_method("remove_mob"):
			level.remove_mob(mob)
		if TurnManager:
			TurnManager.remove_actor(mob)
		if mob is Node:
			(mob as Node).free()

## Upstream Mob.restoreAllies: respawn held allies on free cells beside the
## party and re-link the Dried Rose to its ghost. Called by LoadingScene
## after party positions are assigned on the arrival level.
static func restore_party_allies(level: Variant) -> void:
	if GameManager == null or level == null or GameManager.held_allies.is_empty():
		return
	var held: Array[Dictionary] = GameManager.held_allies.duplicate()
	GameManager.held_allies.clear()
	for data: Dictionary in held:
		var mob_id: String = str(data.get("mob_id", ""))
		var mob: Variant = MobFactory.create_mob(mob_id) if mob_id != "" else null
		if mob == null:
			continue
		if mob.has_method("deserialize"):
			mob.deserialize(data)
		var spawn_pos: int = _ally_arrival_pos(level)
		if spawn_pos < 0:
			if mob is Node:
				(mob as Node).free()
			continue
		mob.pos = spawn_pos
		if level.has_method("add_mob"):
			level.add_mob(mob)
		if TurnManager:
			TurnManager.add_actor(mob)
		if mob.has_method("resolve_post_load"):
			mob.resolve_post_load(level)
		_relink_rose_ghost(mob)

## Free cell adjacent to a party hero (upstream candidatePositions over
## NEIGHBOURS8 of the arrival pos), falling back to any passable cell.
static func _ally_arrival_pos(level: Variant) -> int:
	if GameManager != null and GameManager.has_method("get_active_heroes"):
		for party_hero: Variant in GameManager.get_active_heroes():
			if party_hero == null:
				continue
			var hero_pos: int = int(party_hero.get("pos")) if party_hero.get("pos") != null else -1
			if hero_pos < 0:
				continue
			for dir: int in ConstantsData.DIRS_8:
				var candidate: int = hero_pos + dir
				if candidate < 0 or candidate >= ConstantsData.LENGTH:
					continue
				if level.has_method("is_passable") and not level.is_passable(candidate):
					continue
				if level.has_method("find_char_at") and level.find_char_at(candidate) != null:
					continue
				return candidate
	if level.has_method("random_passable_cell"):
		return int(level.random_passable_cell())
	return -1

## Re-link a restored ghost with its owner's equipped Dried Rose so the
## artifact keeps tracking/healing it (upstream keeps the object reference;
## the port recreates the node from serialized data).
static func _relink_rose_ghost(mob: Variant) -> void:
	if str(mob.get("mob_id")) != "rose_ghost":
		return
	if GameManager == null or not GameManager.has_method("get_active_heroes"):
		return
	for party_hero: Variant in GameManager.get_active_heroes():
		if party_hero == null:
			continue
		var belongings: Variant = party_hero.get("belongings")
		if belongings == null or not belongings.has_method("get_equipped_artifact"):
			continue
		var artifact: Variant = belongings.get_equipped_artifact()
		if artifact == null or str(artifact.get("item_id")) != "dried_rose":
			continue
		if not bool(artifact.get("ghost_summoned")):
			continue
		artifact.current_ghost = mob
		artifact.summoned_ghost_actor_id = int(mob.get("actor_id")) if mob.get("actor_id") != null else -1
		mob.source_artifact = artifact
		if party_hero is Char:
			mob.ally_hero = party_hero
		return

static func transition_to_loading(scene: Variant, transition_type: String = "descend", extra_meta: Dictionary = {}) -> void:
	if scene == null:
		return
	scene._game_ended = true
	scene._cancel_auto_walk()
	scene._detach_persistent_actors()
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script:
		var meta: Dictionary = {
			"is_continue": true,
			"transition_type": transition_type,
		}
		meta.merge(extra_meta, true)
		SceneManager.go_to(loading_script, "LoadingScene", meta)

static func _relocate_faller_on_current_level(scene: Variant, hero_node: Variant) -> void:
	if scene == null or hero_node == null:
		return
	var level: Variant = scene.get("_current_level")
	if level == null or not level.has_method("random_passable_cell"):
		return
	var landing: int = level.random_passable_cell()
	if landing < 0:
		return
	hero_node.set("pos", landing)
	hero_node.set("level", level)

static func _is_weak_floor_room(level: Variant, pos: int) -> bool:
	if level == null or pos < 0:
		return false
	var room_list: Variant = level.get("rooms") if level is Object else null
	if not (room_list is Array):
		return false
	for room: Variant in room_list:
		if room is WeakFloorRoom and room.inside(pos):
			return true
	return false
