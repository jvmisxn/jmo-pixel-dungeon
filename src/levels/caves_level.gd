class_name CavesLevel
extends RegularLevel
## Caves region levels (depths 11-14). Open caverns, chasms, water.

func _init() -> void:
	num_standard_rooms = 6 + randi_range(0, 3)
	num_connection_rooms = 3 + randi_range(0, 2)

func _roll_feeling() -> void:
	# Original CavesLevel does NOT have a CHASM feeling in random rolls.
	# CHASM is only used in specific hardcoded levels (DeadEndLevel).
	var roll: float = randf()
	if roll < 0.20:
		feeling = Feeling.WATER
	elif roll < 0.35:
		feeling = Feeling.LARGE
		num_standard_rooms += 2
	elif roll < 0.45:
		feeling = Feeling.DARK
	elif roll < 0.50:
		feeling = Feeling.TRAPS
	else:
		feeling = Feeling.NONE

func _create_special_rooms() -> Array[Room]:
	var result: Array[Room] = []
	if randf() < 0.4:
		result.append(VaultRoom.new())
	if randf() < 0.4:
		result.append(PoolRoom.new())
	if randf() < 0.3:
		result.append(TrapRoom.new())
	if randf() < 0.3:
		result.append(PitRoom.new())
	if randf() < 0.25:
		result.append(CrystalVaultRoom.new())
	if randf() < 0.2:
		result.append(WeakFloorRoom.new())
	return result

func _create_secret_room() -> Room:
	var roll: float = randf()
	if roll < 0.35:
		return SecretWellRoom.new()
	elif roll < 0.7:
		return SecretRoom.new()
	else:
		return SecretGardenRoom.new()

func _create_random_trap() -> Trap:
	return _trap_for_weighted_roll(randf())

func _trap_for_weighted_roll(roll: float) -> Trap:
	# Upstream CavesLevel weights: Burning/PoisonDart/Frost/Storm/Corrosion x4,
	# Gripping/Rockfall/Guardian x2, then rare utility/depth traps. Omit only
	# classes not present in this port and preserve source order.
	var slot: int = clampi(int(floor(roll * 29.0)), 0, 28)
	if slot < 4:
		return FireTrap.new()
	elif slot < 8:
		return PoisonTrap.new()
	elif slot < 12:
		return FrostTrap.new()
	elif slot < 16:
		return StormTrap.new()
	elif slot < 20:
		return CorrosionTrap.new()
	elif slot < 22:
		return GrippingTrap.new()
	elif slot < 24:
		return RockfallTrap.new()
	elif slot < 26:
		return GuardianTrap.new()
	elif slot < 27:
		return SummoningTrap.new()
	elif slot < 28:
		return WarpingTrap.new()
	else:
		return PitfallTrap.new()
