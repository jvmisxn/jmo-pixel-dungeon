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
	_grant_natures_aid(level)
	_do_effect(char, level)
	# Remove the plant from the level after activation
	if level and level.get("plants") is Dictionary:
		level.plants.erase(pos)
	# Revert terrain to grass
	if level and level.has_method("set_terrain") and pos >= 0:
		level.set_terrain(pos, ConstantsData.Terrain.GRASS)
	if EventBus:
		EventBus.plant_activated.emit(pos, plant_name)
	if MessageLog:
		MessageLog.add("The %s activates!" % plant_name)

## Override in subclasses to implement the plant's effect.
func _do_effect(_char: Variant, _level: Variant) -> void:
	pass

## SPD Plant.trigger(): any plant triggering within the hero's FOV grants
## Nature's Aid barkskin — level 2 for 3/5 turns (interval 1 + 2*points).
## Co-op adaptation: upstream checks the single Dungeon.hero; here every party
## hero with the talent benefits when the plant cell is currently visible.
func _grant_natures_aid(level: Variant) -> void:
	if level == null or pos < 0:
		return
	var visible: Variant = level.get("visible")
	if not (visible is Array) or pos >= (visible as Array).size() or not visible[pos]:
		return
	if GameManager == null or not GameManager.has_method("get_active_heroes"):
		return
	for hero: Node in GameManager.get_active_heroes():
		if hero == null or not hero.has_method("get_talent_level"):
			continue
		var points: int = hero.get_talent_level("huntress_natures_aid")
		if points > 0:
			Barkskin.conditionally_append(hero, 2, 1 + 2 * points)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"_script_path": get_script().resource_path,
		"type": plant_id,
		"pos": pos,
	}

func deserialize(data: Dictionary) -> void:
	plant_id = data.get("type", plant_id)
	pos = data.get("pos", pos)

func _to_string() -> String:
	return "%s at %d" % [plant_name, pos]
