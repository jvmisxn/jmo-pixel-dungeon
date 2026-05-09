class_name Golem
extends Mob
## Extremely tough, slow. Teleports target on hit.

func _init() -> void:
	super._init()
	mob_id = "golem"
	mob_name = "Stone Golem"
	description = "A massive stone construct. Slow but incredibly durable."
	setup(85, 20, 8, 12, 28, 18)
	xp_value = 12
	max_level = 22
	awareness = 0.3
	aggro_range = 6
	base_speed = 0.6
	loot_table = [{"item_id": "gold", "chance": 0.6}]

func on_attack_hit(target_char: Char, damage: int) -> void:
	super.on_attack_hit(target_char, damage)
	# Chance to teleport the target
	if randf() < 0.25:
		_teleport_target(target_char)

func _teleport_target(victim: Char) -> void:
	did_visible_action = true
	if level == null:
		return
	# Find random passable cell
	for _attempt: int in range(20):
		var random_pos: int = randi_range(0, ConstantsData.LENGTH - 1)
		if level.has_method("is_passable") and level.is_passable(random_pos):
			if level.has_method("find_char_at") and level.find_char_at(random_pos) == null:
				victim.pos = random_pos
				if victim.is_hero and EventBus:
					EventBus.hero_moved.emit(random_pos)
				if MessageLog:
					MessageLog.add_warning("The golem's blow teleports you!")
				return
