class_name StormTrap
extends Trap
## Seeds a large Electricity field, mirroring Shattered Pixel Dungeon's
## StormTrap (radius-2 passable footprint, 20 charge per cell).

const ELECTRICITY_AMOUNT: float = 20.0

func _init() -> void:
	trap_name = "storm trap"
	color = Color(0.8, 0.9, 1.0)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A violent storm erupts!")
	if level == null:
		return
	for cell: int in Blob.blast_cells(level, pos, 2):
		level.add_blob(Electricity.new(), cell, ELECTRICITY_AMOUNT)
