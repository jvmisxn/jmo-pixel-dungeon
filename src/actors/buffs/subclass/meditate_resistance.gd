class_name MeditateResistance
extends Buff
## Empowered-Meditate damage resistance. Original:
## MonkEnergy.MonkAbility.Meditate.MeditateResistance. While active the
## hero takes only 20% damage (Hero.take_damage applies the multiplier);
## lasts for the meditation itself (upstream: hero.cooldown()).

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "MeditateResistance"
	buff_name = "Meditative Resistance"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.63, 0.53, 0.25)

func description() -> String:
	return "Deep meditation shields this character, reducing all damage taken to 20%."
