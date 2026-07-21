extends RefCounted

class FakeMobLevel:
	extends RefCounted

	var heroes: Array[Char] = []
	var los_enabled: bool = true

	func get_heroes() -> Array[Char]:
		return heroes

	func has_los(_from_pos: int, _to_pos: int) -> bool:
		return los_enabled

	func find_step(_from_pos: int, _target_pos: int) -> int:
		return -1

	func is_passable(_cell: int) -> bool:
		return true

	func find_char_at(_cell: int) -> Variant:
		return null

	func terrain_at(_cell: int) -> int:
		return ConstantsData.Terrain.EMPTY

func run(t: Object) -> void:
	_test_invisible_hero_not_visible_to_mobs(t)
	_test_hunting_mob_loses_invisible_target_at_last_known_cell(t)

func _make_mob(cell: int, level: Variant) -> Mob:
	var mob := Mob.new()
	mob.setup(20, 10, 1000, 1, 4, 0)
	mob.mob_name = "test mob"
	mob.pos = cell
	mob.level = level
	mob.is_alive = true
	return mob

func _make_hero(cell: int, level: Variant) -> Char:
	var hero := Char.new()
	hero.name = "Hero"
	hero.is_hero = true
	hero.pos = cell
	hero.level = level
	hero.hp = 20
	hero.hp_max = 20
	hero.is_alive = true
	return hero

func _test_invisible_hero_not_visible_to_mobs(t: Object) -> void:
	var level := FakeMobLevel.new()
	var mob := _make_mob(ConstantsData.xy_to_pos(10, 10), level)
	var hero := _make_hero(ConstantsData.xy_to_pos(12, 10), level)
	level.heroes = [hero]

	t.check(mob._find_visible_heroes().size() == 1, "Visible hero is detected by a mob")
	hero.invisible = 1
	t.check(mob._find_visible_heroes().is_empty(), "Invisible hero is not detected by a mob")

	mob.free()
	hero.free()

func _test_hunting_mob_loses_invisible_target_at_last_known_cell(t: Object) -> void:
	var level := FakeMobLevel.new()
	var mob := _make_mob(ConstantsData.xy_to_pos(10, 10), level)
	var hero := _make_hero(ConstantsData.xy_to_pos(11, 10), level)
	level.heroes = [hero]
	mob.state = Mob.AIState.HUNTING
	mob.target = hero
	mob.target_pos = mob.pos
	hero.invisible = 1

	mob._act_hunting()

	t.check(hero.hp == hero.hp_max, "Hunting mob does not attack an adjacent invisible hero")
	t.check(mob.state == Mob.AIState.WANDERING, "Hunting mob gives up at the invisible target's last known cell")
	t.check(mob.target == null, "Hunting mob clears the invisible target after losing it")
	t.check(mob.target_pos == -1, "Hunting mob clears last-known target position after losing invis target")

	mob.free()
	hero.free()
