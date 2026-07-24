class_name Spinner
extends Mob
## Giant spider that poisons and leaves webs. Flees after poisoning target,
## returns to hunting when target's poison expires.
## Original: Spinner.java — flees on successful poison, shoots webs ahead of
## enemy movement, immune to Web, resistant to Poison.

## Cooldown for web shooting (original: webCoolDown, resets to 10 after shooting).
var web_cooldown: int = 0
## Last known enemy position for web trajectory prediction.
var last_enemy_pos: int = -1

func _init() -> void:
	super._init()
	mob_id = "spinner"
	mob_name = "Cave Spinner"
	description = "A giant spider that spins webs and injects venom."
	# Original: HP=HT=50, attackSkill=22, defenseSkill=17, damageRoll=10-20, DR=0-6
	setup(50, 22, 17, 10, 20, 6)
	xp_value = 9
	max_level = 17
	awareness = 0.3
	aggro_range = 7
	loot_table = [{"item_id": "mystery_meat", "chance": 0.125}]
	_resistances = ["Poison"]
	_immunities = ["Web"]

func act() -> void:
	if state == AIState.HUNTING or state == AIState.FLEEING:
		web_cooldown -= 1
	super.act()
	# Update last enemy position after acting (for web trajectory prediction)
	if target != null and can_see(target.pos):
		last_enemy_pos = target.pos

func _act_hunting() -> void:
	# Original Hunting.act(): the web shot is a pre-step; every shared hunting
	# guard (flee, Amok retarget, chase/attack, lost-target) runs in the base.
	if has_buff("Amok"):
		var nearest: Char = _find_nearest_char()
		if nearest:
			target = nearest
	if _try_shoot_web():
		return
	super._act_hunting()

func _act_fleeing() -> void:
	# Original Fleeing.act(): return to hunting once the enemy is visible and
	# no longer poisoned, unless Terror/Dread force the flee to continue.
	if not has_buff("Terror") and not has_buff("Dread") \
			and target != null and target.is_alive and can_see(target.pos) \
			and target.has_method("has_buff") and not target.has_buff("Poison"):
		_set_state(AIState.HUNTING)
		_act_hunting()
		return
	# A fleeing spinner still shoots webs at a visible enemy.
	if _try_shoot_web():
		return
	super._act_fleeing()

## Web pre-step shared by hunting and fleeing (original Hunting/Fleeing.act).
func _try_shoot_web() -> bool:
	if target == null or not target.is_alive:
		return false
	if web_cooldown > 0 or not can_see(target.pos) or distance_to(target.pos) > 6:
		return false
	_shoot_web()
	spend_attack()
	return true

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	# Original attackProc: 50% chance to poison for 7-8 turns; on a successful
	# poison the web cooldown resets and the spinner flees while it lasts.
	if randf() < 0.5:
		var p: Poison = Poison.create(float(randi_range(7, 8)))
		target_char.add_buff(p)
		web_cooldown = 0
		_set_state(AIState.FLEEING)

func _shoot_web() -> void:
	web_cooldown = 10
	did_visible_action = true
	if target == null or level == null:
		return
	var web_pos: int = _predict_web_position()
	# Place web at predicted target position
	if level.has_method("set_terrain"):
		level.set_terrain(web_pos, ConstantsData.Terrain.WEB)
	if level.has_method("add_blob"):
		var web: WebBlob = WebBlob.new()
		level.add_blob(web, web_pos)
	if MessageLog:
		MessageLog.add_warning("The spinner shoots a web!")

func _predict_web_position() -> int:
	if target == null or level == null:
		return pos
	var target_pos: int = target.pos
	if last_enemy_pos >= 0 and last_enemy_pos != target_pos:
		var dx: int = signi(ConstantsData.pos_to_x(target_pos) - ConstantsData.pos_to_x(last_enemy_pos))
		var dy: int = signi(ConstantsData.pos_to_y(target_pos) - ConstantsData.pos_to_y(last_enemy_pos))
		var predicted_pos: int = target_pos + dx + dy * ConstantsData.WIDTH
		if ConstantsData.is_valid_pos(predicted_pos) and level.is_passable(predicted_pos):
			return predicted_pos
	return target_pos

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["web_cooldown"] = web_cooldown
	data["last_enemy_pos"] = last_enemy_pos
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	web_cooldown = int(data.get("web_cooldown", web_cooldown))
	last_enemy_pos = int(data.get("last_enemy_pos", last_enemy_pos))
