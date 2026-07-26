class_name ProvokedAngerTracker
extends Buff
## Warrior Provoked Anger tracker (upstream Talent.ProvokedAngerTracker, a
## 5-turn FlavourBuff). Attached by the shield-absorb path in Char.take_damage
## (upstream ShieldBuff.processDamage) when any shield buff on the Warrior is
## broken by damage; consumed by Hero.attack_proc (upstream
## Talent.onAttackProc), which adds 1 + 2*points bonus damage and detaches it.

const DURATION := 5.0

func _init() -> void:
	buff_id = "ProvokedAngerTracker"
	buff_name = "Provoked Anger"
	buff_type = BuffType.POSITIVE
	duration = DURATION
	icon_color = Color(1.0, 0.55, 0.35)

func description() -> String:
	return "The Warrior's shielding was just broken, provoking his anger. His next physical attack will deal bonus damage."
