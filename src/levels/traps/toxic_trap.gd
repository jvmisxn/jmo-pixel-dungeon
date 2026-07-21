class_name ToxicTrap
extends Trap
## Seeds a lasting ToxicGas cloud, mirroring Shattered Pixel Dungeon's
## ToxicTrap. The gas itself applies Poison on the shared blob timeline.

func _init() -> void:
	trap_name = "toxic gas trap"
	color = Color(0.2, 0.8, 0.2)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Toxic gas billows from the trap!")
	if level == null or not level.has_method("add_blob"):
		return
	level.add_blob(ToxicGas.new(), pos, 300.0 + 20.0 * float(level.depth))
