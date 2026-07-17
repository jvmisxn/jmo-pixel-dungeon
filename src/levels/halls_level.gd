class_name HallsLevel
extends RegularLevel
## Demon Halls region levels (depths 21-24). Dangerous and fiery.

func _init() -> void:
	# Original: 8-9 standard rooms (average 8.33), not 5-7
	num_standard_rooms = 8 + randi_range(0, 1)
	num_connection_rooms = 2 + randi_range(0, 2)
	# TODO: Original reduces view_distance = min(26-depth, viewDistance) in Halls.
	# Needs a per-level view_distance field on Level class to implement.

func _roll_feeling() -> void:
	# Original HallsLevel does NOT have a CHASM feeling in random rolls.
	var roll: float = randf()
	if roll < 0.25:
		feeling = Feeling.DARK
	elif roll < 0.40:
		feeling = Feeling.TRAPS
	elif roll < 0.50:
		feeling = Feeling.LARGE
		num_standard_rooms += 2
	else:
		feeling = Feeling.NONE

func _create_special_rooms() -> Array[Room]:
	var result: Array[Room] = []
	if randf() < 0.4:
		result.append(TrapRoom.new())
	if randf() < 0.3:
		result.append(VaultRoom.new())
	if randf() < 0.3:
		result.append(SacrificeRoom.new())
	if randf() < 0.25:
		result.append(PitRoom.new())
	if randf() < 0.2:
		result.append(WeakFloorRoom.new())
	return result

func _create_secret_room() -> Room:
	var roll: float = randf()
	if roll < 0.35:
		return SecretLibraryRoom.new()
	elif roll < 0.65:
		return SecretRoom.new()
	else:
		return SecretWellRoom.new()

func _create_random_trap() -> Trap:
	return _trap_for_weighted_roll(randf())

func _trap_for_weighted_roll(roll: float) -> Trap:
	# Original Halls trap weights are mostly late-game lethal traps. This port
	# uses the implemented subset and preserves their relative source weights.
	var slot: int = clampi(int(floor(roll * 28.0)), 0, 27)
	if slot < 4:
		return FrostTrap.new()
	elif slot < 8:
		return StormTrap.new()
	elif slot < 12:
		return CorrosionTrap.new()
	elif slot < 16:
		return BlazingTrap.new()
	elif slot < 18:
		return RockfallTrap.new()
	elif slot < 20:
		return FlashingTrap.new()
	elif slot < 22:
		return GuardianTrap.new()
	elif slot < 23:
		return DisarmingTrap.new()
	elif slot < 24:
		return SummoningTrap.new()
	elif slot < 25:
		return WarpingTrap.new()
	elif slot < 26:
		return CursingTrap.new()
	elif slot < 27:
		return GrimTrap.new()
	else:
		return PitfallTrap.new()
