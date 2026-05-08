class_name Corrosion
extends Buff
## Corrosion debuff: deals escalating damage each turn.
## Original (Corrosion.java): starts at a set damage level, increases by 1 per
## turn (or 0.5 once damage exceeds (scalingDepth/2)+2).
## Used by Wand of Corrosion and corrosive gas.
## Implements Hero.Doom for death tracking.

var damage: float = 1.0
var left: float = 0.0
var source_id: String = ""  # e.g., "WandOfCorrosion" for death logic

func _init() -> void:
	buff_id = "Corrosion"
	buff_name = "Corroding"
	buff_type = BuffType.NEGATIVE
	duration = -1.0  # managed by 'left'
	time_left = -1.0
	icon_color = Color(1.0, 0.5, 0.0)
	announced = true

## Set corrosion parameters. Takes max of existing duration/damage.
func set_level(new_duration: float, new_damage: int, new_source: String = "") -> void:
	left = maxf(new_duration, left)
	if damage < new_damage:
		damage = float(new_damage)
	if new_source != "":
		source_id = new_source

## Extend corrosion duration additively.
func extend(extra_duration: float) -> void:
	left += extra_duration

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s is corroding!" % target.name)

func on_turn() -> void:
	if target == null:
		return

	if target.is_alive:
		target.take_damage(int(damage), self)

		# Original: damage increases by 1 if below threshold, 0.5 above
		var depth: int = 1
		if GameManager:
			depth = maxi(1, GameManager.depth)
		@warning_ignore("integer_division")
		var threshold: float = float(depth / 2) + 2.0
		if damage < threshold:
			damage += 1.0
		else:
			damage += 0.5

		left -= 1.0
		if left <= 0.0:
			if target:
				target.remove_buff(self)
	else:
		if target:
			target.remove_buff(self)

func merge(other: Node) -> void:
	if other is Corrosion:
		var other_c: Corrosion = other as Corrosion
		set_level(other_c.left, int(other_c.damage), other_c.source_id)
	else:
		super.merge(other)

func is_expired() -> bool:
	return left <= 0.0

func icon_text() -> String:
	return str(int(damage))

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["damage"] = damage
	data["left"] = left
	data["source_id"] = source_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	damage = data.get("damage", 1.0)
	left = data.get("left", 0.0)
	source_id = data.get("source_id", "")

func description() -> String:
	return "Corroding, taking %d damage per turn (increasing). %s turns left." % [int(damage), disp_turns(left)]
