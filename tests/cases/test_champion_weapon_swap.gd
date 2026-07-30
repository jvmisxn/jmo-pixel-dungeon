extends RefCounted
## Champion instant weapon swap (upstream MeleeWeapon.Charger.doAction):
## Belongings.swap_weapons exchanges the primary and off-hand weapons for
## free, Champion-only; an empty off-hand with a full backpack refuses the
## swap; the WeaponCharger buff surfaces on the buff bar only for Champions
## (the port's ActionIndicator stand-in, tapped to trigger the swap).

func run(t: Object) -> void:
	_test_non_champion_refused(t)
	_test_swap_exchanges_weapons(t)
	_test_swap_into_empty_offhand(t)
	_test_empty_offhand_full_backpack_refused(t)
	_test_full_backpack_with_offhand_allowed(t)
	_test_charger_icon_champion_only(t)

func _make_champion() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	return hero

func _fill_backpack(belongings: Belongings) -> void:
	while belongings.has_space():
		belongings.backpack.append(Generator.create_item("dagger"))

func _test_non_champion_refused(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	var sword: Item = Generator.create_item("sword")
	var dagger: Item = Generator.create_item("dagger")
	hero.belongings.weapon = sword
	hero.belongings.second_wep = dagger
	t.check(not hero.belongings.swap_weapons(), "Non-Champion Duelist cannot swap")
	t.check(hero.belongings.weapon == sword and hero.belongings.second_wep == dagger,
		"Refused swap leaves both slots untouched")
	var ownerless := Belongings.new()
	ownerless.weapon = Generator.create_item("sword")
	t.check(not ownerless.swap_weapons(), "Ownerless belongings cannot swap")
	hero.free()

func _test_swap_exchanges_weapons(t: Object) -> void:
	var hero := _make_champion()
	var sword: Item = Generator.create_item("sword")
	var dagger: Item = Generator.create_item("dagger")
	hero.belongings.weapon = sword
	hero.belongings.second_wep = dagger
	t.check(hero.belongings.swap_weapons(), "Champion swap succeeds with both slots filled")
	t.check(hero.belongings.weapon == dagger, "Off-hand weapon becomes the primary")
	t.check(hero.belongings.second_wep == sword, "Primary weapon moves to the off-hand")
	t.check(hero.belongings.swap_weapons() and hero.belongings.weapon == sword,
		"Swapping again restores the original arrangement")
	hero.free()

func _test_swap_into_empty_offhand(t: Object) -> void:
	var hero := _make_champion()
	var sword: Item = Generator.create_item("sword")
	hero.belongings.weapon = sword
	hero.belongings.second_wep = null
	t.check(hero.belongings.swap_weapons(),
		"Swap with an empty off-hand is allowed with backpack space")
	t.check(hero.belongings.weapon == null, "Primary slot is emptied")
	t.check(hero.belongings.second_wep == sword, "Primary weapon is stowed in the off-hand")
	hero.free()

func _test_empty_offhand_full_backpack_refused(t: Object) -> void:
	var hero := _make_champion()
	var sword: Item = Generator.create_item("sword")
	hero.belongings.weapon = sword
	hero.belongings.second_wep = null
	_fill_backpack(hero.belongings)
	t.check(not hero.belongings.swap_weapons(),
		"Empty off-hand plus full backpack refuses the swap (upstream swap_full)")
	t.check(hero.belongings.weapon == sword, "Refused swap keeps the primary weapon")
	hero.free()

func _test_full_backpack_with_offhand_allowed(t: Object) -> void:
	var hero := _make_champion()
	var sword: Item = Generator.create_item("sword")
	var dagger: Item = Generator.create_item("dagger")
	hero.belongings.weapon = sword
	hero.belongings.second_wep = dagger
	_fill_backpack(hero.belongings)
	t.check(hero.belongings.swap_weapons(), "Full backpack does not block a two-weapon swap")
	t.check(hero.belongings.weapon == dagger and hero.belongings.second_wep == sword,
		"Two-weapon swap works with a full backpack")
	hero.free()

func _test_charger_icon_champion_only(t: Object) -> void:
	var duelist := Hero.new()
	duelist.init_class(ConstantsData.HeroClass.DUELIST)
	var charger: WeaponCharger = duelist.get_buff("WeaponCharger") as WeaponCharger
	t.check(charger != null and not charger.show_in_ui, "Base Duelist charger stays hidden")
	if charger != null:
		charger.on_turn()
		t.check(not charger.show_in_ui, "Base Duelist charger stays hidden after a turn")
	duelist.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	if charger != null:
		charger.on_turn()
		t.check(charger.show_in_ui, "Champion charger surfaces as the swap indicator")
	duelist.free()
