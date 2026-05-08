class_name FrostTrap
extends Trap
## Freezes the victim and freezes adjacent water tiles.

func _init() -> void:
	trap_name = "frost trap"
	color = Color(0.3, 0.5, 1.0)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A wave of frost erupts!")

	# Freeze the triggerer
	if triggerer != null and triggerer.has_method("add_buff"):
		var freeze: Frozen = Frozen.new()
		var dur: float = 5.0 + float(level.depth) * 0.5
		freeze.duration = dur
		freeze.time_left = dur
		triggerer.add_buff(freeze)

	# Deal cold damage
	if triggerer != null and triggerer.has_method("take_damage"):
		@warning_ignore("integer_division")
		var damage: int = 3 + level.depth / 2
		triggerer.take_damage(damage, "frost trap")

	# Freeze adjacent water and damage nearby mobs
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj < 0 or adj >= Level.LEN:
			continue

		# Freeze water tiles
		var t: int = level.terrain_at(adj)
		if t == ConstantsData.Terrain.WATER:
			level.set_terrain(adj, ConstantsData.Terrain.EMPTY)

		# Freeze adjacent mobs too
		var mob: Variant = level.mob_at(adj)
		if mob != null and mob.has_method("add_buff"):
			var mob_freeze: Frozen = Frozen.new()
			mob_freeze.duration = 3.0
			mob_freeze.time_left = 3.0
			mob.add_buff(mob_freeze)
