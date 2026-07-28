class_name GuardTracker
extends Buff
## Duelist shield Guard stance. Original: RoundShield.GuardTracker.
## While active the hero blocks all incoming attacks (upstream
## Hero.defenseSkill returns INFINITE_EVASION); the first block is
## announced and tracked (upstream tints the buff icon).

var has_blocked: bool = false

func _init() -> void:
	buff_id = "GuardTracker"
	buff_name = "Guard"
	buff_type = BuffType.POSITIVE
	announced = true

## Large enough that multiplicative debuff modifiers applied after this one
## cannot pull the result back under Char.hit's infinite-evasion threshold.
func evasion_modifier(_eva: int) -> int:
	return 1000000000

## Char's miss path notifies defender buffs with amount 0; while guarding,
## every incoming attack misses, so a 0 here is a block (upstream
## Hero.defenseVerb sets hasBlocked and reports "guarded").
func on_damage_taken(amount: int, _source: Variant) -> void:
	if amount <= 0 and target is Hero:
		has_blocked = true
		if MessageLog:
			MessageLog.add_positive("You block the attack with your shield!")

## Upstream re-cast is Buff.prolong plus a hasBlocked reset.
func merge(other: Node) -> void:
	if other is Buff:
		time_left = maxf(time_left, (other as Buff).time_left)
	has_blocked = false

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["has_blocked"] = has_blocked
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	has_blocked = bool(data.get("has_blocked", false))

func description() -> String:
	return "You are guarding with your shield, blocking all incoming attacks."
