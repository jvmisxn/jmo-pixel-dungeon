class_name Burning
extends Buff
## Deals fire damage each turn, can spread fire to flammable terrain.
## Extinguished by water. Removes Frozen/Chill on attach.

const DURATION: float = 8.0

var left: float = DURATION
var acted: bool = false  # whether the debuff has dealt any damage yet
var burn_increment: int = 0  # tracks hero item burning chance

func _init() -> void:
	buff_id = "Burning"
	buff_name = "Burning"
	buff_type = BuffType.NEGATIVE
	announced = true
	duration = -1.0  # managed by 'left', not base duration system
	time_left = -1.0
	icon_color = Color(1.0, 0.5, 0.0)

func on_attach() -> void:
	# Burning removes Chill (and Frozen handles its own removal of Burning)
	if target:
		var chill_buff: Node = target.get_buff("Chill")
		if chill_buff:
			target.remove_buff(chill_buff)

func on_turn() -> void:
	if target == null:
		return

	# If already acted and standing in water (not flying), extinguish
	if acted and _is_in_water() and not _is_flying():
		if target:
			target.remove_buff(self)
		return

	if target.is_alive and not target.is_immune("Burning"):
		acted = true
		# Original: Random.NormalIntRange(1, 3 + scalingDepth/4)
		var depth: int = 1
		if GameManager:
			depth = maxi(1, GameManager.depth)
		@warning_ignore("integer_division")
		var max_dmg: int = 3 + depth / 4
		var dmg: int = randi_range(1, maxi(1, max_dmg))
		target.take_damage(dmg, self, "fire")
		if MessageLog:
			MessageLog.add_negative("%s is burning! (%d dmg)" % [target.mob_name, dmg])

	left -= 1.0
	if left <= 0.0:
		if target:
			target.remove_buff(self)

func _is_in_water() -> bool:
	if target == null:
		return false
	var pos: int = target.pos
	if pos < 0:
		return false
	if target.get("level") != null:
		var lvl: Variant = target.level
		if lvl and lvl.has_method("get_terrain"):
			return lvl.get_terrain(pos) == ConstantsData.Terrain.WATER
	return false

func _is_flying() -> bool:
	if target == null:
		return false
	if target.has_method("is_flying"):
		return target.is_flying()
	return false

func description() -> String:
	return "On fire! Taking fire damage each turn. Water extinguishes the flames."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["left"] = left
	data["acted"] = acted
	data["burn_increment"] = burn_increment
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	left = float(data.get("left", left))
	acted = bool(data.get("acted", acted))
	burn_increment = int(data.get("burn_increment", burn_increment))
