class_name AssassinPreparation
extends Buff
## Assassin subclass passive. Builds preparation while hidden (invisible or
## out of enemy sight). First attack from preparation deals massive bonus damage.

var prep_level: int = 0
const MAX_PREP: int = 5
## Whether the assassin is currently preparing (not seen by enemies).
var is_preparing: bool = false

func _init() -> void:
	buff_id = "AssassinPreparation"
	buff_name = "Preparation"
	duration = -1.0
	icon_color = Color(0.2, 0.2, 0.5)

func on_turn() -> void:
	if target == null:
		return
	# Check if hidden: invisible, or no enemies can see us
	var hidden: bool = target.has_buff("Invisibility")
	if not hidden:
		hidden = _no_enemies_see_us()

	if hidden:
		is_preparing = true
		prep_level = mini(prep_level + 1, MAX_PREP)
	else:
		is_preparing = false

func _no_enemies_see_us() -> bool:
	if target == null or target.level == null:
		return true
	for mob: Variant in target.level.mobs:
		if mob is Node and mob.get("is_alive") == true:
			if mob.get("state") == 2 and mob.get("target") == target:
				return false
	return true

func modify_damage(dmg: int) -> int:
	if prep_level <= 0:
		return dmg
	# Damage multiplier: 1.5x at level 1, up to 3.0x at level 5
	var mult: float = 1.0 + prep_level * 0.4
	var boosted: int = int(dmg * mult)
	if MessageLog:
		MessageLog.add_positive("Assassin strike! (x%.1f from preparation)" % mult)
	# Reset preparation after the strike
	prep_level = 0
	is_preparing = false
	return boosted

func description() -> String:
	if prep_level > 0:
		return "Preparation (level %d, x%.1f damage)" % [prep_level, 1.0 + prep_level * 0.4]
	return "Preparation"
