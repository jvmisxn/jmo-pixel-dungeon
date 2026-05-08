class_name Trap
extends RefCounted
## Base trap class. Traps are placed on the level map and activate when
## a character steps on them (or triggers them remotely).
## Mirrors Shattered PD's Trap.java.

# --- Trap Properties ---
var pos: int = -1
var visible: bool = false
var active: bool = true
## If true, the trap is destroyed after one activation.
var one_shot: bool = true

## Display name for the message log.
var trap_name: String = "trap"

## The color used for procedural sprite (region-dependent).
var color: Color = Color.RED

# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

## Called when a character triggers this trap.
## [triggerer] is the actor that stepped on it (or null for remote triggers).
## [level] is the current Level.
func activate(triggerer: Variant, level: Level) -> void:
	if not active:
		return

	_do_effect(triggerer, level)

	if one_shot:
		active = false
		# Change terrain to inactive
		if pos >= 0:
			level.set_terrain(pos, ConstantsData.Terrain.INACTIVE_TRAP)

	# Emit event
	if EventBus:
		EventBus.trap_triggered.emit(pos, trap_name)

## Override in subclasses to implement the trap's effect.
func _do_effect(_triggerer: Variant, _level: Level) -> void:
	pass

# ---------------------------------------------------------------------------
# Position
# ---------------------------------------------------------------------------

func set_pos(p: int) -> void:
	pos = p

func get_pos() -> int:
	return pos

# ---------------------------------------------------------------------------
# Reveal
# ---------------------------------------------------------------------------

## Make this trap visible (e.g., from search or rogue's awareness).
func reveal(level: Level) -> void:
	visible = true
	if pos >= 0 and level.terrain_at(pos) == ConstantsData.Terrain.SECRET_TRAP:
		level.set_terrain(pos, ConstantsData.Terrain.TRAP)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"type": trap_name,
		"pos": pos,
		"visible": visible,
		"active": active,
	}

func _to_string() -> String:
	return "%s at %d" % [trap_name, pos]
