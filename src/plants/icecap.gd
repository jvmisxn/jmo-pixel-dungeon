class_name Icecap
extends Plant
## Immediately freezes characters on the plant's cell and its 8 neighbours,
## mirroring Shattered Pixel Dungeon's Icecap: for every non-solid NEIGHBOURS9
## cell it calls the legacy one-shot `Freezing.affect`, which freezes whoever is
## standing there on the spot. Upstream Icecap does NOT leave a lasting Freezing
## gas cloud, so this plant applies its effect directly rather than seeding a
## blob. A Warden hero instead gains a short Frost Imbue boon and is not frozen
## by the burst (`FrostImbue.DURATION * 0.3`).

const FREEZE_DURATION: float = 5.0
## Warden's Frost Imbue lasts 30% of the full imbue duration.
const WARDEN_IMBUE_DURATION: float = FrostImbue.BASE_DURATION * 0.3

func _init() -> void:
	plant_id = "Icecap"
	plant_name = "Icecap"

func _do_effect(char: Variant, level: Variant) -> void:
	if level == null:
		return

	# Warden gains a short offensive frost boon and, like SPD (FrostImbue grants
	# frost immunity), is skipped by the freezing burst below.
	var warden: Variant = null
	if char is Hero and char.hero_subclass == ConstantsData.HeroSubclass.WARDEN:
		warden = char
		if char.has_method("add_buff"):
			var imbue: FrostImbue = FrostImbue.new()
			imbue.set_duration(WARDEN_IMBUE_DURATION)
			char.add_buff(imbue)
		if MessageLog:
			MessageLog.add_positive("The icecap sheathes your weapon in frost!")

	if MessageLog:
		MessageLog.add("The icecap releases a blast of cold air!")

	# Collect the plant cell plus its 8 true neighbours (column-safe: reject any
	# cell that wraps across a map edge).
	var affected_positions: Array[int] = [pos]
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN and absi(adj % Level.W - pos % Level.W) <= 1:
			affected_positions.append(adj)

	# Freeze every character in range immediately (SPD's legacy Freezing.affect):
	# extinguish any fire on the target, then apply the frozen-solid buff. No
	# lasting gas cloud is left behind.
	for apos: int in affected_positions:
		if level.has_method("terrain_at") and ConstantsData.terrain_is_solid(level.terrain_at(apos)):
			continue
		var target: Variant = level.find_char_at(apos) if level.has_method("find_char_at") else null
		if target == null or target == warden or not target.has_method("add_buff"):
			continue
		if target.has_method("remove_buff_by_id"):
			target.remove_buff_by_id("Burning")
		var freeze: Frozen = Frozen.new()
		freeze.set_duration(FREEZE_DURATION)
		target.add_buff(freeze)
		if MessageLog:
			if target.get("is_hero"):
				MessageLog.add_negative("You are frozen solid!")
			else:
				MessageLog.add("The %s is frozen!" % str(target.get("name")))
