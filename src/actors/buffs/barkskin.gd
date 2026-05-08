class_name Barkskin
extends Buff
## Barkskin buff: grants bonus armor (DR) that decays over time.
## Original (Barkskin.java): level decreases by 1 each interval.
## Multiple Barkskin instances can stack — only the strongest bonus applies,
## but durations are independent.
## Sources: Earthroot plant, Warden subclass, Barkskin talent.

var level: int = 0
var interval: int = 1

func _init() -> void:
	buff_id = "Barkskin"
	buff_name = "Barkskin"
	buff_type = BuffType.POSITIVE
	duration = -1.0  # managed by level decay
	time_left = -1.0
	icon_color = Color(0.4, 0.6, 0.2)

## Set barkskin level and interval. Only overrides if new value is stronger.
func set_level(value: int, time: int) -> void:
	if level <= value:
		level = value
		interval = time

## Delay the next tick by a given amount.
func delay(value: float) -> void:
	# In the original this adjusts the Actor cooldown
	pass

func on_turn() -> void:
	if target == null or not target.is_alive:
		if target:
			target.remove_buff(self)
		return
	# Decrement level each interval
	level -= 1
	if level <= 0:
		if target:
			target.remove_buff(self)

func get_level() -> int:
	return level

func icon_text() -> String:
	return str(level) if level > 0 else ""

func is_expired() -> bool:
	return level <= 0

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["level"] = level
	data["interval"] = interval
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	level = data.get("level", 0)
	interval = data.get("interval", 1)

func description() -> String:
	return "Protected by bark-like skin (+%d DR)." % level

## Static helper: get the current barkskin level for a character.
## Takes the max across all Barkskin buff instances.
static func current_level(ch: Node) -> int:
	var max_level: int = 0
	for buff: Node in ch.get_buffs():
		if buff is Barkskin:
			max_level = maxi(max_level, (buff as Barkskin).level)
	return max_level

## Static helper: conditionally append or reset a barkskin buff.
## If a matching interval exists, reset it. Otherwise append a new instance.
static func conditionally_append(ch: Node, lvl: int, intvl: int) -> void:
	for buff: Node in ch.get_buffs():
		if buff is Barkskin and (buff as Barkskin).interval == intvl:
			(buff as Barkskin).set_level(lvl, intvl)
			return
	var new_bark := Barkskin.new()
	new_bark.set_level(lvl, intvl)
	ch.add_buff(new_bark)
