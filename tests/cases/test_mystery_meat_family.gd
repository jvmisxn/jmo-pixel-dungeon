extends RefCounted
## Mystery-meat family parity:
## - MysteryMeat.effect(): Burning reignite / Roots x2 / Poison HT/5 /
##   Slow / nothing (upstream Random.Int(5) table).
## - FrozenCarpaccio.effect(): Invisibility / Barkskin HT/4 / cure / heal HT/4
##   / nothing; no flat heal on eat.
## - ChargrilledMeat: energy 150, value 8, no effect.
## - Frost (port Frozen) freezes one carried unit: mystery meat becomes a
##   Frozen Carpaccio instead of being destroyed; potions shatter.


func run(t: Object) -> void:
	_test_mystery_effect_table(t)
	_test_carpaccio_effect_table(t)
	_test_chargrilled_item(t)
	_test_frozen_converts_mystery_meat(t)
	_test_frozen_removes_potion(t)


func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	return hero


func _test_mystery_effect_table(t: Object) -> void:
	var meat: Food = Food.create("mystery_meat")
	t.check(meat.hunger_satisfy == 150.0, "mystery meat satisfies HUNGRY/2 = 150")
	t.check(meat.value() == 5, "mystery meat value is 5 (upstream)")

	var hero := _make_hero()
	meat._mystery_effect(hero, 0)
	var burn: Variant = hero.get_buff("Burning")
	t.check(burn != null, "roll 0 ignites the hero (Burning reignite)")

	hero = _make_hero()
	meat._mystery_effect(hero, 1)
	var roots: Variant = hero.get_buff("Rooted")
	t.check(roots != null, "roll 1 roots the hero")
	t.check(
		roots != null and roots.time_left == Rooted.BASE_DURATION * 2.0,
		"roots last Roots.DURATION*2 turns"
	)

	hero = _make_hero()
	meat._mystery_effect(hero, 2)
	var poison: Variant = hero.get_buff("Poison")
	t.check(poison != null, "roll 2 poisons the hero")
	t.check(
		poison != null and absf(poison.time_left - float(hero.ht) / 5.0) < 0.001,
		"poison strength is HT/5"
	)

	hero = _make_hero()
	meat._mystery_effect(hero, 3)
	var slow: Variant = hero.get_buff("Slow")
	t.check(slow != null, "roll 3 slows the hero")
	t.check(
		slow != null and slow.time_left == Slow.BASE_DURATION,
		"slow lasts Slow.DURATION turns"
	)

	hero = _make_hero()
	meat._mystery_effect(hero, 4)
	t.check(
		hero.get_buff("Burning") == null and hero.get_buff("Rooted") == null
				and hero.get_buff("Poison") == null and hero.get_buff("Slow") == null,
		"roll 4 does nothing (upstream empty case)"
	)


func _test_carpaccio_effect_table(t: Object) -> void:
	var carpaccio: Food = Food.create("frozen_carpaccio")
	t.check(carpaccio.hunger_satisfy == 150.0, "carpaccio satisfies HUNGRY/2 = 150")
	t.check(carpaccio.heal_amount == 0, "carpaccio has no flat heal (upstream)")
	t.check(carpaccio.value() == 10, "carpaccio value is 10 (upstream)")

	var hero := _make_hero()
	carpaccio._carpaccio_effect(hero, 0)
	t.check(hero.get_buff("Invisibility") != null, "roll 0 grants Invisibility")

	hero = _make_hero()
	carpaccio._carpaccio_effect(hero, 1)
	var bark: Variant = hero.get_buff("Barkskin")
	t.check(bark != null, "roll 1 grants Barkskin")
	t.check(
		bark != null and bark.get_level() == int(hero.ht / 4.0),
		"barkskin level is HT/4"
	)

	hero = _make_hero()
	var slow := Slow.new()
	hero.add_buff(slow)
	carpaccio._carpaccio_effect(hero, 2)
	t.check(hero.get_buff("Slow") == null, "roll 2 cures debuffs (PotionOfHealing.cure)")

	hero = _make_hero()
	hero.hp = hero.ht / 2
	carpaccio._carpaccio_effect(hero, 3)
	t.check(
		hero.hp == hero.ht / 2 + int(hero.ht / 4.0),
		"roll 3 heals HT/4"
	)

	hero = _make_hero()
	var hp_before: int = hero.hp
	carpaccio._carpaccio_effect(hero, 4)
	t.check(
		hero.hp == hp_before and hero.get_buff("Invisibility") == null
				and hero.get_buff("Barkskin") == null,
		"roll 4 does nothing (upstream empty case)"
	)


func _test_chargrilled_item(t: Object) -> void:
	var steak: Food = Food.create("chargrilled_meat")
	t.check(steak.item_name == "Chargrilled Meat", "chargrilled meat exists as a food")
	t.check(steak.hunger_satisfy == 150.0, "chargrilled meat satisfies HUNGRY/2 = 150")
	t.check(steak.heal_amount == 0, "chargrilled meat has no heal")
	t.check(not steak.random_effect, "chargrilled meat has no random effect")
	t.check(steak.value() == 8, "chargrilled meat value is 8 (upstream)")
	t.check(
		Generator.SPRITE_INDICES.get("chargrilled_meat", -1) == 433,
		"chargrilled meat uses the STEAK sprite index"
	)


func _test_frozen_converts_mystery_meat(t: Object) -> void:
	var hero := _make_hero()
	var meat: Food = Food.create("mystery_meat")
	meat.quantity = 2
	hero.belongings.add_item(meat)

	Frozen.freeze_carried_item(hero, meat)

	var meat_left: int = 0
	var carpaccio_count: int = 0
	for item: Variant in hero.belongings.backpack:
		if item.get("item_id") == "mystery_meat":
			meat_left += item.quantity
		elif item.get("item_id") == "frozen_carpaccio":
			carpaccio_count += item.quantity
	t.check(meat_left == 1, "freezing removes exactly one mystery meat from the stack")
	t.check(carpaccio_count == 1, "frozen mystery meat becomes a Frozen Carpaccio")

	# End-to-end: the Frozen buff attach path performs the same conversion
	# when mystery meat is the only freezable carried item.
	var hero2 := _make_hero()
	var meat2: Food = Food.create("mystery_meat")
	hero2.belongings.add_item(meat2)
	hero2.add_buff(Frozen.new())
	var converted: bool = false
	for item: Variant in hero2.belongings.backpack:
		if item.get("item_id") == "frozen_carpaccio":
			converted = true
	t.check(converted, "Frozen buff attach converts carried mystery meat")


func _test_frozen_removes_potion(t: Object) -> void:
	var hero := _make_hero()
	var potion: Item = Generator.create_item("healing")
	hero.belongings.add_item(potion)

	Frozen.freeze_carried_item(hero, potion)

	var potion_left: bool = false
	for item: Variant in hero.belongings.backpack:
		if item.get("category") == ConstantsData.ItemCategory.POTION:
			potion_left = true
	t.check(not potion_left, "freezing removes the carried potion")
