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
	var roll: float = randf()
	if roll < 0.20:
		return FlashingTrap.new()
	elif roll < 0.40:
		return GuardianTrap.new()
	elif roll < 0.60:
		return WarpingTrap.new()
	elif roll < 0.80:
		return SummoningTrap.new()
	else:
		return GrimTrap.new()
