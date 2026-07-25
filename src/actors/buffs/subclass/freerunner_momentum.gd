class_name FreerunnerMomentum
extends Buff
## Freerunner subclass passive. Builds momentum from consecutive movement
## without attacking. At max momentum, grants evasion and speed bonuses.

var momentum: int = 0
const MAX_MOMENTUM: int = 10
## Whether the last action was a move (resets on attack/wait).
var last_was_move: bool = false

func _init() -> void:
	buff_id = "FreerunnerMomentum"
	buff_name = "Momentum"
	duration = -1.0
	icon_color = Color(0.1, 0.7, 0.9)

func on_move(_old_pos: int, _new_pos: int) -> void:
	last_was_move = true
	momentum = mini(momentum + 1, MAX_MOMENTUM)

func on_turn() -> void:
	if not last_was_move:
		# Momentum decays when not moving
		momentum = maxi(0, momentum - 3)
	last_was_move = false

func on_damage_dealt(_amount: int, _target: Node) -> void:
	# Attacking breaks momentum
	last_was_move = false
	momentum = 0

## The port's freerunning state: momentum held at the cap. Upstream freerun
## is a manually activated timer, so max momentum stands in for it here.
func is_freerunning() -> bool:
	return momentum >= MAX_MOMENTUM

func _projectile_momentum_points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level("freerunner_projectile_momentum")
	return 0

## Upstream Talent.PROJECTILE_MOMENTUM (Hero.attackSkill ranged branch):
## while freerunning, ranged accuracy *= 1 + points/2 (+50%/100%/150%).
func ranged_accuracy_multiplier() -> float:
	if is_freerunning():
		return 1.0 + 0.5 * float(_projectile_momentum_points())
	return 1.0

func modify_evasion(eva: int) -> int:
	if momentum >= MAX_MOMENTUM:
		return int(eva * 1.5)  # +50% evasion at max
	elif momentum > 0:
		var bonus: float = float(momentum) / float(MAX_MOMENTUM) * 0.5
		return int(eva * (1.0 + bonus))
	return eva

func modify_speed(speed: float) -> float:
	if momentum >= MAX_MOMENTUM:
		return speed * 1.5  # +50% speed at max
	elif momentum > 0:
		var bonus: float = float(momentum) / float(MAX_MOMENTUM) * 0.5
		return speed * (1.0 + bonus)
	return speed

func description() -> String:
	if momentum > 0:
		return "Momentum (%d/%d)" % [momentum, MAX_MOMENTUM]
	return "Momentum (still)"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["momentum"] = momentum
	data["last_was_move"] = last_was_move
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	momentum = int(data.get("momentum", momentum))
	last_was_move = bool(data.get("last_was_move", last_was_move))
