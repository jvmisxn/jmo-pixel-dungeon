class_name PrisonLevel
extends RegularLevel
## Prison region levels (depths 6-9). Stone corridors with barricades.

func _init() -> void:
	num_standard_rooms = 6 + randi_range(0, 2)
	num_connection_rooms = 3 + randi_range(0, 2)

func _roll_feeling() -> void:
	var roll: float = randf()
	if roll < 0.20:
		feeling = Feeling.DARK
	elif roll < 0.35:
		feeling = Feeling.TRAPS
	elif roll < 0.45:
		feeling = Feeling.GRASS
	else:
		feeling = Feeling.NONE

func _create_special_rooms() -> Array[Room]:
	var result: Array[Room] = []
	if randf() < 0.5:
		result.append(LibraryRoom.new())
	if randf() < 0.3:
		result.append(ArmoryRoom.new())
	if depth >= 8 and randf() < 0.4:
		result.append(LaboratoryRoom.new())
	if randf() < 0.25:
		result.append(WeakFloorRoom.new())
	if randf() < 0.2:
		result.append(StatueRoom.new())
	return result

func _create_secret_room() -> Room:
	var roll: float = randf()
	if roll < 0.4:
		return SecretLibraryRoom.new()
	elif roll < 0.7:
		return SecretRoom.new()
	else:
		return SecretWellRoom.new()

func _create_random_trap() -> Trap:
	# Original PrisonLevel trapClasses with weights:
	# ChillingTrap(4), ShockingTrap(4), ToxicTrap/PoisonTrap(4), BurningTrap/FireTrap(4),
	# ParalyticTrap(2), AlarmTrap(2), GrippingTrap(2)
	var roll: float = randf()
	if roll < 0.1818:
		return ChillingTrap.new()
	elif roll < 0.3636:
		return ShockingTrap.new()
	elif roll < 0.5455:
		return PoisonTrap.new()
	elif roll < 0.7273:
		return FireTrap.new()
	elif roll < 0.8182:
		return ParalyticTrap.new()
	elif roll < 0.9091:
		return AlarmTrap.new()
	else:
		return GrippingTrap.new()
