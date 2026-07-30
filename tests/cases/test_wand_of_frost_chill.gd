extends RefCounted
## WandOfFrost fidelity (upstream WandOfFrost.onZap): the bolt applies a real
## Chill buff (2+lvl turns, 4+lvl in water) instead of the old Cripple
## stand-in, already-chilled targets take 0.9333^turns reduced damage, and a
## Frozen target cannot be affected at all. Chill itself no longer
## auto-upgrades to Frozen at 10+ turns (upstream Chill never converts).

class _FakeLevel:
	extends RefCounted
	var target_char: Char = null
	var water_cells: Dictionary = {}

	func find_char_at(cell: int) -> Variant:
		if target_char != null and target_char.pos == cell:
			return target_char
		return null

	func get_terrain(cell: int) -> int:
		if water_cells.has(cell):
			return ConstantsData.Terrain.WATER
		return ConstantsData.Terrain.EMPTY

class _FixedFrost extends Wand.WandOfFrost:
	var fixed_damage: int = 30
	func roll_zap_damage(_hero: Char = null) -> int:
		return fixed_damage

func run(t: Object) -> void:
	_test_zap_applies_chill(t)
	_test_water_extends_chill(t)
	_test_chilled_target_takes_reduced_damage(t)
	_test_frozen_target_unaffected(t)
	_test_chill_does_not_convert_to_frozen(t)

func _center() -> int:
	return ConstantsData.xy_to_pos(16, 16)

func _make_victim(cell: int) -> Char:
	var c: Char = Char.new()
	c.name = "FrostTarget"
	c.hp = 100
	c.hp_max = 100
	c.is_alive = true
	c.pos = cell
	return c

func _make_hero(level: Object) -> Char:
	var hero: Char = Char.new()
	hero.name = "FrostCaster"
	hero.hp = 100
	hero.hp_max = 100
	hero.is_alive = true
	hero.pos = _center() - 1
	hero.level = level
	return hero

func _zap(wand_level: int, victim: Char, level: _FakeLevel, dmg: int = 30) -> void:
	var wand := _FixedFrost.new()
	wand.level = wand_level
	wand.fixed_damage = dmg
	var hero: Char = _make_hero(level)
	wand.on_zap(hero, [victim.pos] as Array[int])
	hero.free()

func _test_zap_applies_chill(t: Object) -> void:
	var cell: int = _center()
	var victim: Char = _make_victim(cell)
	var level := _FakeLevel.new()
	level.target_char = victim

	_zap(2, victim, level)

	t.check(victim.hp == 70, "frost bolt deals full damage to an unchilled target")
	var chill: Chill = victim.get_buff("Chill") as Chill
	t.check(chill != null, "frost bolt applies a real Chill buff")
	t.check(chill != null and is_equal_approx(chill.left, 4.0),
			"frost chill lasts 2 + wand level turns on dry land")
	t.check(not victim.has_buff("Cripple"), "frost bolt no longer applies Cripple")
	t.check(not victim.has_buff("Paralysis"), "frost bolt no longer paralyzes")
	victim.free()

func _test_water_extends_chill(t: Object) -> void:
	var cell: int = _center()
	var victim: Char = _make_victim(cell)
	var level := _FakeLevel.new()
	level.target_char = victim
	level.water_cells[cell] = true

	_zap(3, victim, level)

	var chill: Chill = victim.get_buff("Chill") as Chill
	t.check(chill != null and is_equal_approx(chill.left, 7.0),
			"frost chill lasts 4 + wand level turns in water")
	victim.free()

func _test_chilled_target_takes_reduced_damage(t: Object) -> void:
	var cell: int = _center()
	var victim: Char = _make_victim(cell)
	var level := _FakeLevel.new()
	level.target_char = victim
	var chill := Chill.new()
	chill.extend(5.0)
	victim.add_buff(chill)

	_zap(0, victim, level, 30)

	# 30 * 0.9333^5 = 21.15 -> 21 damage
	t.check(victim.hp == 79,
			"chilled target takes 0.9333^turns reduced frost damage")

	var deep: Char = _make_victim(cell)
	level.target_char = deep
	var heavy := Chill.new()
	heavy.extend(20.0)
	deep.add_buff(heavy)
	_zap(0, deep, level, 30)
	# reduction turns cap at 10: 30 * 0.9333^10 = 15.06 -> 15 damage
	t.check(deep.hp == 85,
			"frost damage reduction caps at 10 turns of chill")
	victim.free()
	deep.free()

func _test_frozen_target_unaffected(t: Object) -> void:
	var cell: int = _center()
	var victim: Char = _make_victim(cell)
	var level := _FakeLevel.new()
	level.target_char = victim
	var frozen: Frozen = Frozen.new()
	victim.add_buff(frozen)

	_zap(2, victim, level)

	t.check(victim.hp == 100, "frozen target takes no frost bolt damage")
	t.check(not victim.has_buff("Chill"), "frozen target gains no chill")
	victim.free()

func _test_chill_does_not_convert_to_frozen(t: Object) -> void:
	var cell: int = _center()
	var victim: Char = _make_victim(cell)
	var chill := Chill.new()
	chill.extend(12.0)
	victim.add_buff(chill)

	var buff: Chill = victim.get_buff("Chill") as Chill
	if buff != null:
		buff.on_turn()

	t.check(not victim.has_buff("Frozen"),
			"long chill ticks down instead of upgrading to Frozen")
	var after: Chill = victim.get_buff("Chill") as Chill
	t.check(after != null and is_equal_approx(after.left, 11.0),
			"chill loses one turn per tick")
	victim.free()
