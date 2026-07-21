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
	return _trap_for_weighted_roll(randf())

func _trap_for_weighted_roll(roll: float) -> Trap:
	# Upstream PrisonLevel weights (total 32): Chilling/Shocking/Toxic/Burning/
	# PoisonDart x4, Alarm/Ooze/Gripping x2, then Confusion/Flock/Summoning/
	# Teleportation/Gateway/Geyser x1. Port maps BurningTrap->FireTrap and
	# PoisonDartTrap->PoisonTrap. Preserve source order.
	var slot: int = clampi(int(floor(roll * 32.0)), 0, 31)
	if slot < 4:
		return ChillingTrap.new()
	elif slot < 8:
		return ShockingTrap.new()
	elif slot < 12:
		return ToxicTrap.new()
	elif slot < 16:
		return FireTrap.new()
	elif slot < 20:
		return PoisonTrap.new()
	elif slot < 22:
		return AlarmTrap.new()
	elif slot < 24:
		return OozeTrap.new()
	elif slot < 26:
		return GrippingTrap.new()
	elif slot < 27:
		return ConfusionTrap.new()
	elif slot < 28:
		return FlockTrap.new()
	elif slot < 29:
		return SummoningTrap.new()
	elif slot < 30:
		return TeleportTrap.new()
	elif slot < 31:
		return GatewayTrap.new()
	else:
		return GeyserTrap.new()
