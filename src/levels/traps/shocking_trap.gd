class_name ShockingTrap
extends Trap
## Seeds an Electricity blob across its 3x3 footprint, mirroring Shattered Pixel
## Dungeon's ShockingTrap. The blob owns paralysis, water conduction, and the
## small alternating zap damage on the shared timeline.

const ELECTRICITY_AMOUNT: float = 10.0

func _init() -> void:
	trap_name = "shocking trap"
	color = Color(1.0, 1.0, 0.3)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Lightning arcs from the trap!")
	if level == null:
		return
	for cell: int in Blob.blast_cells(level, pos, 1):
		level.add_blob(Electricity.new(), cell, ELECTRICITY_AMOUNT)
