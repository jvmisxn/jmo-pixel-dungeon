class_name YogFist
extends Mob
## A fist of Yog-Dzewa. Rotting type poisons, Burning type sets fire.

enum FistType { ROTTING, BURNING }
var fist_type: FistType = FistType.ROTTING

func _init() -> void:
	super._init()
	mob_id = "yog_fist"
	mob_name = "Fist of Yog"
	xp_value = 30
	max_level = 30
	awareness = 1.0
	aggro_range = 99
	state = AIState.HUNTING

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	match fist_type:
		FistType.ROTTING:
			if randf() < 0.6:
				var p: Poison = Poison.create(8.0)
				target_char.add_buff(p)
		FistType.BURNING:
			var burn: Burning = Burning.new()
			target_char.add_buff(burn)

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_positive("The %s is destroyed!" % mob_name)
	super._on_death(source)
