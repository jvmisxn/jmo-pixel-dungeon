class_name FrostTrap
extends Trap
## Erupts into a lasting Freezing blob over a radius-2 footprint, mirroring
## Shattered Pixel Dungeon's FrostTrap (which flood-fills Freezing out to
## distance 2). The trap no longer deals a one-shot hit; the seeded Freezing
## blob rides the shared blob timeline (Level.advance_blobs), freezing anyone
## standing in it, hardening water, and extinguishing fire.

## SPD seeds 20 units of Freezing per cell; scaled down for our density model
## (FreezingBlob decays 0.12/tick) so the vapor lingers without persisting for
## hundreds of ticks.
const FROST_AMOUNT: float = 5.0

func _init() -> void:
	trap_name = "frost trap"
	color = Color(0.3, 0.5, 1.0)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A wave of frost erupts!")
	if level == null:
		return
	# SPD FrostTrap: seed Freezing across the passable radius-2 footprint.
	for cell: int in Blob.blast_cells(level, pos, 2):
		level.add_blob(FreezingBlob.new(), cell, FROST_AMOUNT)
