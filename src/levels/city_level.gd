class_name CityLevel
extends RegularLevel
## Dwarf City region levels (depths 16-19). Grand halls and architecture.

func _init() -> void:
	num_standard_rooms = 7 + randi_range(0, 2)
	num_connection_rooms = 3 + randi_range(0, 2)

func _roll_feeling() -> void:
	var roll: float = randf()
	if roll < 0.20:
		feeling = Feeling.DARK
	elif roll < 0.30:
		feeling = Feeling.LARGE
		num_standard_rooms += 2
	elif roll < 0.40:
		feeling = Feeling.TRAPS
	elif roll < 0.45:
		feeling = Feeling.SECRETS
		num_secret_rooms += 1
	else:
		feeling = Feeling.NONE

func _create_special_rooms() -> Array[Room]:
	var result: Array[Room] = []
	# ShopRoom is now guaranteed on shop floors (16, 21) via _is_shop_floor() in base class.
	# Don't add a second random one here.
	if randf() < 0.4:
		result.append(LibraryRoom.new())
	if randf() < 0.3:
		result.append(LaboratoryRoom.new())
	if randf() < 0.25:
		result.append(StatueRoom.new())
	if randf() < 0.2:
		result.append(CrystalVaultRoom.new())
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
	# Upstream CityLevel weights: Frost/Storm/Corrosion/Blazing/Disintegration x4,
	# Rockfall/Flashing/Guardian/Weakening x2, then rare utility/lethal traps.
	# Omit only trap classes not present in this port and preserve source order.
	var slot: int = clampi(int(floor(roll * 29.0)), 0, 28)
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
	elif slot < 24:
		return WeakeningTrap.new()
	elif slot < 25:
		return DisarmingTrap.new()
	elif slot < 26:
		return SummoningTrap.new()
	elif slot < 27:
		return WarpingTrap.new()
	elif slot < 28:
		return CursingTrap.new()
	else:
		return PitfallTrap.new()
