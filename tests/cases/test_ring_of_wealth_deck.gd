extends RefCounted
## Ring of Wealth bonus-drop deck (upstream RingOfWealth.tryForBonusDrop).
## Covers:
##   - no wealth ring: no drops, no trackers attached
##   - first qualifying kill seeds both counter trackers in upstream ranges
##   - an exhausted tries deck pays out a consumable and refills
##   - an exhausted equip deck pays out uncursed equipment and refills
##   - equipment drops respect the (bonus+1)/2 minimum item level
##   - consumable generators never return null at any tier
##   - two worn wealth rings: full bonus sums, equip bonus caps the 2nd at +2
##   - tracker counts survive a serialize/deserialize round trip

func run(t: Object) -> void:
	_test_no_ring_no_deck(t)
	_test_deck_seeding(t)
	_test_consumable_payout(t)
	_test_equipment_payout(t)
	_test_equipment_min_level(t)
	_test_consumable_generators(t)
	_test_two_ring_bonus_cap(t)
	_test_tracker_persistence(t)

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	return hero

func _make_wealth_hero(ring_level: int) -> Hero:
	var hero := _make_hero()
	var ring: Object = Generator.create_item("ring_of_wealth")
	ring.level = ring_level
	ring.cursed = false
	hero.belongings.equip_ring(ring, true)
	return hero

func _test_no_ring_no_deck(t: Object) -> void:
	var hero := _make_hero()
	var drops: Array = Ring.wealth_try_for_bonus_drop(hero, 1)
	t.check(drops.is_empty(), "No wealth ring yields no bonus drops")
	t.check(hero.get_buff("WealthTriesTracker") == null,
		"No wealth ring attaches no tries tracker")
	t.check(hero.get_buff("WealthEquipTracker") == null,
		"No wealth ring attaches no equip tracker")
	hero.free()

func _test_deck_seeding(t: Object) -> void:
	var hero := _make_wealth_hero(1)
	Ring.wealth_try_for_bonus_drop(hero, 1)
	var tries: WealthTriesTracker = hero.get_buff("WealthTriesTracker") as WealthTriesTracker
	var equip: WealthEquipTracker = hero.get_buff("WealthEquipTracker") as WealthEquipTracker
	t.check(tries != null, "First deck query seeds the tries tracker")
	t.check(equip != null, "First deck query seeds the equip tracker")
	if tries != null:
		t.check(tries.count >= -1.0 and tries.count <= 19.0,
			"Tries deck seeded with NormalIntRange(0,20) minus the first try")
	if equip != null:
		t.check(equip.count >= 4.0 and equip.count <= 10.0,
			"Equip deck seeded with NormalIntRange(5,10)")
	hero.free()

func _test_consumable_payout(t: Object) -> void:
	var hero := _make_wealth_hero(2)
	Ring.wealth_try_for_bonus_drop(hero, 1)
	var tries: WealthTriesTracker = hero.get_buff("WealthTriesTracker") as WealthTriesTracker
	var equip: WealthEquipTracker = hero.get_buff("WealthEquipTracker") as WealthEquipTracker
	tries.count = 1.0
	equip.count = 5.0
	var drops: Array = Ring.wealth_try_for_bonus_drop(hero, 1)
	t.check(drops.size() >= 1, "Exhausting the tries deck pays out a drop")
	t.check(tries.count > 0.0 or drops.size() > 1,
		"Tries deck refills after paying out")
	t.check(equip.count < 5.0, "Consumable payout counts the equip deck down")
	for drop: Variant in drops:
		t.check(drop is Item, "Consumable payout is an Item")
	hero.free()

func _test_equipment_payout(t: Object) -> void:
	var hero := _make_wealth_hero(2)
	Ring.wealth_try_for_bonus_drop(hero, 1)
	var tries: WealthTriesTracker = hero.get_buff("WealthTriesTracker") as WealthTriesTracker
	var equip: WealthEquipTracker = hero.get_buff("WealthEquipTracker") as WealthEquipTracker
	tries.count = 1.0
	equip.count = 0.0
	var drops: Array = Ring.wealth_try_for_bonus_drop(hero, 1)
	t.check(drops.size() >= 1, "Exhausted equip deck pays out equipment")
	if drops.size() >= 1:
		var drop: Item = drops[0]
		var is_equip: bool = drop is Weapon or drop is Armor \
			or drop is Ring or drop is Artifact
		t.check(is_equip, "Equipment payout is a weapon/armor/ring/artifact")
		t.check(not drop.cursed, "Equipment payout is never cursed")
		t.check(drop.cursed_known, "Equipment payout has curse state known")
	t.check(equip.count >= 4.0, "Equip deck refills with NormalIntRange(5,10)")
	hero.free()

func _test_equipment_min_level(t: Object) -> void:
	for i: int in range(20):
		var drop: Item = Ring.wealth_gen_equipment_drop(5)
		t.check(drop != null, "Equipment generator never returns null")
		if drop != null and drop.is_upgradeable():
			t.check(drop.level >= 3,
				"Bonus level 5 equipment is at least +3 ((5+1)/2)")

func _test_consumable_generators(t: Object) -> void:
	var all_ok: bool = true
	for i: int in range(40):
		var low: Item = Ring._wealth_low_consumable()
		var mid: Item = Ring._wealth_mid_consumable()
		var high: Item = Ring._wealth_high_consumable()
		var tiered: Item = Ring.wealth_gen_consumable_drop(i % 15)
		if low == null or mid == null or high == null or tiered == null:
			all_ok = false
		if low != null and low.quantity < 1:
			all_ok = false
	t.check(all_ok, "Consumable generators never return null or empty stacks")

func _test_two_ring_bonus_cap(t: Object) -> void:
	var hero := _make_hero()
	var first: Object = Generator.create_item("ring_of_wealth")
	first.level = 3
	first.cursed = false
	hero.belongings.equip_ring(first, true)
	var second: Object = Generator.create_item("ring_of_wealth")
	second.level = 3
	second.cursed = false
	hero.belongings.equip_ring(second, false)
	t.check(Ring.wealth_bonus(hero) == 6,
		"Two +3 wealth rings give a full drop-chance bonus of 6")
	t.check(Ring._wealth_equip_bonus(hero) == 5,
		"Equip bonus caps the second wealth ring at +2 (3 + 2)")
	hero.free()

func _test_tracker_persistence(t: Object) -> void:
	var tracker := WealthTriesTracker.new()
	tracker.count = 7.0
	var data: Dictionary = tracker.serialize()
	var restored := WealthTriesTracker.new()
	restored.deserialize(data)
	t.check(is_equal_approx(restored.count, 7.0),
		"Tries tracker count survives serialize/deserialize")
	t.check(tracker.revive_persists, "Tries tracker persists through revives")
	var equip := WealthEquipTracker.new()
	equip.count = 4.0
	var equip_restored := WealthEquipTracker.new()
	equip_restored.deserialize(equip.serialize())
	t.check(is_equal_approx(equip_restored.count, 4.0),
		"Equip tracker count survives serialize/deserialize")
	tracker.free()
	restored.free()
	equip.free()
	equip_restored.free()
