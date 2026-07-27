extends RefCounted
## Huntress Seer Shot (T3) — upstream SpiritBow.SpiritArrow.cast: shooting the
## bow at a cell with no character on it, while off cooldown, attaches a
## RevealedArea buff (5 turns per talent point) plus a 20-turn
## SeerShotCooldown; Level.update_fov then reveals the 3x3 around the shot
## cell through walls, on the reveal's own depth only.

func run(t: Object) -> void:
	_test_registry(t)
	_test_apply_attaches_buffs(t)
	_test_no_talent_no_buffs(t)
	_test_cooldown_blocks_reapply(t)
	_test_char_at_cell_blocks(t)
	_test_fov_reveal(t)
	_test_serialization(t)

func _make_walled_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.WALL)
	level.build_flag_maps()
	return level

func _make_huntress(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_seer_shot"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_seer_shot")
	t.check(info != null, "huntress_seer_shot is registered")
	if info != null:
		t.check(info.tier == 3 and info.max_points == 3 and info.implemented,
			"Seer Shot is an implemented 3-point T3 talent")

func _test_apply_attaches_buffs(t: Object) -> void:
	var hero := _make_huntress(2)
	var shot_pos: int = ConstantsData.xy_to_pos(10, 10)
	SpiritBow.apply_seer_shot(hero, shot_pos)
	var reveal: Buff = hero.get_buff("RevealedArea")
	t.check(reveal != null, "Seer Shot attaches a RevealedArea buff")
	if reveal != null:
		t.check(is_equal_approx(reveal.duration, 10.0),
			"RevealedArea lasts 5 turns per point (10 at +2)")
		t.check(int(reveal.get("reveal_pos")) == shot_pos,
			"RevealedArea records the shot cell")
	t.check(hero.has_buff("SeerShotCooldown"),
		"Seer Shot starts its 20-turn cooldown")
	var cd: Buff = hero.get_buff("SeerShotCooldown")
	if cd != null:
		t.check(is_equal_approx(cd.duration, 20.0), "Cooldown is 20 turns")
	hero.free()

func _test_no_talent_no_buffs(t: Object) -> void:
	var hero := _make_huntress(0)
	SpiritBow.apply_seer_shot(hero, ConstantsData.xy_to_pos(10, 10))
	t.check(not hero.has_buff("RevealedArea") and not hero.has_buff("SeerShotCooldown"),
		"Without the talent no reveal or cooldown is attached")
	hero.free()

func _test_cooldown_blocks_reapply(t: Object) -> void:
	var hero := _make_huntress(3)
	var first_pos: int = ConstantsData.xy_to_pos(10, 10)
	SpiritBow.apply_seer_shot(hero, first_pos)
	SpiritBow.apply_seer_shot(hero, ConstantsData.xy_to_pos(20, 20))
	var reveal: Buff = hero.get_buff("RevealedArea")
	t.check(reveal != null and int(reveal.get("reveal_pos")) == first_pos,
		"While on cooldown a second shot does not move the reveal")
	hero.free()

func _test_char_at_cell_blocks(t: Object) -> void:
	var level := _make_walled_level()
	var hero := _make_huntress(3)
	var shot_pos: int = ConstantsData.xy_to_pos(10, 10)
	var mob := Char.new()
	mob.pos = shot_pos
	level.mobs.append(mob)
	hero.level = level
	SpiritBow.apply_seer_shot(hero, shot_pos)
	t.check(not hero.has_buff("RevealedArea") and not hero.has_buff("SeerShotCooldown"),
		"Shooting a cell occupied by a character does not reveal (or spend the cooldown)")
	hero.level = null
	level.mobs.clear()
	mob.free()
	hero.free()

func _test_fov_reveal(t: Object) -> void:
	var level := _make_walled_level()
	var hero := _make_huntress(1)
	var prev_hero: Variant = GameManager.hero if GameManager else null
	var prev_depth: int = int(GameManager.depth) if GameManager else 0
	if GameManager:
		GameManager.hero = hero
	var hero_pos: int = ConstantsData.xy_to_pos(16, 16)
	var shot_pos: int = ConstantsData.xy_to_pos(30, 16)

	var reveal := RevealedArea.new()
	reveal.reveal_pos = shot_pos
	reveal.reveal_depth = prev_depth
	reveal.set_duration(5.0)
	hero.add_buff(reveal)

	level.update_fov(hero_pos)
	t.check(level.visible[shot_pos],
		"RevealedArea lights the shot cell through solid rock")
	t.check(level.visible[shot_pos - 1] and level.visible[shot_pos + ConstantsData.WIDTH],
		"RevealedArea lights the 3x3 neighborhood around the shot cell")

	# A reveal from another depth contributes nothing.
	reveal.reveal_depth = prev_depth + 1
	level.update_fov(hero_pos)
	t.check(not level.visible[shot_pos],
		"A RevealedArea from another depth does not light anything")

	if GameManager:
		GameManager.hero = prev_hero
	hero.free()

func _test_serialization(t: Object) -> void:
	var reveal := RevealedArea.new()
	reveal.reveal_pos = 123
	reveal.reveal_depth = 4
	reveal.set_duration(15.0)
	var data: Dictionary = reveal.serialize()
	var restored := RevealedArea.new()
	restored.deserialize(data)
	t.check(restored.reveal_pos == 123 and restored.reveal_depth == 4,
		"RevealedArea round-trips its cell and depth through save data")
	reveal.free()
	restored.free()
