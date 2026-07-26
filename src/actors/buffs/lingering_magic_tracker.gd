class_name LingeringMagicTracker
extends Buff
## Mage Lingering Magic tracker (upstream Talent.LingeringMagicTracker, a
## 5-turn FlavourBuff). Attached by Wand.zap (upstream Wand.wandUsed) whenever
## the Mage zaps a wand or his staff; consumed by Hero.attack_proc (upstream
## Talent.onAttackProc), which adds IntRange(points, 2) bonus damage and
## detaches it.

const DURATION := 5.0

func _init() -> void:
	buff_id = "LingeringMagicTracker"
	buff_name = "Lingering Magic"
	buff_type = BuffType.POSITIVE
	duration = DURATION
	icon_color = Color(0.55, 0.6, 1.0)

func description() -> String:
	return "Magical energy lingers from the Mage's last zap. His next physical attack will deal bonus damage."
