extends RefCounted
## Huntress Heightened Senses talent (upstream Level.updateFieldOfView
## mindVisRange branch): the hero gains mind vision on characters within
## 1+points tiles (2/3), even through walls. Revealed mobs light up their
## cell plus 8 neighbors (NEIGHBOURS9), same as the MindVision buff overlay.

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_talent_no_reveal(t)
	_test_reveal_within_range(t)
	_test_range_scales_with_points(t)

func _make_walled_level() -> Level:
	# Solid rock everywhere: nothing is visible by normal sight, so any
	# revealed cell must come from the mind-vision overlay.
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.WALL)
	level.build_flag_maps()
	return level

func _make_huntress(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_heightened_senses"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_heightened_senses")
	t.check(info != null, "huntress_heightened_senses is registered")
	if info != null:
		t.check(info.tier == 2 and info.max_points == 2 and info.implemented,
			"Heightened Senses is an implemented 2-point T2 talent")

func _run_fov(points: int, mob_dist: int) -> bool:
	var level := _make_walled_level()
	var hero := _make_huntress(points)
	var prev_hero: Variant = GameManager.hero if GameManager else null
	if GameManager:
		GameManager.hero = hero
	var hero_pos: int = ConstantsData.xy_to_pos(16, 16)
	var mob_pos: int = ConstantsData.xy_to_pos(16 + mob_dist, 16)
	var mob := Char.new()
	mob.pos = mob_pos
	level.mobs.append(mob)
	level.update_fov(hero_pos)
	var revealed: bool = level.visible[mob_pos]
	if GameManager:
		GameManager.hero = prev_hero
	level.mobs.clear()
	mob.free()
	hero.free()
	return revealed

func _test_no_talent_no_reveal(t: Object) -> void:
	t.check(not _run_fov(0, 2),
		"Without the talent an adjacent-ish mob behind rock stays hidden")

func _test_reveal_within_range(t: Object) -> void:
	t.check(_run_fov(1, 2),
		"+1 senses a mob 2 tiles away through solid rock")
	t.check(not _run_fov(1, 3),
		"+1 does not sense a mob 3 tiles away")

func _test_range_scales_with_points(t: Object) -> void:
	t.check(_run_fov(2, 3),
		"+2 senses a mob 3 tiles away through solid rock")
	t.check(not _run_fov(2, 4),
		"+2 does not sense a mob 4 tiles away")
