class_name ShockingTrap
extends Trap
## Chain lightning that arcs to nearby characters.

func _init() -> void:
	trap_name = "shocking trap"
	color = Color(1.0, 1.0, 0.3)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Lightning arcs from the trap!")

	var base_damage: int = 5 + level.depth

	# Damage the triggerer
	if triggerer != null and triggerer.has_method("take_damage"):
		triggerer.take_damage(base_damage, "shocking trap")

	# Chain lightning — find and damage nearby characters
	# Water conducts: double range on water tiles
	var affected: Array[int] = []
	affected.append(pos)

	# Scan a 5x5 area for chain targets
	var width: int = ConstantsData.WIDTH
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if dy == 0 and dx == 0:
				continue
			var cell: int = pos + dx + dy * width
			if cell < 0 or cell >= ConstantsData.LENGTH:
				continue
			if cell in affected:
				continue

			var mob: Variant = level.mob_at(cell)
			if mob != null and mob.has_method("take_damage"):
				# Water amplifies damage
				var t: int = level.terrain_at(cell)
				var chain_damage: int = base_damage / 2
				if t == ConstantsData.Terrain.WATER:
					chain_damage = base_damage
				mob.take_damage(chain_damage, "shocking trap")
				affected.append(cell)
