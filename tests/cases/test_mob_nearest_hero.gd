extends RefCounted

# _find_visible_heroes() must return nearest-first (upstream Mob.chooseEnemy:
# "go after the closest potential enemy, breaking ties randomly"), so every
# heroes[0] call site — sleeping/wandering detection, alert(), notice — picks
# the nearest hero on multi-hero levels.

class FakeLevel:
	extends RefCounted

	var heroes: Array[Char] = []

	func get_heroes() -> Array[Char]:
		return heroes

	func has_los(_from_pos: int, _to_pos: int) -> bool:
		return true

func run(t: Object) -> void:
	_test_visible_heroes_sorted_nearest_first(t)
	_test_alert_targets_nearest_hero(t)
	_test_invisible_and_dead_heroes_excluded(t)

func _make_hero(level: FakeLevel, x: int, y: int) -> Char:
	var h := Char.new()
	h.pos = ConstantsData.xy_to_pos(x, y)
	h.level = level
	return h

func _test_visible_heroes_sorted_nearest_first(t: Object) -> void:
	var level := FakeLevel.new()
	var mob := Mob.new()
	mob.pos = ConstantsData.xy_to_pos(10, 10)
	mob.level = level
	var far_hero := _make_hero(level, 18, 10)
	var mid_hero := _make_hero(level, 14, 10)
	var near_hero := _make_hero(level, 11, 10)
	level.heroes = [far_hero, mid_hero, near_hero]

	for _i in range(8):
		var found: Array[Char] = mob._find_visible_heroes()
		t.check(found.size() == 3, "all three heroes visible")
		t.check(found[0] == near_hero, "nearest hero first")
		t.check(found[1] == mid_hero, "middle hero second")
		t.check(found[2] == far_hero, "farthest hero last")
	mob.free()
	far_hero.free()
	mid_hero.free()
	near_hero.free()

func _test_alert_targets_nearest_hero(t: Object) -> void:
	var level := FakeLevel.new()
	var mob := Mob.new()
	mob.pos = ConstantsData.xy_to_pos(10, 10)
	mob.level = level
	mob.state = Mob.AIState.SLEEPING
	var far_hero := _make_hero(level, 17, 10)
	var near_hero := _make_hero(level, 12, 10)
	level.heroes = [far_hero, near_hero]

	mob.alert()

	t.check(mob.target == near_hero, "alert() targets the nearest hero")
	t.check(mob.state == Mob.AIState.HUNTING, "alert() wakes mob to HUNTING")
	mob.free()
	far_hero.free()
	near_hero.free()

func _test_invisible_and_dead_heroes_excluded(t: Object) -> void:
	var level := FakeLevel.new()
	var mob := Mob.new()
	mob.pos = ConstantsData.xy_to_pos(10, 10)
	mob.level = level
	var near_invisible := _make_hero(level, 11, 10)
	near_invisible.invisible = 1
	var mid_dead := _make_hero(level, 13, 10)
	mid_dead.is_alive = false
	var far_hero := _make_hero(level, 16, 10)
	level.heroes = [near_invisible, mid_dead, far_hero]

	var found: Array[Char] = mob._find_visible_heroes()
	t.check(found.size() == 1, "invisible and dead heroes excluded")
	t.check(found[0] == far_hero, "only the visible living hero remains")
	mob.free()
	near_invisible.free()
	mid_dead.free()
	far_hero.free()
