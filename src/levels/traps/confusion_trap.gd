class_name ConfusionTrap
extends Trap
## Seeds a lasting ConfusionGas cloud, matching Shattered Pixel Dungeon's
## ConfusionTrap. The gas itself applies Vertigo on its blob timeline.

func _init() -> void:
	trap_name = "confusion gas trap"
	color = Color(0.0, 0.75, 0.75)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A confusing gas billows from the trap!")
	if level == null or not level.has_method("add_blob"):
		return

	# SPD ConfusionTrap: seed ConfusionGas at 300 + 20 * scalingDepth.
	level.add_blob(ConfusionGas.new(), pos, 300.0 + 20.0 * float(level.depth))
