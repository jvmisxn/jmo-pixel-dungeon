class_name PitRoom
extends Room
## Pit room — sealed special room the hero falls into from a weak floor above.
## Upstream PitRoom.java: crystal door entrance, an empty well on the wall
## opposite the entrance, and a skeleton heap at the centre holding the main
## loot, 1-2 minor prizes, and the crystal key that opens the door from inside.

func _init() -> void:
	type = Type.SPECIAL

## Special rooms have a single entrance.
## Matches original SpecialRoom.maxConnections() = 1.
func max_connections(_direction: int = -1) -> int:
	return 1

## Upstream: min size raised to 6 to prevent tiny wraith fights.
func min_width() -> int:
	return 6

func min_height() -> int:
	return 6

## Upstream: max size reduced to 9 so the well stays visible from the door.
func max_width() -> int:
	return 9

func max_height() -> int:
	return 9

## Upstream canPlaceTrap: the player is already weak after landing,
## having traps here just seems unfair.
func can_place_trap(_pos: int) -> bool:
	return false

## Upstream canPlaceGrass: keep the well visible through the crystal door.
func can_place_grass(_pos: int) -> bool:
	return false

## Upstream SpecialRoom: no water patches inside special rooms.
func can_place_water(_pos: int) -> bool:
	return false

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY)

	# Crystal door entrance (upstream entrance().set(Door.Type.CRYSTAL))
	var entrance_pos: int = -1
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.CRYSTAL_DOOR)
			if entrance_pos < 0:
				entrance_pos = door_pos

	_paint_well(level, entrance_pos)

	# Skeleton remains at the centre: main loot, 1-2 prizes, and the
	# crystal key that opens the door from the inside.
	var remains: int = center()
	level.drop_item(remains, _main_loot(level.depth), "skeleton")
	var n: int = randi_range(1, 2)
	for _i: int in range(n):
		level.drop_item(remains, _prize(level.depth))
	var key: Key = Key.create("crystal_key")
	key.depth = level.depth
	level.drop_item(remains, key)

	painted = true

## Place the empty well against the wall opposite the entrance
## (upstream picks one of the two corners-adjacent cells at random).
func _paint_well(level: Level, entrance_pos: int) -> void:
	if entrance_pos < 0:
		return
	var ex: int = ConstantsData.pos_to_x(entrance_pos)
	var ey: int = ConstantsData.pos_to_y(entrance_pos)
	var wx: int = -1
	var wy: int = -1
	if ex == left:
		wx = right - 1
		wy = top + 1 if randi_range(0, 1) == 0 else bottom - 1
	elif ex == right:
		wx = left + 1
		wy = top + 1 if randi_range(0, 1) == 0 else bottom - 1
	elif ey == top:
		wx = left + 1 if randi_range(0, 1) == 0 else right - 1
		wy = bottom - 1
	elif ey == bottom:
		wx = left + 1 if randi_range(0, 1) == 0 else right - 1
		wy = top + 1
	if wx < 0 or wy < 0:
		return
	level.set_terrain(wy * ConstantsData.WIDTH + wx, ConstantsData.Terrain.EMPTY_WELL)

## Main skeleton loot (upstream: 1/3 ring, 1/3 artifact,
## 1/3 one of weapon/weapon/missile/armor/armor).
func _main_loot(depth: int) -> Item:
	match randi_range(0, 2):
		0:
			return Generator.random_ring()
		1:
			return Generator.random_artifact()
		_:
			match randi_range(0, 4):
				0, 1:
					return Generator.random_weapon(depth)
				2:
					return Generator.random_missile(depth)
				_:
					return Generator.random_armor(depth)

## Minor prize (upstream: one of potion/scroll/food/gold).
func _prize(depth: int) -> Item:
	match randi_range(0, 3):
		0:
			return Generator.random_potion()
		1:
			return Generator.random_scroll()
		2:
			return Generator.random_food()
		_:
			return Generator.random_gold(depth)
