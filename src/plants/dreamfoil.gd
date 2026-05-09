class_name Dreamfoil
extends Plant
## On hero: cures mind-altering debuffs. On mobs: puts them to sleep.

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
		if char is Mob:
			(char as Mob)._set_state(Mob.AIState.SLEEPING)
		if MessageLog:
			MessageLog.add("The %s falls into a deep sleep." % str(char.get("name")))
