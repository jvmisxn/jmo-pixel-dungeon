class_name Chill
extends Buff
## Chill debuff: slows the target proportional to remaining duration.
## Original: reduces speed by 10% per turn remaining, capping at 50%.
## Applied through spend_turn() time scaling, not speed().
## At 10+ turns of chill, converts to full Frost (Frozen).
## Stacks additively — each application extends duration.
## Removes Burning on attach (fire and ice cancel each other).

const DURATION: float = 10.0  # Original: DURATION = 10f

var left: float = 0.0

func _init() -> void:
	buff_id = "Chill"
	buff_name = "Chilled"
	buff_type = BuffType.NEGATIVE
	announced = true
	duration = -1.0  # managed by 'left'
	time_left = -1.0
	icon_color = Color(0.4, 0.7, 1.0)

func set_level(dur: float) -> void:
	left = maxf(left, dur)

func extend(dur: float) -> void:
	left += dur

## Speed multiplier: reduces speed by 10% per turn remaining, capping at 50%.
## Original formula: max(0.5f, 1 - cooldown()*0.1f)
func speed_factor() -> float:
	return maxf(0.5, 1.0 - left * 0.1)

## NOTE: Chill does NOT modify speed() — it works through time scaling in
## spend_turn() via speed_factor(). Slow and Chill don't stack (original).
## Do NOT add modify_speed() here — it would double-apply the slowdown.

func on_attach() -> void:
	# Original: Chill removes Burning on attach
	if target:
		var burn: Node = target.get_buff("Burning")
		if burn:
			target.remove_buff(burn)
	if MessageLog and target:
		MessageLog.add_negative("%s is chilled!" % target.name)

func on_turn() -> void:
	if target == null:
		return

	# If chill exceeds threshold, upgrade to full Frozen
	# Use load() to avoid Chill↔Frozen circular parse dependency
	if left >= 10.0:
		if target:
			var frozen: Node = load("res://src/actors/buffs/frozen.gd").new()
			target.add_buff(frozen)
			target.remove_buff(self)
		return

	left -= 1.0
	if left <= 0.0:
		if target:
			target.remove_buff(self)

func merge(other: Node) -> void:
	if other is Chill:
		# Additive stacking (original extends duration)
		extend((other as Chill).left)
	else:
		super.merge(other)
