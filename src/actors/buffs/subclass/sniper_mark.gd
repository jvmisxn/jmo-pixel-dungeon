class_name SniperMark
extends Buff
## Sniper subclass passive. Boosts ranged accuracy and tracks snapshot cooldown.

var snapshot_cooldown: int = 0
const SNAPSHOT_INTERVAL: int = 3

func _init() -> void:
	buff_id = "SniperMark"
	buff_name = "Sniper"
	duration = -1.0
	icon_color = Color(0.9, 0.5, 0.1)

func on_turn() -> void:
	if snapshot_cooldown > 0:
		snapshot_cooldown -= 1

func modify_accuracy(acc: int) -> int:
	# +50% accuracy for ranged attacks
	# This applies to all attacks; the hero code should check if ranged
	return int(acc * 1.5)

## Check if snapshot is available (instant ranged attack).
func can_snapshot() -> bool:
	return snapshot_cooldown <= 0

## Use snapshot — resets the cooldown.
func use_snapshot() -> void:
	snapshot_cooldown = SNAPSHOT_INTERVAL
	if MessageLog:
		MessageLog.add_positive("Snapshot!")

func description() -> String:
	if snapshot_cooldown > 0:
		return "Sniper (snapshot in %d)" % snapshot_cooldown
	return "Sniper (snapshot ready!)"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["snapshot_cooldown"] = snapshot_cooldown
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	snapshot_cooldown = int(data.get("snapshot_cooldown", snapshot_cooldown))
