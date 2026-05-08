class_name AdrenalineSurge
extends Buff
## Adrenaline Surge: temporarily boosts strength.
## Original: modifies effective STR (affects equipment requirements and weapon damage).

const BASE_DURATION: float = 10.0
var bonus: int = 2

func _init() -> void:
	buff_id = "AdrenalineSurge"
	buff_name = "Adrenaline Surge"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.2, 0.2)

static func create(str_bonus: int) -> AdrenalineSurge:
	var a: AdrenalineSurge = AdrenalineSurge.new()
	a.bonus = str_bonus
	return a

## Returns the STR bonus granted by this buff.
## Equipment and combat systems should query this.
func str_bonus() -> int:
	return bonus

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s surges with adrenaline! (+%d STR)" % [target.name, bonus])

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_warning("%s's adrenaline surge wears off." % target.name)

func merge(other: Node) -> void:
	if other is AdrenalineSurge:
		var other_a: AdrenalineSurge = other as AdrenalineSurge
		bonus = maxi(bonus, other_a.bonus)
		time_left = maxf(time_left, other_a.time_left)
		duration = maxf(duration, other_a.duration)
	else:
		super.merge(other)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["bonus"] = bonus
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	bonus = data.get("bonus", 0)
