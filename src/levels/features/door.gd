class_name Door
extends RefCounted
## Door interaction logic. Handles opening doors, locked doors, and secret doors.

# ---------------------------------------------------------------------------
# Door Actions
# ---------------------------------------------------------------------------

## Attempt to open a door at [pos]. Returns true if the door was opened.
static func open(level: Level, pos: int, opener: Variant = null) -> bool:
	var terrain: int = level.terrain_at(pos)

	match terrain:
		ConstantsData.Terrain.DOOR:
			level.set_terrain(pos, ConstantsData.Terrain.OPEN_DOOR)
			if EventBus:
				EventBus.door_opened.emit(pos)
			if GameManager:
				GameManager.record_stat("doors_opened")
			return true

		ConstantsData.Terrain.LOCKED_DOOR:
			# Check if opener has a key
			if opener != null and opener.has_method("has_key"):
				if opener.has_key("golden"):
					opener.use_key("golden")
					level.set_terrain(pos, ConstantsData.Terrain.OPEN_DOOR)
					if EventBus:
						EventBus.door_opened.emit(pos)
					if GameManager:
						GameManager.record_stat("doors_opened")
					if MessageLog:
						MessageLog.add("You unlock the door.")
					return true
				else:
					if MessageLog:
						MessageLog.add("The door is locked.")
					return false
			else:
				if MessageLog:
					MessageLog.add("The door is locked.")
				return false

		ConstantsData.Terrain.CRYSTAL_DOOR:
			if opener != null and opener.has_method("has_key"):
				if opener.has_key("crystal"):
					opener.use_key("crystal")
					level.set_terrain(pos, ConstantsData.Terrain.OPEN_DOOR)
					if EventBus:
						EventBus.door_opened.emit(pos)
					if MessageLog:
						MessageLog.add("The crystal door shatters open.")
					return true
				else:
					if MessageLog:
						MessageLog.add("The crystal door is sealed.")
					return false
			return false

		ConstantsData.Terrain.SECRET_DOOR:
			# Secret doors are revealed when searched
			level.set_terrain(pos, ConstantsData.Terrain.DOOR)
			if MessageLog:
				MessageLog.add("You discover a hidden door!")
			return false  # Revealed but not opened yet

		ConstantsData.Terrain.OPEN_DOOR:
			return true  # Already open

	return false

## Close an open door.
static func close(level: Level, pos: int) -> bool:
	if level.terrain_at(pos) == ConstantsData.Terrain.OPEN_DOOR:
		# Check no mob or hero is standing in the door
		if level.mob_at(pos) != null:
			return false
		level.set_terrain(pos, ConstantsData.Terrain.DOOR)
		return true
	return false

## Search adjacent cells for secret doors. Called when hero uses the search action.
static func search(level: Level, hero_pos: int) -> int:
	var found: int = 0
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = hero_pos + dir
		if adj < 0 or adj >= Level.LEN:
			continue
		if level.terrain_at(adj) == ConstantsData.Terrain.SECRET_DOOR:
			level.set_terrain(adj, ConstantsData.Terrain.DOOR)
			found += 1
			if MessageLog:
				MessageLog.add("You discover a hidden door!")
		elif level.terrain_at(adj) == ConstantsData.Terrain.SECRET_TRAP:
			# Reveal hidden traps too
			level.set_terrain(adj, ConstantsData.Terrain.TRAP)
			var trap: Variant = level.trap_at(adj)
			if trap != null and trap.has_method("reveal"):
				trap.reveal(level)
			found += 1
	return found
