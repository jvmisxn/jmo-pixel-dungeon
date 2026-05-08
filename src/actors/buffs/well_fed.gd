class_name WellFed
extends Buff
## WellFed: blocks hunger gain entirely and heals 1 HP every 18 turns.
## Applied by eating food when already full (Pasty, Ration, etc.).
## Original: blocks Hunger.isStarving(), provides slow regeneration.

const BASE_DURATION: float = 450.0  # Full hunger bar worth of turns
const HEAL_INTERVAL: float = 18.0

var partial_heal: float = 0.0

func _init() -> void:
	buff_id = "WellFed"
	buff_name = "Well Fed"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.9, 0.7, 0.3)

func on_turn() -> void:
	if target == null or not target.is_alive:
		return
	# Slow regeneration while well fed
	if target.hp < target.ht:
		partial_heal += 1.0 / HEAL_INTERVAL
		if partial_heal >= 1.0:
			var heal: int = int(partial_heal)
			partial_heal -= heal
			target.heal(heal)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s feels well fed!" % target.name)

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_info("%s no longer feels stuffed." % target.name)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["partial_heal"] = partial_heal
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	partial_heal = data.get("partial_heal", 0.0)

func description() -> String:
	return "Well fed! Hunger is paused and slowly regenerating (%s turns left)." % disp_turns(time_left)
