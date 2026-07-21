class_name Firebloom
extends Plant
## Seeds a lasting Fire blob at its cell, exactly like Shattered Pixel Dungeon's
## Firebloom (`GameScene.add(Blob.seed(pos, 2, Fire.class))`). The Fire blob —
## not the plant — is what sets characters alight and burns flammable terrain on
## the shared blob timeline, so there is no separate one-shot burn or grass
## ignition here. A Warden hero instead gains a short Fire Imbue boon, matching
## upstream's subclass interaction (`FireImbue.DURATION * 0.3`).

## SPD Firebloom seeds 2 units of Fire at its cell.
const FIRE_AMOUNT: float = 2.0
## Warden's Fire Imbue lasts 30% of the full imbue duration.
const WARDEN_IMBUE_DURATION: float = FireImbue.BASE_DURATION * 0.3

func _init() -> void:
	plant_id = "Firebloom"
	plant_name = "Firebloom"

func _do_effect(char: Variant, level: Variant) -> void:
	# Warden gains a short offensive fire boon rather than relying on the seeded
	# flames (SPD: Warden receives FireImbue for a fraction of its duration).
	if char is Hero and char.hero_subclass == ConstantsData.HeroSubclass.WARDEN:
		if char.has_method("add_buff"):
			var imbue: FireImbue = FireImbue.new()
			imbue.set_duration(WARDEN_IMBUE_DURATION)
			char.add_buff(imbue)
		if MessageLog:
			MessageLog.add_positive("The firebloom's flames wreathe your weapon!")
	elif MessageLog and char != null:
		if char.get("is_hero"):
			MessageLog.add_negative("The firebloom bursts into flame!")
		else:
			MessageLog.add("The firebloom ignites around the %s!" % str(char.get("name")))

	# Seed a lasting Fire blob at the cell. The FireBlob applies Burning to any
	# character standing in it and converts flammable terrain to embers on its
	# own tick, so the plant never applies a one-shot burn (SPD parity). Guarded
	# so plant activation still works on lightweight test levels with no blob
	# layer.
	if level != null and level.has_method("add_blob"):
		level.add_blob(FireBlob.new(), pos, FIRE_AMOUNT)
