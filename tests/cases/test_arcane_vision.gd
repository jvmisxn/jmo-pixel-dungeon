extends RefCounted
## Mage Arcane Vision talent (upstream Wand.wandProc head + Talent T2):
## zapping a character with a wand marks it with CharAwareness for
## 5 + 5*points turns (10/15), and Level.update_fov reveals any living mob
## carrying the mark even outside normal sight (cell + 8 neighbors).
## Port adaptation: upstream attaches TalismanOfForesight.CharAwareness to
## the hero keyed by actor id; the port has no actor-id registry, so the
## mark lives on the watched mob and serializes with it.

class _FakeLevel extends RefCounted:
	var chars: Dictionary = {}  # pos -> Char
	func find_char_at(p: int) -> Variant:
		return chars.get(p, null)

func run(t: Object) -> void:
	_test_registry(t)
	_test_proc_marks_target(t)
	_test_no_talent_no_mark(t)
	_test_refresh_keeps_longer_duration(t)
	_test_fov_reveals_marked_mob(t)
	_test_serialize_round_trip(t)

func _make_mage(points: int, lvl: Variant) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_arcane_vision"] = points
	hero.level = lvl
	return hero

## Arcane Vision is live T2; Inscribed Power / Wand Preservation are inert
## groundwork slots (upstream Mage T2 ordering).
func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_arcane_vision")
	t.check(info != null, "mage_arcane_vision is registered")
	if info != null:
		t.check(info.tier == 2 and info.max_points == 2 and info.implemented,
			"Arcane Vision is an implemented 2-point T2 talent")
	var inscribed: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_inscribed_power")
	var preservation: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_wand_preservation")
	t.check(inscribed != null and inscribed.implemented,
		"Inscribed Power is implemented (see test_inscribed_power.gd)")
	t.check(preservation != null and not preservation.implemented,
		"Wand Preservation is an inert groundwork slot")

func _test_proc_marks_target(t: Object) -> void:
	for points: int in [1, 2]:
		var lvl := _FakeLevel.new()
		var hero := _make_mage(points, lvl)
		var mob := Char.new()
		mob.pos = 5
		lvl.chars[5] = mob
		var wand := Wand.WandOfMagicMissile.new()
		wand._arcane_vision_proc(hero, [3, 4, 5] as Array[int])
		var mark: Buff = mob.get_buff("CharAwareness")
		t.check(mark != null, "+%d zap proc marks the bolt-stop character" % points)
		if mark != null:
			var expected: float = 5.0 + 5.0 * points
			t.check(is_equal_approx(mark.time_left, expected),
				"+%d awareness lasts %d turns, got %.1f" % [points, int(expected), mark.time_left])
		hero.free()
		mob.free()

func _test_no_talent_no_mark(t: Object) -> void:
	var lvl := _FakeLevel.new()
	var hero := _make_mage(0, lvl)
	var mob := Char.new()
	mob.pos = 5
	lvl.chars[5] = mob
	var wand := Wand.WandOfMagicMissile.new()
	wand._arcane_vision_proc(hero, [4, 5] as Array[int])
	t.check(not mob.has_buff("CharAwareness"),
		"Zapping without the talent applies no awareness mark")
	# Self-zaps never mark the hero.
	lvl.chars[7] = hero
	hero.talent_levels["mage_arcane_vision"] = 2
	wand._arcane_vision_proc(hero, [7] as Array[int])
	t.check(not hero.has_buff("CharAwareness"),
		"Self-zap does not mark the hero")
	hero.free()
	mob.free()

func _test_refresh_keeps_longer_duration(t: Object) -> void:
	var lvl := _FakeLevel.new()
	var hero := _make_mage(2, lvl)
	var mob := Char.new()
	mob.pos = 5
	lvl.chars[5] = mob
	var wand := Wand.WandOfMagicMissile.new()
	wand._arcane_vision_proc(hero, [5] as Array[int])
	var mark: Buff = mob.get_buff("CharAwareness")
	if mark != null:
		mark.time_left = 4.0
	hero.talent_levels["mage_arcane_vision"] = 1
	wand._arcane_vision_proc(hero, [5] as Array[int])
	mark = mob.get_buff("CharAwareness")
	t.check(mark != null and is_equal_approx(mark.time_left, 10.0),
		"Re-zapping refreshes the mark to the longer duration")
	if mark != null:
		mark.time_left = 14.0
	wand._arcane_vision_proc(hero, [5] as Array[int])
	mark = mob.get_buff("CharAwareness")
	t.check(mark != null and is_equal_approx(mark.time_left, 14.0),
		"A weaker re-zap never shortens an existing mark")
	hero.free()
	mob.free()

## A marked mob far outside view distance is revealed by update_fov.
func _test_fov_reveals_marked_mob(t: Object) -> void:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	var prev_hero: Variant = GameManager.hero if GameManager else null
	if GameManager:
		GameManager.hero = hero
	var hero_pos: int = ConstantsData.xy_to_pos(16, 16)
	var far_pos: int = ConstantsData.xy_to_pos(16, 2)
	var mob := Char.new()
	mob.pos = far_pos
	level.mobs.append(mob)
	level.update_fov(hero_pos)
	t.check(not level.visible[far_pos],
		"Unmarked mob 14 tiles away is outside normal FOV")
	mob.add_buff(CharAwareness.new())
	level.update_fov(hero_pos)
	t.check(level.visible[far_pos],
		"CharAwareness reveals the marked mob through the fog")
	var dead_check: bool = true
	mob.is_alive = false
	level.update_fov(hero_pos)
	dead_check = not level.visible[far_pos]
	t.check(dead_check, "A dead marked mob is no longer revealed")
	if GameManager:
		GameManager.hero = prev_hero
	level.mobs.clear()
	mob.free()
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var mark := CharAwareness.new()
	mark.time_left = 12.0
	mark.duration = 15.0
	var data: Dictionary = mark.serialize()
	var restored := CharAwareness.new()
	restored.deserialize(data)
	t.check(is_equal_approx(restored.time_left, 12.0)
		and is_equal_approx(restored.duration, 15.0),
		"CharAwareness serialize round-trips duration state")
	mark.free()
	restored.free()
