class_name MirrorImage
extends Mob
## A mirror image of the hero that fights alongside them.
## Created by the Scroll of Mirror Image.

var _source_hero: Variant = null
var _attack_skill: int = 10
var _defense_skill: int = 5
var _image_hp: int = 1

func _init() -> void:
	mob_name = "Mirror Image"
	description = "A " + "" + "shimmering " + "copy of the hero."
	hp = 1
	ht = 1
	xp_value = 0
	state = AIState.HUNTING
	icon_color = Color(0.6, 0.8, 1.0)
	body_color = Color(0.6, 0.8, 1.0)
	accent_color = Color(0.4, 0.6, 0.9)
	eye_color = Color(1.0, 1.0, 1.0)

func setup_from_hero(hero: Variant) -> void:
	_source_hero = hero
	if hero:
		var hero_lvl: int = ConstantsData.get_prop(hero, "hero_level", 1)
		_attack_skill = 10 + hero_lvl
		_defense_skill = 5 + hero_lvl
		_image_hp = 1 + hero_lvl
		hp = _image_hp
		ht = _image_hp

func attack_skill() -> int:
	return _attack_skill

func defense_skill() -> int:
	return _defense_skill

func damage_roll() -> int:
	if _source_hero and _source_hero.has_method("damage_roll"):
		return _source_hero.damage_roll()
	return randi_range(1, 5)

func die(cause: Variant) -> void:
	super.die(cause)

func get_display_name() -> String:
	return "Mirror Image"
