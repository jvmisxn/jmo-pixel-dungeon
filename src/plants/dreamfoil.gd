class_name Dreamfoil
extends Plant
## Upstream Mageroyal (renamed from Dreamfoil in SPD): cures negative effects
## on any character via PotionOfHealing.cure. Port adaptation: keeps the
## Dreamfoil name and the pre-rename sleep-lesser-creatures behavior for mobs.
## Upstream's Warden BlobImmunity on trigger is not ported yet (no BlobImmunity
## buff exists).

const SLEEP_DURATION: float = 10.0

func _init() -> void:
	plant_id = "Dreamfoil"
	plant_name = "Dreamfoil"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	# Upstream Mageroyal.activate: PotionOfHealing.cure on any character.
	Potion.PotionHealing.cure(char)

	if char.get("is_hero"):
		if MessageLog:
			MessageLog.add_positive("You feel refreshed.")
	else:
		# Port adaptation: lesser creatures are lulled into a deep sleep.
		if char.has_method("add_buff"):
			var sleep: SleepBuff = SleepBuff.new()
			sleep.set_duration(SLEEP_DURATION)
			char.add_buff(sleep)
		if char is Mob:
			(char as Mob)._set_state(Mob.AIState.SLEEPING)
		if MessageLog:
			MessageLog.add("The %s falls into a deep sleep." % str(char.get("name")))
