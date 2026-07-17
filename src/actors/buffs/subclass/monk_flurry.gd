class_name MonkFlurry
extends Buff
## Monk (Duelist) subclass passive. Unarmed attacks become faster with
## consecutive hits. Gains Focus buff after dodging.

var consecutive_hits: int = 0
const MAX_CONSECUTIVE: int = 5
## Whether focus is active (next attack has +100% accuracy after dodging).
var has_focus: bool = false

func _init() -> void:
	buff_id = "MonkFlurry"
	buff_name = "Flurry"
	duration = -1.0
	icon_color = Color(0.9, 0.8, 0.3)

func on_damage_dealt(amount: int, _target: Node) -> void:
	if amount > 0:
		consecutive_hits = mini(consecutive_hits + 1, MAX_CONSECUTIVE)
		# Consume focus on attack
		if has_focus:
			has_focus = false

func on_damage_taken(amount: int, _source: Variant) -> void:
	if amount == 0:
		# Dodged! Gain focus
		has_focus = true
		if MessageLog:
			MessageLog.add_positive("Focus! Your next attack has perfect accuracy.")
	else:
		# Hit breaks combo
		consecutive_hits = 0

func modify_speed(speed: float) -> float:
	# Flurry is an attack-speed passive, not movement speed. Attack delay needs
	# its own hook so get_speed() can safely activate movement buffs.
	return speed

func modify_accuracy(acc: int) -> int:
	if has_focus:
		return acc * 2  # +100% accuracy from focus
	return acc

func modify_damage(dmg: int) -> int:
	# Unarmed damage scales with hero level
	if target and target.get("is_hero") == true:
		var hero: Node = target
		if hero.belongings == null or hero.belongings.weapon == null:
			@warning_ignore("integer_division")
			var level_bonus: int = hero.hero_level / 3
			return dmg + level_bonus
	return dmg

func description() -> String:
	var parts: Array[String] = []
	if consecutive_hits > 0:
		parts.append("%d hits (x%.1f speed)" % [consecutive_hits, 1.0 + consecutive_hits * 0.4])
	if has_focus:
		parts.append("Focus active!")
	if parts.is_empty():
		return "Flurry"
	return "Flurry: rapid strikes deal bonus damage."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["consecutive_hits"] = consecutive_hits
	data["has_focus"] = has_focus
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	consecutive_hits = int(data.get("consecutive_hits", consecutive_hits))
	has_focus = bool(data.get("has_focus", has_focus))
