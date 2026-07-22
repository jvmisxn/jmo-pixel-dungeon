class_name BlazingTrap
extends Trap
## Seeds a large Fire blob, mirroring Shattered Pixel Dungeon's BlazingTrap.
##
## Upstream flood-fills non-solid cells out to distance 2, seeding strong fire
## on normal cells and weak fire on water/pit cells. The blob timeline owns the
## Burning application and terrain ignition.

const FIRE_AMOUNT: float = 5.0
const WATER_OR_PIT_FIRE_AMOUNT: float = 1.0

func _init() -> void:
	trap_name = "blazing trap"
	color = Color(1.0, 0.3, 0.0)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A blazing inferno erupts!")
	if level == null:
		return
	for cell: int in _non_solid_radius_cells(level, 2):
		var amount: float = FIRE_AMOUNT
		var terrain: int = level.terrain_at(cell)
		if terrain == ConstantsData.Terrain.WATER or terrain == ConstantsData.Terrain.CHASM:
			amount = WATER_OR_PIT_FIRE_AMOUNT
		level.add_blob(FireBlob.new(), cell, amount)

func _non_solid_radius_cells(level: Level, radius: int) -> Array[int]:
	var result: Array[int] = []
	if not ConstantsData.is_valid_pos(pos):
		return result
	var cx: int = ConstantsData.pos_to_x(pos)
	var cy: int = ConstantsData.pos_to_y(pos)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or x >= ConstantsData.WIDTH or y < 0 or y >= ConstantsData.HEIGHT:
				continue
			var cell: int = ConstantsData.xy_to_pos(x, y)
			if ConstantsData.terrain_is_solid(level.terrain_at(cell)):
				continue
			result.append(cell)
	return result
