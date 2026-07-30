class_name CausticSlime
extends Slime
## Caustic slime: rare 1-in-50 alt of the slime (upstream CausticSlime.java,
## swapped in via MobSpawner.RARE_ALTS). Acidic — immune to Ooze — and has a
## 1/2 chance to coat its victim in caustic ooze on hit. Upstream also always
## drops a Goo Blob next to its corpse; deferred until alchemy ingredients
## are ported.

func _init() -> void:
	super._init()
	mob_id = "caustic_slime"
	mob_name = "Caustic Slime"
	description = "This slime seems to have been tainted by the dark magic emanating from below. It has lost its usual green color, and drips with caustic ooze."
	_properties = ["ACIDIC"]


func _innate_immunities() -> Array[String]:
	return ["Ooze"]


func attack_proc(enemy: Char, damage: int) -> int:
	# Upstream: Random.Int(2) == 0 -> Ooze.set(Ooze.DURATION) on the victim.
	if enemy != null and randi_range(0, 1) == 0:
		apply_ooze(enemy)
	return super.attack_proc(enemy, damage)


## Split out so tests can exercise the ooze application deterministically.
func apply_ooze(enemy: Char) -> void:
	var ooze := Ooze.new()
	ooze.set_duration_value(Ooze.DURATION)
	enemy.add_buff(ooze)
