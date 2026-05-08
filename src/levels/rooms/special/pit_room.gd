class_name PitRoom
extends Room
## Pit room — large room with a chasm pit surrounding a center platform.
## Items are visible on the platform, forcing creative pathfinding.
## Paints a ring of CHASM around a center platform.

func _init() -> void:
	type = Type.SPECIAL

## Pit rooms allow 2 connections.
func max_connections(_direction: int = -1) -> int:
	return 2

func min_width() -> int:
	return 7

func min_height() -> int:
	return 7

func max_width() -> int:
	return 9

func max_height() -> int:
	return 9

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY)

	# Fill a ring of chasm around the center, leaving a 1-cell platform
	var cx: int = center_x()
	var cy: int = center_y()
	for y: int in range(top + 2, bottom - 1):
		for x: int in range(left + 2, right - 1):
			var dist: int = maxi(absi(x - cx), absi(y - cy))
			if dist >= 1 and dist <= 2:
				# Chasm ring (distance 1-2 from center)
				level.set_terrain(y * ConstantsData.WIDTH + x, ConstantsData.Terrain.CHASM)

	# Center platform stays EMPTY for the reward
	level.set_terrain(center(), ConstantsData.Terrain.PEDESTAL)

	# Walkable perimeter already set as EMPTY by fill_interior

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
