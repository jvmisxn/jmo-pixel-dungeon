class_name SewerLevel
extends RegularLevel
## Sewer region levels (depths 1-4). Damp and mossy, with water and grass.

func _init() -> void:
	num_standard_rooms = 5 + randi_range(0, 2)
	num_connection_rooms = 2 + randi_range(0, 2)

func _roll_feeling() -> void:
	# Sewers favor water and grass feelings
	var roll: float = randf()
	if roll < 0.25:
		feeling = Feeling.WATER
	elif roll < 0.40:
		feeling = Feeling.GRASS
	elif depth >= 3 and roll < 0.45:
		feeling = Feeling.DARK
	else:
		feeling = Feeling.NONE

func _create_special_rooms() -> Array[Room]:
	var result: Array[Room] = []
	if depth >= 3 and randf() < 0.5:
		result.append(GardenRoom.new())
	if depth >= 2 and randf() < 0.3:
		result.append(PoolRoom.new())
	if depth >= 3 and randf() < 0.3:
		result.append(RotGardenRoom.new())
	if randf() < 0.25:
		result.append(MagicWellRoom.new())
	return result

func _create_secret_room() -> Room:
	# Original always creates secret rooms (secretsForFloor determines count).
	# Don't gate behind random chance — the count is already controlled by num_secret_rooms.
	var roll: float = randf()
	if roll < 0.4:
		return SecretGardenRoom.new()
	elif roll < 0.7:
		return SecretWellRoom.new()
	else:
		return SecretRoom.new()

func _create_random_trap() -> Trap:
	# Original: floor 1 only has WornDartTrap
	if depth <= 1:
		return WornDartTrap.new()
	# Original Sewer trap pool: WornDartTrap, PoisonTrap, AlarmTrap
	var trap_pool: Array[Trap] = [
		WornDartTrap.new(),
		PoisonTrap.new(),
		AlarmTrap.new(),
	]
	return trap_pool[randi_range(0, trap_pool.size() - 1)]
