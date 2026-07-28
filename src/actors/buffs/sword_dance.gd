class_name SwordDance
extends Buff
## Duelist Scimitar Sword Dance stance. Original: Scimitar.SwordDance
## (FlavourBuff): while active the hero attacks with 1.5x accuracy and a
## +0.6 bonus to the attack-speed multiplier (additive with Ring of Furor).

const ACCURACY_FACTOR: float = 1.5
const SPEED_BONUS: float = 0.6

func _init() -> void:
	buff_id = "SwordDance"
	buff_name = "Sword Dance"
	buff_type = BuffType.POSITIVE
	announced = true
	icon_color = Color(1.0, 0.85, 0.3)

func modify_accuracy(acc: int) -> int:
	return roundi(float(acc) * ACCURACY_FACTOR)

## Upstream Weapon.speedMultiplier is furor_multi + 0.6 and the final delay
## is base / multi. FurorBuff already divides the delay by its own
## multiplier f, so this hook scales by f / (f + 0.6); multiplication
## commutes, so in any hook order the combined result is base / (f + 0.6).
func modify_attack_delay(delay: float) -> float:
	var furor_multi: float = 1.0
	if target != null and target.has_method("get_buff"):
		var furor: Variant = target.get_buff("RingOfFuror")
		if furor != null and furor.has_method("attack_speed_multiplier"):
			furor_multi = furor.attack_speed_multiplier()
	return delay * furor_multi / (furor_multi + SPEED_BONUS)

func description() -> String:
	return "You are dancing with your blade, attacking with greater speed and accuracy."
