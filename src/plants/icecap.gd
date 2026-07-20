class_name Icecap
extends Plant
## Freezes nearby characters. Also extinguishes fire on the hero.

const FREEZE_DURATION: float = 5.0
const RADIUS: int = 1
## Freezing density seeded per footprint cell (see FrostTrap for the scaling).
const FROST_AMOUNT: float = 5.0

func _init() -> void:
	plant_id = "Icecap"
	plant_name = "Icecap"

func _do_effect(char: Variant, level: Variant) -> void:
	if level == null:
		return

	if MessageLog:
		MessageLog.add("The icecap releases a " +
			"blast of cold air!")

	# Collect all positions within radius
	var affected_positions: Array[int] = [pos]
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		# Column-safe adjacency: reject cells that wrap across a map edge
		# (e.g. a West step from column 0 lands on the previous row's last
		# column), which would otherwise freeze a character across the map.
		if adj >= 0 and adj < Level.LEN and absi(adj % Level.W - pos % Level.W) <= 1:
			affected_positions.append(adj)

	# Freeze all characters in range
	for apos: int in affected_positions:
		var target: Variant = level.find_char_at(apos) if level.has_method("find_char_at") else null
		if target != null and target.has_method("add_buff"):
			# Remove Burning if present
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

	# Seed a lasting Freezing blob over the 3x3 footprint so the cold air
	# persists on the shared blob timeline, matching SPD's Freezing.affect over
	# NEIGHBOURS9. Guarded so the direct AoE still works on lightweight test
	# levels that lack the blob layer.
	if level != null and level.has_method("add_blob"):
		for cell: int in Blob.blast_cells(level, pos, RADIUS):
			level.add_blob(FreezingBlob.new(), cell, FROST_AMOUNT)
