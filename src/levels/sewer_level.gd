class_name SewerLevel
extends RegularLevel
## Sewer region levels (depths 1-4). Damp and mossy, with water and grass.

const OozeTrapScript := preload("res://src/levels/traps/ooze_trap.gd")
const ToxicTrapScript := preload("res://src/levels/traps/toxic_trap.gd")

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
	return _trap_for_weighted_roll(randf())

func _trap_for_weighted_roll(roll: float) -> Trap:
	# Upstream SewerLevel weights after floor 1: Chilling/Shocking/Toxic/
	# WornDart x4, Alarm/Ooze x2, then Confusion/Flock/Summoning/
	# Teleportation/Gateway x1. Preserve source order.
	var slot: int = clampi(int(floor(roll * 25.0)), 0, 24)
	if slot < 4:
		return ChillingTrap.new()
	elif slot < 8:
		return ShockingTrap.new()
	elif slot < 12:
		return ToxicTrapScript.new()
	elif slot < 16:
		return WornDartTrap.new()
	elif slot < 18:
		return AlarmTrap.new()
	elif slot < 20:
		return OozeTrapScript.new()
	elif slot < 21:
		return ConfusionTrap.new()
	elif slot < 22:
		return FlockTrap.new()
	elif slot < 23:
		return SummoningTrap.new()
	elif slot < 24:
		return TeleportTrap.new()
	else:
		return GatewayTrap.new()
