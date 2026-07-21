class_name Stormvine
extends Plant
## Disorients the target, or grants Warden a short levitation boon.

const WARDEN_LEVITATION_DURATION: float = Levitation.BASE_DURATION / 2.0

func _init() -> void:
	plant_id = "Stormvine"
	plant_name = "Stormvine"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	var is_warden: bool = char is Hero and char.hero_subclass == ConstantsData.HeroSubclass.WARDEN
	if char.has_method("add_buff"):
		if is_warden:
			var levitation: Levitation = Levitation.new()
			levitation.set_duration(WARDEN_LEVITATION_DURATION)
			char.add_buff(levitation)
		else:
			var vertigo: Vertigo = Vertigo.new()
			vertigo.set_duration(Vertigo.BASE_DURATION)
			char.add_buff(vertigo)

	if MessageLog:
		if is_warden:
			MessageLog.add("The stormvine lifts you into the air!")
		elif char.get("is_hero"):
			MessageLog.add_negative("The stormvine makes the world spin!")
		else:
			MessageLog.add("The stormvine disorients the %s!" % str(char.get("name")))
