class_name Plant
extends RefCounted
## Base class for all plants. Plants occupy a cell on the level map and
## activate when a character steps on them (or when otherwise triggered).
## Mirrors Shattered PD's Plant.java.

# --- Properties ---
var plant_id: String = "Plant"
var plant_name: String = "Plant"
var pos: int = -1

# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

## Called when a character steps on this plant or it is otherwise triggered.
## [char] is the character that triggered it (Char or subclass).
## [level] is the current Level instance.
func activate(char: Variant, level: Variant) -> void:
	_do_effect(char, level)
	# Remove the plant from the level after activation
	if level and level.get("plants") is Dictionary:
		level.plants.erase(pos)
	# Revert terrain to grass
	if level and level.has_method("set_terrain") and pos >= 0:
		level.set_terrain(pos, ConstantsData.Terrain.GRASS)
	if MessageLog:
		MessageLog.add("The %s activates!" % plant_name)

## Override in subclasses to implement the plant's effect.
func _do_effect(_char: Variant, _level: Variant) -> void:
	pass

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"type": plant_id,
		"pos": pos,
	}

func deserialize(data: Dictionary) -> void:
	plant_id = data.get("type", plant_id)
	pos = data.get("pos", pos)

func _to_string() -> String:
	return "%s at %d" % [plant_name, pos]
