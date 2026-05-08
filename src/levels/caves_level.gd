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
	var roll: float = randf()
	if roll < 0.25:
		return RockfallTrap.new()
	elif roll < 0.45:
		return PoisonTrap.new()
	elif roll < 0.65:
		return ExplosiveTrap.new()
	elif roll < 0.85:
		return CorrosionTrap.new()
	else:
		return StormTrap.new()
