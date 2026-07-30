extends RefCounted
## Champion upstream-parity cleanup: choosing the Champion subclass no longer
## attaches the legacy alternating ChampionDualWield passive (upstream has no
## such buff — dual-wielding lives in Belongings.secondWep), and old saves
## that still carry the buff migrate its stored off-hand weapon into
## belongings.second_wep (or the backpack when the slot is taken) before the
## buff removes itself.

func run(t: Object) -> void:
	_test_champion_has_no_legacy_buff(t)
	_test_legacy_buff_migrates_to_empty_slot(t)
	_test_legacy_buff_migrates_to_backpack_when_slot_taken(t)

func _make_champion() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	return hero

func _test_champion_has_no_legacy_buff(t: Object) -> void:
	var hero := _make_champion()
	SubclassAbilities.apply_subclass(hero, ConstantsData.HeroSubclass.CHAMPION)
	t.check(not hero.has_buff("ChampionDualWield"),
		"Choosing Champion no longer attaches the legacy dual-wield buff")
	hero.free()

func _test_legacy_buff_migrates_to_empty_slot(t: Object) -> void:
	var hero := _make_champion()
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	var dagger: Item = Generator.create_item("dagger")
	var legacy := ChampionDualWield.new()
	legacy.secondary_weapon = dagger
	hero.add_buff(legacy)
	t.check(hero.belongings.second_wep == dagger,
		"Legacy buff weapon migrates into the empty off-hand slot")
	t.check(legacy.secondary_weapon == null,
		"Legacy buff no longer holds the weapon after migration")
	hero.free()

func _test_legacy_buff_migrates_to_backpack_when_slot_taken(t: Object) -> void:
	var hero := _make_champion()
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	var mace: Item = Generator.create_item("mace")
	var dagger: Item = Generator.create_item("dagger")
	hero.belongings.equip_second_wep(mace)
	var legacy := ChampionDualWield.new()
	legacy.secondary_weapon = dagger
	hero.add_buff(legacy)
	t.check(hero.belongings.second_wep == mace,
		"Occupied off-hand slot is not displaced by migration")
	t.check(hero.belongings.get_items().has(dagger),
		"Legacy buff weapon lands in the backpack when the slot is taken")
	hero.free()
