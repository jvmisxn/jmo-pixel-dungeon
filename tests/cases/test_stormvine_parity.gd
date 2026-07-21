extends RefCounted
## Stormvine mirrors upstream SPD: ordinary targets get Vertigo only, while
## Warden converts the plant into a short Levitation boon.

func run(t: Object) -> void:
	_test_stormvine_vertigo_only(t)
	_test_stormvine_warden_levitation(t)

func _make_char() -> Char:
	var ch: Char = Char.new()
	ch.name = "test char"
	ch.hp = 20
	ch.hp_max = 20
	ch.ht = 20
	return ch

func _make_hero(subclass_id: int) -> Hero:
	var hero: Hero = Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = subclass_id
	hero.hp = 20
	hero.hp_max = 20
	hero.ht = 20
	return hero

func _test_stormvine_vertigo_only(t: Object) -> void:
	var target: Char = _make_char()
	var stormvine: Stormvine = Stormvine.new()

	stormvine._do_effect(target, null)

	var vertigo: Vertigo = target.get_buff("Vertigo") as Vertigo
	t.check(vertigo != null, "Stormvine applies Vertigo to ordinary targets")
	t.check(not target.has_buff("Rooted"), "Stormvine does not Root ordinary targets")
	t.check(not target.has_buff("Levitation"), "Stormvine does not levitate ordinary targets")
	t.check(
		is_equal_approx(vertigo.time_left, Vertigo.BASE_DURATION),
		"Stormvine Vertigo uses the standard duration"
	)
	target.free()

func _test_stormvine_warden_levitation(t: Object) -> void:
	var hero: Hero = _make_hero(ConstantsData.HeroSubclass.WARDEN)
	var stormvine: Stormvine = Stormvine.new()

	stormvine._do_effect(hero, null)

	var levitation: Levitation = hero.get_buff("Levitation") as Levitation
	t.check(levitation != null, "Warden Stormvine applies Levitation")
	t.check(not hero.has_buff("Vertigo"), "Warden Stormvine does not apply Vertigo")
	t.check(not hero.has_buff("Rooted"), "Warden Stormvine does not apply Rooted")
	t.check(
		is_equal_approx(levitation.time_left, Stormvine.WARDEN_LEVITATION_DURATION),
		"Warden Stormvine levitates for half the base duration"
	)
	hero.free()
