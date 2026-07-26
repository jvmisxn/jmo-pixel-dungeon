extends RefCounted
## Warrior Liquid Willpower talent (SPD Talent.onPotionUsed): using a potion
## grants a Barrier of HT * (3% + 3.5% per point) — 6.5%/10% of max HP.
## Upstream setShield semantics keep the larger of existing and new shield.

func run(t: Object) -> void:
	_test_one_point_shield(t)
	_test_two_point_shield(t)
	_test_untalented_no_shield(t)
	_test_larger_existing_barrier_kept(t)
	_test_smaller_existing_barrier_raised(t)
	_test_drink_path_triggers(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hp_max = 100
	hero.ht = 100
	hero.hp = 100
	hero.pos = 100
	if points > 0:
		hero.talent_levels["warrior_liquid_willpower"] = points
	return hero

func _test_one_point_shield(t: Object) -> void:
	var hero := _make_warrior(1)
	hero.on_potion_used()
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null, "One-point potion use grants a Barrier")
	t.check(barrier != null and barrier.get_shielding() == 7,
		"One point shields 6.5% of max HP (100 HT -> 7)")
	hero.free()

func _test_two_point_shield(t: Object) -> void:
	var hero := _make_warrior(2)
	hero.on_potion_used()
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 10,
		"Two points shield 10% of max HP (100 HT -> 10)")
	hero.free()

func _test_untalented_no_shield(t: Object) -> void:
	var hero := _make_warrior(0)
	hero.on_potion_used()
	t.check(hero.get_buff("Barrier") == null,
		"Untalented potion use grants no Barrier")
	hero.free()

func _test_larger_existing_barrier_kept(t: Object) -> void:
	var hero := _make_warrior(2)
	var existing: Barrier = hero.add_buff(Barrier.new()) as Barrier
	existing.set_shield(15)
	hero.on_potion_used()
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 15,
		"A larger existing barrier is kept (15 > 10)")
	hero.free()

func _test_smaller_existing_barrier_raised(t: Object) -> void:
	var hero := _make_warrior(2)
	var existing: Barrier = hero.add_buff(Barrier.new()) as Barrier
	existing.set_shield(4)
	hero.on_potion_used()
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 10,
		"A smaller existing barrier is raised to the talent shield, not stacked (4 -> 10)")
	hero.free()

func _test_drink_path_triggers(t: Object) -> void:
	var hero := _make_warrior(1)
	var potion: Potion = Potion.create("healing")
	hero.belongings.add_item(potion)
	potion.execute(hero)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() >= 7,
		"Drinking a potion through execute() fires Liquid Willpower")
	hero.free()
