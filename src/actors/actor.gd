class_name Actor
extends Node
## Base class for all entities that participate in the turn system.
## Actors have energy-based timing and register with TurnManager.

## Whether this actor is currently active in the turn system.
var active: bool = false
## Position in the level (flat index into the tile array).
var pos: int = -1
## The level this actor belongs to.
var level: Variant = null  # Level reference (untyped to avoid circular dependency)

# --- Turn System Integration ---

## Called by TurnManager when it's this actor's turn.
## Subclasses MUST override this and call spend_turn() when done.
func act() -> void:
	spend_turn()

## How fast this actor is. 1.0 = normal speed.
func get_speed() -> float:
	return 1.0

## Spend a standard turn's worth of energy.
func spend_turn(speed_factor: float = 1.0) -> void:
	if TurnManager:
		TurnManager.spend_energy(self, speed_factor)

## Register this actor with the turn system.
func activate() -> void:
	if active:
		return
	active = true
	if TurnManager:
		TurnManager.register_actor(self)

## Remove this actor from the turn system.
func deactivate() -> void:
	if not active:
		return
	active = false
	if TurnManager:
		TurnManager.remove_actor(self)

## Serialize base actor state.
func serialize_actor() -> Dictionary:
	return {
		"pos": pos,
		"active": active,
	}

## Deserialize base actor state.
func deserialize_actor(data: Dictionary) -> void:
	pos = data.get("pos", -1)
	active = data.get("active", false)

## Serialize state (base implementation for subclass super calls).
func serialize() -> Dictionary:
	return serialize_actor()

# ---------------------------------------------------------------------------
# Spatial Helpers
# ---------------------------------------------------------------------------

## Chebyshev distance (king-move distance) from this actor's position to a cell.
func distance_to(target_pos: int) -> int:
	var ax: int = ConstantsData.pos_to_x(pos)
	var ay: int = ConstantsData.pos_to_y(pos)
	var bx: int = ConstantsData.pos_to_x(target_pos)
	var by: int = ConstantsData.pos_to_y(target_pos)
	return maxi(absi(ax - bx), absi(ay - by))

## Whether this actor is adjacent (Chebyshev distance == 1) to a cell.
func is_adjacent(target_pos: int) -> bool:
	return distance_to(target_pos) == 1

## Whether this actor can see a given cell. Base implementation uses
## level LOS if available, otherwise distance check. Char overrides
## to add Blindness handling.
func can_see(target_pos: int) -> bool:
	if pos == target_pos:
		return true
	if level and level.has_method("has_los"):
		return level.has_los(pos, target_pos)
	return distance_to(target_pos) <= 8
