extends RefCounted
## Mage Scholar's Intuition (upstream Talent.SCHOLARS_INTUITION, Mage T1):
## Talent.itemIDSpeedFactor makes wands consume 1+2*points ID uses per zap
## (3x at +1, 5x at +2), and Wand.wandUsed identifies the wand immediately
## at +2 regardless of remaining usesLeftToID. There is no on-pickup
## identify in current upstream; the port's old 30%/60% scroll+wand pickup
## roll was removed with this parity pass.

func run(t: Object) -> void:
	_test_no_talent_single_use(t)
	_test_plus_one_triple_speed(t)
	_test_plus_one_pool_clamp(t)
	_test_plus_two_instant_id(t)
	_test_no_pickup_identify(t)
	_test_talent_registered_t1(t)

func _make_mage(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_scholars_intuition"] = points
	return hero

func _test_no_talent_single_use(t: Object) -> void:
	var hero := _make_mage(0)
	var wand := Wand.new()
	wand._use_for_identification(hero)
	t.check(is_equal_approx(wand._uses_left_to_id, Wand.USES_TO_ID - 1.0),
		"Without the talent a zap consumes 1 ID use, left=%s" % wand._uses_left_to_id)
	t.check(is_equal_approx(wand._available_uses_to_id, Wand.USES_TO_ID / 2.0 - 1.0),
		"Without the talent a zap consumes 1 available use")
	hero.free()

func _test_plus_one_triple_speed(t: Object) -> void:
	var hero := _make_mage(1)
	var wand := Wand.new()
	wand._use_for_identification(hero)
	t.check(is_equal_approx(wand._uses_left_to_id, Wand.USES_TO_ID - 3.0),
		"+1 consumes 3 ID uses per zap (itemIDSpeedFactor 1+2*1), left=%s" % wand._uses_left_to_id)
	t.check(not wand.is_identified(),
		"+1 does not identify the wand on the first zap")
	hero.free()

func _test_plus_one_pool_clamp(t: Object) -> void:
	var hero := _make_mage(1)
	var wand := Wand.new()
	wand._use_for_identification(hero)
	wand._use_for_identification(hero)
	t.check(is_equal_approx(wand._available_uses_to_id, 0.0),
		"Second +1 zap is clamped to the remaining pool (min(available, 3))")
	t.check(is_equal_approx(wand._uses_left_to_id, Wand.USES_TO_ID - 5.0),
		"Pool clamp: two +1 zaps consume 3 then 2 uses, left=%s" % wand._uses_left_to_id)
	var left_before: float = wand._uses_left_to_id
	wand._use_for_identification(hero)
	t.check(is_equal_approx(wand._uses_left_to_id, left_before),
		"An empty available pool blocks further ID progress")
	hero.free()

func _test_plus_two_instant_id(t: Object) -> void:
	var hero := _make_mage(2)
	var wand := Wand.new()
	wand._use_for_identification(hero)
	t.check(wand.is_identified(),
		"+2 identifies a wand after a single zap (upstream Wand.wandUsed)")
	hero.free()

func _test_no_pickup_identify(t: Object) -> void:
	var hero := _make_mage(2)
	var wand := Wand.new()
	hero.on_item_picked_up(wand)
	t.check(not wand.is_identified(),
		"Pickup no longer identifies wands (no on-pickup effect upstream)")
	hero.free()

func _test_talent_registered_t1(t: Object) -> void:
	var talent: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_scholars_intuition")
	t.check(talent != null, "Scholar's Intuition is registered for the Mage")
	if talent != null:
		t.check(talent.tier == 1, "Scholar's Intuition sits at tier 1 (upstream roster)")
		t.check(talent.implemented, "Scholar's Intuition is live, not inert")
