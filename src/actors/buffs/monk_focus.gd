class_name MonkFocus
extends Buff
## Dwarf monk Focus stance (upstream Monk.Focus + Monk.defenseSkill/
## defenseVerb). While held, the monk parries physical attacks: infinite
## evasion unless the monk is paralysed or sleeping. Any miss while focused
## consumes the focus and starts the monk's 6-7 turn focus cooldown.

func _init() -> void:
	buff_id = "MonkFocus"
	buff_name = "Focused"
	buff_type = BuffType.POSITIVE
	duration = -1  # Consumed on parry, never expires on its own
	announced = true
	icon_color = Color(0.25, 1.0, 0.67)  # upstream hardlight 0.25/1.5/1

## Upstream Monk.defenseSkill returns INFINITE_EVASION only while not
## paralysed and awake; Char.hit treats >= 1000000 evasion as auto-miss.
func modify_evasion(eva: int) -> int:
	if target == null:
		return eva
	if "paralysed" in target and target.paralysed > 0:
		return eva
	if target is Mob and (target as Mob).state == Mob.AIState.SLEEPING:
		return eva
	return 1000000000

## Char's miss path notifies defender buffs with amount 0. Upstream
## Monk.defenseVerb: any miss while focused is a parry — detach the buff
## and roll the new focus cooldown on the monk.
func on_damage_taken(amount: int, source: Variant) -> void:
	if amount > 0 or target == null:
		return
	if MessageLog and source is Hero:
		MessageLog.add_negative("The %s parries your attack!" % str(target.mob_name).to_lower())
	if target is MonkMob:
		(target as MonkMob).on_focus_parried()
	if target.has_method("remove_buff"):
		target.remove_buff(self)

func description() -> String:
	return "This monk is perfectly honed in on their target, and seems to be anticipating their moves before they make them.\n\nWhile focused, the next physical attack made against this character is guaranteed to miss, no matter what circumstances there are. Parrying this attack will spend the monk's focus, and they will need to build it up again to parry another attack. Monks build focus more quickly while they are moving."
