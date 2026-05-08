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

