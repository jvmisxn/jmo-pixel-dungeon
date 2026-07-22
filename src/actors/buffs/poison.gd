class_name Poison
extends Buff
## Deals damage each turn based on remaining duration: (left/3)+1 per tick.
## Total damage over full duration is roughly duration^2/6.

func _init() -> void:
	buff_id = "Poison"
	buff_name = "Poison"
	buff_type = BuffType.NEGATIVE
	icon_color = Color(0.5, 0.0, 0.8)

## Set poison duration (takes the higher of current vs new).
func set_level(amount: float) -> void:
	time_left = maxf(time_left, amount)
	duration = maxf(duration, amount)

## Extend poison by adding duration.
func extend(amount: float) -> void:
	time_left += amount
	duration = maxf(duration, time_left)

static func create(amount: float) -> Poison:
	var p: Poison = Poison.new()
	p.duration = amount
	p.time_left = amount
	return p

## SPD `Poison.act()` deals damage using `left` *before* decrementing it
## (`target.damage((int)(left/3)+1, this); left -= TICK;`). The base `Buff.act()`
## decrements `time_left` first and then calls `on_turn()`, which would make every
## tick read a value one lower than upstream and shave ~1 damage-tier off the whole
## duration (e.g. a 10-turn poison dealt 22 instead of 25). Mirror SPD by damaging
## with the current `time_left` first, then applying the base decrement.
func act() -> void:
	on_turn()
	if duration > 0:
		time_left -= 1.0

func on_turn() -> void:
	if target == null:
		return
	# Original formula: (int)(left / 3) + 1
	# At 10 turns left -> 4 dmg, at 3 -> 2, at 1 -> 1
	var dmg: int = int(time_left / 3.0) + 1
	target.take_damage(dmg, self)
	if MessageLog:
		var target_name: String = "You" if target.get("is_hero") else target.get("mob_name") if target.get("mob_name") else "Something"
		MessageLog.add_negative("%s takes %d poison damage." % [target_name, dmg])

func description() -> String:
	return "Poisoned! Taking increasing damage each turn."
