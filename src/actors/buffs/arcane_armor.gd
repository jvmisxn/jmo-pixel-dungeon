class_name ArcaneArmor
extends Buff
## ArcaneArmor buff: reduces magic damage by a level-based amount.
## Original (ArcaneArmor.java): "A magical version of barkskin, essentially."
## Level decays by 1 each interval. DR applied as NormalIntRange(0, level)
## against magic damage sources.
## Sources: Wand of Living Earth, AntiMagic glyph, Shield of Light talent.

var level: int = 0
var interval: int = 1

func _init() -> void:
	buff_id = "ArcaneArmor"
	buff_name = "Arcane Armor"
	buff_type = BuffType.POSITIVE
	duration = -1.0  # managed by level decay
	time_left = -1.0
	icon_color = Color(0.6, 0.3, 1.0)

## Set arcane armor level and interval.
## Original uses sqrt(interval)*level comparison to decide whether to override.
func set_level(value: int, time: int) -> void:
	if sqrt(interval) * level < sqrt(time) * value:
		level = value
		interval = time

## Delay the next tick.
func delay(value: float) -> void:
	pass

func on_turn() -> void:
	if target == null or not target.is_alive:
		if target:
			target.remove_buff(self)
		return
	level -= 1
	if level <= 0:
		if target:
			target.remove_buff(self)

func get_level() -> int:
	return level

## Returns a DR roll against magic damage: triangular distribution [0, level].
func dr_roll() -> int:
	if level <= 0:
		return 0
	# Approximate NormalIntRange(0, level) with triangular distribution
	var a: int = randi_range(0, level)
	var b: int = randi_range(0, level)
	@warning_ignore("integer_division")
	return (a + b) / 2

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
	return "Protected by arcane armor (up to +%d magic DR)." % level
