extends RefCounted
## Rogue Enhanced Rings (T3). Upstream: Talent.onArtifactUsed prolongs the
## EnhancedRings buff for 3*points turns when the cloak is used, and
## Ring.buffedLvl adds +1 while the buff is live. Port adaptation: Ring of
## Might's cached STR/HP bonus is re-applied on buff attach/detach instead of
## upstream's updateHT call.

func run(t: Object) -> void:
	_test_registry(t)
	_test_cloak_grants_buff(t)
	_test_no_talent_no_buff(t)
	_test_ring_bonus_while_live(t)
	_test_cursed_ring_bonus(t)
	_test_unequipped_ring_unaffected(t)
	_test_might_refresh(t)
	_test_prolong_never_shortens(t)
	_test_expiry_restores_bonus(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_enhanced_rings"] = points
	return hero

func _make_cloak() -> Artifact:
	var cloak: Artifact = Generator.create_item("cloak_of_shadows")
	cloak.charge = cloak.charge_max
	return cloak

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_enhanced_rings")
	t.check(info != null, "rogue_enhanced_rings is registered for the Rogue")
	t.check(info != null and info.implemented,
		"rogue_enhanced_rings is marked implemented")
	t.check(info != null and info.tier == 3, "rogue_enhanced_rings is tier 3")
	t.check(info != null and info.max_points == 3,
		"rogue_enhanced_rings has 3 max points")
	var lc: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_light_cloak")
	t.check(lc != null and lc.implemented and lc.tier == 3,
		"rogue_light_cloak is registered implemented at tier 3")

func _test_cloak_grants_buff(t: Object) -> void:
	for points: int in [1, 2, 3]:
		var hero := _make_rogue(points)
		var cloak := _make_cloak()
		var ok: bool = cloak.activate(hero)
		t.check(ok, "+%d cloak activation succeeds" % points)
		var buff: Variant = hero.get_buff("EnhancedRings")
		t.check(buff != null, "+%d cloak use attaches EnhancedRings" % points)
		var expected: float = 3.0 * points
		t.check(buff != null and is_equal_approx(buff.time_left, expected),
			"+%d EnhancedRings lasts %.0f turns, got %s"
			% [points, expected, str(buff.time_left) if buff != null else "none"])
		hero.free()

func _test_no_talent_no_buff(t: Object) -> void:
	var hero := _make_rogue(0)
	var cloak := _make_cloak()
	cloak.activate(hero)
	t.check(hero.get_buff("EnhancedRings") == null,
		"No talent points -> cloak use grants no EnhancedRings")
	hero.free()

func _test_ring_bonus_while_live(t: Object) -> void:
	var hero := _make_rogue(2)
	var ring := Ring.RingOfHaste.new()
	ring.level = 2
	hero.belongings.equip_ring(ring, true)
	t.check(ring.bonus() == 2, "Equipped +2 ring has bonus 2 without the buff")
	var cloak := _make_cloak()
	cloak.activate(hero)
	t.check(ring.bonus() == 3, "EnhancedRings raises equipped ring bonus to 3")
	hero.remove_buff_by_id("EnhancedRings")
	t.check(ring.bonus() == 2, "Bonus returns to 2 after the buff detaches")
	hero.free()

func _test_cursed_ring_bonus(t: Object) -> void:
	var hero := _make_rogue(1)
	var ring := Ring.RingOfHaste.new()
	ring.level = 0
	ring.cursed = true
	hero.belongings.equip_ring(ring, true)
	t.check(ring.bonus() == -1, "Cursed +0 ring has bonus -1 without the buff")
	var cloak := _make_cloak()
	cloak.activate(hero)
	t.check(ring.bonus() == 0, "EnhancedRings lifts cursed +0 ring to bonus 0")
	hero.free()

func _test_unequipped_ring_unaffected(t: Object) -> void:
	var hero := _make_rogue(1)
	var ring := Ring.RingOfHaste.new()
	ring.level = 1
	var cloak := _make_cloak()
	cloak.activate(hero)
	t.check(ring.bonus() == 1,
		"A ring not equipped (no passive buff) keeps its base bonus")
	hero.free()

func _test_might_refresh(t: Object) -> void:
	var hero := _make_rogue(1)
	var base_str: int = hero.str_val
	var base_ht: int = hero.ht
	var ring := Ring.RingOfMight.new()
	ring.level = 1
	hero.belongings.equip_ring(ring, true)
	t.check(hero.str_val == base_str + 1, "+1 Might grants +1 STR when equipped")
	var ht_plus1: int = hero.ht
	var cloak := _make_cloak()
	cloak.activate(hero)
	t.check(hero.str_val == base_str + 2,
		"EnhancedRings re-applies Might at +2 (STR %d -> %d expected, got %d)"
		% [base_str + 1, base_str + 2, hero.str_val])
	t.check(hero.ht >= ht_plus1, "Might HT does not drop while enhanced")
	hero.remove_buff_by_id("EnhancedRings")
	t.check(hero.str_val == base_str + 1,
		"STR returns to +1 after EnhancedRings detaches")
	t.check(hero.ht == ht_plus1, "HT returns to the +1 value after detach")
	t.check(hero.ht - base_ht >= 0, "HT never ends below base")
	hero.free()

func _test_prolong_never_shortens(t: Object) -> void:
	var hero := _make_rogue(2)
	var cloak := _make_cloak()
	cloak.activate(hero)
	var buff: Variant = hero.get_buff("EnhancedRings")
	buff.time_left = 1.0
	cloak.activate(hero)
	var after: Variant = hero.get_buff("EnhancedRings")
	t.check(after == buff, "Re-activation merges into the existing buff")
	t.check(is_equal_approx(after.time_left, 6.0),
		"Re-activation prolongs back to 6 turns, got %s" % str(after.time_left))
	hero.free()

func _test_expiry_restores_bonus(t: Object) -> void:
	var hero := _make_rogue(1)
	var ring := Ring.RingOfHaste.new()
	ring.level = 1
	hero.belongings.equip_ring(ring, true)
	var cloak := _make_cloak()
	cloak.activate(hero)
	t.check(ring.bonus() == 2, "Bonus is 2 right after cloak use")
	for i: int in range(3):
		hero._tick_buffs_once()
	t.check(hero.get_buff("EnhancedRings") == null,
		"EnhancedRings expires after 3 turns at +1")
	t.check(ring.bonus() == 1, "Ring bonus returns to base after expiry")
	hero.free()
