extends RefCounted
## Sleep/freeze producers should use the dedicated buffs, not renamed paralysis.

class FakeLevel:
	extends RefCounted

	var mobs: Array[Node] = []
	var chars_by_pos: Dictionary = {}

	func get_mobs() -> Array[Node]:
		return mobs

	func find_char_at(cell: int) -> Variant:
		return chars_by_pos.get(cell, null)

func run(t: Object) -> void:
	_test_lullaby_uses_sleep_buff(t)
	_test_deepened_sleep_uses_sleep_buff(t)
	_test_dreamfoil_uses_sleep_buff(t)
	_test_icecap_uses_frozen_buff(t)

func _make_char(cell: int, level_ref: Variant = null) -> Char:
	var ch: Char = Char.new()
	ch.pos = cell
	ch.level = level_ref
	ch.hp = 20
	ch.hp_max = 20
	ch.ht = 20
	ch.name = "test char"
	return ch

func _assert_sleep_contract(t: Object, target: Char, label: String) -> void:
	t.check(target.has_buff("Sleep"), label + " applies Sleep")
	t.check(not target.has_buff("Paralysis"), label + " does not apply Paralysis")
	target.take_damage(1, "test")
	t.check(not target.has_buff("Sleep"), label + " wakes on damage")

func _test_lullaby_uses_sleep_buff(t: Object) -> void:
	var level := FakeLevel.new()
	var hero: Char = _make_char(33, level)
	var mob: Char = _make_char(34, level)
	level.mobs = [mob]

	var scroll: Scroll = Scroll.create("lullaby")
	scroll.read_scroll(hero)

	_assert_sleep_contract(t, mob, "Scroll of Lullaby")
	hero.free()
	mob.free()

func _test_deepened_sleep_uses_sleep_buff(t: Object) -> void:
	var level := FakeLevel.new()
	var hero: Char = _make_char(33, level)
	var target: Char = _make_char(34, level)
	level.chars_by_pos[34] = target

	var stone: Stone = Stone.create("deepened_sleep")
	stone._use_deepened_sleep(hero)

	_assert_sleep_contract(t, target, "Stone of Deepened Sleep")
	hero.free()
	target.free()

func _test_dreamfoil_uses_sleep_buff(t: Object) -> void:
	var target: Char = _make_char(40)
	var dreamfoil: Dreamfoil = Dreamfoil.new()

	dreamfoil._do_effect(target, null)

	_assert_sleep_contract(t, target, "Dreamfoil")
	target.free()

func _test_icecap_uses_frozen_buff(t: Object) -> void:
	var level := FakeLevel.new()
	var target: Char = _make_char(50, level)
	level.chars_by_pos[50] = target

	var icecap: Icecap = Icecap.new()
	icecap.pos = 50
	icecap._do_effect(target, level)

	t.check(target.has_buff("Frozen"), "Icecap applies Frozen")
	t.check(not target.has_buff("Paralysis"), "Icecap does not apply Paralysis")
	t.check(target.paralysed == 1, "Frozen increments the paralysis counter")
	target.remove_buff_by_id("Frozen")
	t.check(target.paralysed == 0, "Frozen decrements the paralysis counter")
	target.free()
