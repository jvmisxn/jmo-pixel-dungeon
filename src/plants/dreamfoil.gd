class_name Dreamfoil
extends Plant
## On hero: cures mind-altering debuffs (Blindness, Terror, Charm, Amok, etc.).
## On mobs: puts them to sleep (applies Paralysis as a sleep stand-in).

## Debuff IDs that dreamfoil can cure.
const MIND_DEBUFFS: Array[String] = [
	"Blindness", "Terror", "Charm", "Amok", "Vertigo",
]
const SLEEP_DURATION: float = 10.0

func _init() -> void:
	plant_id = "Dreamfoil"
	plant_name = "Dreamfoil"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	if char.get("is_hero"):
		# Cure mind-altering debuffs on the hero
		var cured: bool = false
		if char.has_method("remove_buff_by_id"):
			for debuff_id: String in MIND_DEBUFFS:
				if char.has_method("has_buff") and char.has_buff(debuff_id):
					char.remove_buff_by_id(debuff_id)
					cured = true
		if MessageLog:
			if cured:
				MessageLog.add_positive("Refreshing vapors clear your mind!")
			else:
				MessageLog.add("Refreshing vapors wash over you.")
	else:
		# Put mobs to sleep
		if char.has_method("add_buff"):
			var sleep: Paralysis = Paralysis.new()
			sleep.set_duration(SLEEP_DURATION)
			char.add_buff(sleep)
		# Also set mob state to sleeping if possible
		if char.get("state") != null and char.has_method("set"):
			char.set("state", 0)  # Mob.AIState.SLEEPING = 0
		if MessageLog:
			MessageLog.add("The %s falls into a deep sleep." % str(char.get("name")))
