class_name WardenBarkskin
extends Buff
## Warden subclass passive. Grants temporary armor when walking over
## grass, plants, or natural terrain.

var barkskin_armor: int = 0
const MAX_BARKSKIN: int = 15
## Turns of barkskin remaining.
var barkskin_turns: int = 0

func _init() -> void:
	buff_id = "WardenBarkskin"
	buff_name = "Barkskin"
	duration = -1.0
	icon_color = Color(0.3, 0.6, 0.2)

func on_move(_old_pos: int, new_pos: int) -> void:
	if target == null or target.level == null:
		return
	var terrain: int = target.level.get_terrain(new_pos)
	match terrain:
		ConstantsData.Terrain.GRASS, ConstantsData.Terrain.HIGH_GRASS, \
		ConstantsData.Terrain.FURROWED_GRASS:
			# Grant barkskin from nature
			var hero_lvl: int = 1
			if target.get("is_hero") == true:
				hero_lvl = target.hero_level
			barkskin_armor = mini(2 + hero_lvl / 3, MAX_BARKSKIN)
			barkskin_turns = 5
			if MessageLog:
				MessageLog.add("The grass strengthens your bark-like skin.")

func on_turn() -> void:
	if barkskin_turns > 0:
		barkskin_turns -= 1
		if barkskin_turns <= 0:
			barkskin_armor = 0

func modify_armor(armor: int) -> int:
	return armor + barkskin_armor

## Warden plants last twice as long — check this from the plant system.
func plant_duration_multiplier() -> float:
	return 2.0

## Warden seeds have double area of effect.
func seed_aoe_multiplier() -> float:
	return 2.0

func description() -> String:
	if barkskin_armor > 0:
		return "Barkskin (+%d armor, %d turns)" % [barkskin_armor, barkskin_turns]
	return "Barkskin (inactive until standing on grass)."
