class_name RevealedArea
extends Buff
## Huntress Seer Shot reveal (upstream `buffs/RevealedArea.java`): while this
## buff lasts, the 3x3 area around the shot cell is merged into the hero's
## field of view by `Level.update_fov`, on the depth it was created on only.
## Duration is 5 turns per Seer Shot talent point; applied by
## `SpiritBow.apply_seer_shot`.

## Cell at the center of the revealed 3x3 area.
var reveal_pos: int = -1
## Depth the reveal was created on; other floors ignore it, matching
## upstream's depth/branch guard (this port has no side branches).
var reveal_depth: int = 0

func _init() -> void:
	buff_id = "RevealedArea"
	buff_name = "Revealed Area"
	buff_type = BuffType.POSITIVE
	# Upstream tints the MIND_VISION icon cyan (hardlight 0,1,1).
	icon_color = Color(0.0, 1.0, 1.0)
	announced = true

func description() -> String:
	return "Your spirit bow has revealed the area around where it struck, and you can see that area from any distance.\n\nThe area will stay revealed for a short time, or until you shoot at another location."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["reveal_pos"] = reveal_pos
	data["reveal_depth"] = reveal_depth
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	reveal_pos = int(data.get("reveal_pos", reveal_pos))
	reveal_depth = int(data.get("reveal_depth", reveal_depth))
