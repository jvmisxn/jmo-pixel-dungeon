class_name FireTrap
extends Trap
## Erupts into a lasting Fire blob across its 3x3 footprint, mirroring Shattered
## Pixel Dungeon's BurningTrap. The trap no longer deals a one-shot hit; the
## seeded Fire blob rides the shared blob timeline (Level.advance_blobs) and
## applies Burning + ignites flammable terrain as characters stand in it.

## SPD seeds each footprint cell with 2 units of Fire. Our FireBlob decays 0.15
## per timeline tick, so 2.0 lingers long enough to burn anyone standing in it.
const FIRE_AMOUNT: float = 2.0

func _init() -> void:
	trap_name = "fire trap"
	color = Color(1.0, 0.4, 0.1)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Flames erupt from the floor!")
	if level == null:
		return
	# SPD BurningTrap: seed Fire over the passable NEIGHBOURS9 (3x3) footprint.
	for cell: int in Blob.blast_cells(level, pos, 1):
		level.add_blob(FireBlob.new(), cell, FIRE_AMOUNT)
