class_name CorrosionTrap
extends Trap
## Seeds a lasting CorrosiveGas cloud, mirroring Shattered Pixel Dungeon's
## CorrosionTrap (which seeds `80 + 5 * scalingDepth` CorrosiveGas at its cell
## with strength `1 + scalingDepth/4`). The trap no longer deals a one-shot hit
## or applies the wrong Ooze buff: the seeded CorrosiveGas rides the shared blob
## timeline (Level.advance_blobs), spreading by diffusion and applying the real
## escalating Corrosion debuff to anyone caught in the cloud.

func _init() -> void:
	trap_name = "corrosion trap"
	color = Color(0.6, 0.1, 0.6)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Corrosive gas billows from the trap!")
	if level == null or not level.has_method("add_blob"):
		return
	# SPD CorrosionTrap: single-cell CorrosiveGas seed, depth-scaled volume/strength.
	@warning_ignore("integer_division")
	var strength: int = 1 + level.depth / 4
	var gas: CorrosiveGas = CorrosiveGas.new()
	gas.set_strength(strength, "CorrosionTrap")
	level.add_blob(gas, pos, 80.0 + 5.0 * float(level.depth))
