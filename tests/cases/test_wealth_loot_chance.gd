extends RefCounted
## Ring of Wealth must boost mob loot drop chance (upstream Mob.lootChance
## multiplies by RingOfWealth.dropChanceMultiplier = 1.15^bonus). Covers:
##   - a killer hero without a wealth ring gets no boost
##   - a worn wealth ring multiplies the loot chance by 1.15^bonus
##   - higher ring levels give a larger multiplier
##   - the boost stacks multiplicatively with Bounty Hunter preparation
##   - unequipping the ring removes the boost

func run(t: Object) -> void:
	_test_no_ring_no_boost(t)
	_test_ring_scales_loot_chance(t)
	_test_stacks_with_bounty_hunter(t)
	_test_unequip_clears_boost(t)

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	return hero

func _make_wealth_ring(ring_level: int) -> Object:
	var ring: Object = Generator.create_item("ring_of_wealth")
	ring.level = ring_level
	ring.cursed = false
	return ring

func _test_no_ring_no_boost(t: Object) -> void:
	var mob := Mob.new()
	var hero := _make_hero()
	t.check(is_equal_approx(mob._loot_chance_multiplier(hero), 1.0),
		"A hero without a wealth ring gets no loot boost")
	t.check(is_equal_approx(mob._loot_chance_multiplier(null), 1.0),
		"No killer means no loot boost")
	hero.free()
	mob.free()

func _test_ring_scales_loot_chance(t: Object) -> void:
	var mob := Mob.new()
	var hero := _make_hero()
	hero.belongings.equip_ring(_make_wealth_ring(1), true)
	var lvl1: float = mob._loot_chance_multiplier(hero)
	t.check(is_equal_approx(lvl1, 1.15),
		"A +1 wealth ring multiplies loot chance by 1.15")
	hero.free()

	var hero3 := _make_hero()
	hero3.belongings.equip_ring(_make_wealth_ring(3), true)
	var lvl3: float = mob._loot_chance_multiplier(hero3)
	t.check(is_equal_approx(lvl3, pow(1.15, 3.0)),
		"A +3 wealth ring multiplies loot chance by 1.15^3")
	t.check(lvl3 > lvl1, "Higher ring levels give a larger loot multiplier")
	hero3.free()
	mob.free()

func _test_stacks_with_bounty_hunter(t: Object) -> void:
	var mob := Mob.new()
	var hero := _make_hero()
	hero.hero_subclass = ConstantsData.HeroSubclass.ASSASSIN
	hero.talent_levels["assassin_bounty_hunter"] = 2
	var prep := AssassinPreparation.new()
	prep.turns_invis = 5
	hero.add_buff(prep)
	hero.belongings.equip_ring(_make_wealth_ring(2), true)
	var expected: float = (1.0 + 0.16) * pow(1.15, 2.0)
	t.check(is_equal_approx(mob._loot_chance_multiplier(hero), expected),
		"Wealth ring stacks multiplicatively with Bounty Hunter preparation")
	hero.free()
	mob.free()

func _test_unequip_clears_boost(t: Object) -> void:
	var mob := Mob.new()
	var hero := _make_hero()
	hero.belongings.equip_ring(_make_wealth_ring(2), true)
	hero.belongings.unequip("ring_left")
	t.check(is_equal_approx(mob._loot_chance_multiplier(hero), 1.0),
		"Unequipping the wealth ring removes the loot boost")
	hero.free()
	mob.free()
