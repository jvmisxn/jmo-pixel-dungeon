class_name MeditateTracker
extends Buff
## Tracks the Monk's 5-turn meditation. When the meditation ends, wands
## recharge rapidly for 8 turns (upstream Meditate schedules Recharging via
## a delayed actor at hero.cooldown()-1; the ArtifactRecharge half has no
## local artifact-charge system to feed yet).

const MEDITATE_TURNS: float = 5.0
const RECHARGE_TURNS: float = 8.0

func _init() -> void:
	buff_id = "MeditateTracker"
	buff_name = "Meditating"
	buff_type = BuffType.POSITIVE
	duration = MEDITATE_TURNS
	time_left = MEDITATE_TURNS
	icon_color = Color(0.63, 0.53, 0.25)

func on_detach() -> void:
	if target == null or not is_instance_valid(target):
		return
	if not ("is_alive" in target) or not target.is_alive:
		return
	if target.has_method("add_buff"):
		var recharging: Recharging = Recharging.new()
		recharging.duration = RECHARGE_TURNS
		recharging.time_left = RECHARGE_TURNS
		target.add_buff(recharging)

func description() -> String:
	return "This character is deep in meditation. When the meditation ends their wands will briefly recharge rapidly."
