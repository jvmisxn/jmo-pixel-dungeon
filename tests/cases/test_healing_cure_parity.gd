extends RefCounted
## Upstream PotionOfHealing.cure parity: the healing potion and Dreamfoil
## (upstream Mageroyal) share the same nine-debuff cure list, applied to any
## character; Dreamfoil no longer cures the old mind-debuff list (Terror,
## Charm, Amok are untouched).

class FakeLevel:
	extends RefCounted

	var chars_by_pos: Dictionary = {}

	func find_char_at(cell: int) -> Variant:
		return chars_by_pos.get(cell, null)

func run(t: Object) -> void:
	_test_cure_list(t)
	_test_healing_drink_cures(t)
	_test_healing_shatter_cures_target(t)
	_test_dreamfoil_cures_hero(t)
	_test_dreamfoil_cures_mob_then_sleeps(t)

func _make_char(cell: int) -> Char:
	var ch: Char = Char.new()
	ch.pos = cell
	ch.hp = 10
	ch.hp_max = 20
	ch.ht = 20
	ch.name = "test char"
	return ch

func _apply_curables(ch: Char) -> void:
	for id: String in Potion.PotionHealing.CURE_IDS:
		var b: Buff = Buff.new()
		b.buff_id = id
		b.buff_name = id
		ch.add_buff(b)

func _check_all_cured(t: Object, ch: Char, label: String) -> void:
	for id: String in Potion.PotionHealing.CURE_IDS:
		t.check(not ch.has_buff(id), "%s cures %s" % [label, id])

func _test_cure_list(t: Object) -> void:
	# Upstream PotionOfHealing.cure detaches exactly these nine debuffs.
	var expected: Array[String] = [
		"Poison", "Cripple", "Weakness", "Vulnerable", "Bleeding",
		"Blindness", "Drowsy", "Slow", "Vertigo",
	]
	t.check(Potion.PotionHealing.CURE_IDS == expected, "cure list matches upstream PotionOfHealing.cure")

func _test_healing_drink_cures(t: Object) -> void:
	var hero: Char = _make_char(10)
	_apply_curables(hero)
	var potion: Potion = Potion.create("healing")
	potion.drink(hero)
	t.check(hero.hp == hero.hp_max, "healing potion heals to full")
	_check_all_cured(t, hero, "healing drink")
	hero.free()

func _test_healing_shatter_cures_target(t: Object) -> void:
	var level := FakeLevel.new()
	var target: Char = _make_char(15)
	level.chars_by_pos[15] = target
	_apply_curables(target)
	var potion: Potion = Potion.create("healing")
	potion.shatter(15, level)
	t.check(target.hp == target.hp_max, "healing shatter heals the target")
	_check_all_cured(t, target, "healing shatter")
	target.free()

func _test_dreamfoil_cures_hero(t: Object) -> void:
	var hero: Char = _make_char(20)
	hero.is_hero = true
	_apply_curables(hero)
	# Old mind-debuff behavior is gone: Terror/Charm/Amok stay attached.
	for id: String in ["Terror", "Charm", "Amok"]:
		var b: Buff = Buff.new()
		b.buff_id = id
		b.buff_name = id
		hero.add_buff(b)
	var plant: Dreamfoil = Dreamfoil.new()
	plant._do_effect(hero, null)
	_check_all_cured(t, hero, "Dreamfoil (hero)")
	for id: String in ["Terror", "Charm", "Amok"]:
		t.check(hero.has_buff(id), "Dreamfoil no longer cures %s" % id)
	t.check(not hero.has_buff("Sleep"), "Dreamfoil does not sleep the hero")
	hero.free()

func _test_dreamfoil_cures_mob_then_sleeps(t: Object) -> void:
	# Upstream Mageroyal cures ANY character; the port then keeps its
	# sleep-lesser-creatures adaptation for mobs.
	var mob: Char = _make_char(30)
	_apply_curables(mob)
	var plant: Dreamfoil = Dreamfoil.new()
	plant._do_effect(mob, null)
	_check_all_cured(t, mob, "Dreamfoil (mob)")
	t.check(mob.has_buff("Sleep"), "Dreamfoil still sleeps mobs (port adaptation)")
	mob.free()
