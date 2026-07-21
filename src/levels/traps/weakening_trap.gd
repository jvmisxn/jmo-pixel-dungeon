class_name WeakeningTrap
extends Trap
## Saps the strength of whoever steps on it, applying a long Weakness debuff.
## Mirrors Shattered Pixel Dungeon's WeakeningTrap: a one-shot City trap that
## prolongs Weakness for `Weakness.DURATION * 3` on the character in the cell
## (upstream also prolongs `DURATION/2` first for BOSS/MINIBOSS targets, but that
## is only a floor for bosses with debuff-duration resistance -- which this port
## does not model, so the 3x application already dominates it). Upstream's mob
## `HazardAssistTracker` hint is likewise not implemented in this port yet.

func _init() -> void:
	trap_name = "weakening trap"
	color = Color(0.3, 0.7, 0.3)

func _do_effect(triggerer: Variant, _level: Level) -> void:
	if MessageLog:
		MessageLog.add("A wave of enervating energy saps your strength!")

	if triggerer != null and triggerer.has_method("add_buff"):
		var weakness := Weakness.new()
		weakness.set_duration(Weakness.BASE_DURATION * 3.0)
		triggerer.add_buff(weakness)
