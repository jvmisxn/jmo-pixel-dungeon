extends RefCounted
## Rogue Inscribed Stealth (upstream Talent.onScrollUsed): reading a scroll
## grants 1+2*points (3/5) turns of Invisibility. Port adaptation: buff merge
## keeps the longer remaining duration instead of stacking additively.

func run(t: Object) -> void:
	_test_registry(t)
	_test_hook_grants_invisibility(t)
	_test_no_talent_no_invisibility(t)
	_test_wrong_class_no_invisibility(t)
	_test_merge_keeps_longer_duration(t)
	_test_scroll_execute_triggers_hook(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_inscribed_stealth"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_inscribed_stealth")
	t.check(info != null, "rogue_inscribed_stealth is registered for the Rogue")
	t.check(info != null and info.implemented,
		"rogue_inscribed_stealth is marked implemented")
	t.check(info != null and info.tier == 2, "rogue_inscribed_stealth is tier 2")

func _test_hook_grants_invisibility(t: Object) -> void:
	for points: int in [1, 2]:
		var hero := _make_rogue(points)
		hero.on_scroll_read()
		var invis: Buff = hero.get_buff("Invisibility")
		var expected: float = 1.0 + 2.0 * points
		t.check(invis != null, "+%d Inscribed Stealth grants Invisibility" % points)
		t.check(invis != null and is_equal_approx(invis.time_left, expected),
			"+%d grants %.0f turns, got %s" % [points, expected,
				str(invis.time_left) if invis != null else "none"])
		hero.free()

func _test_no_talent_no_invisibility(t: Object) -> void:
	var hero := _make_rogue(0)
	hero.on_scroll_read()
	t.check(hero.get_buff("Invisibility") == null,
		"No talent points -> reading grants no invisibility")
	hero.free()

func _test_wrong_class_no_invisibility(t: Object) -> void:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.talent_levels["rogue_inscribed_stealth"] = 2
	hero.on_scroll_read()
	t.check(hero.get_buff("Invisibility") == null,
		"Non-Rogue with the talent id gets no invisibility")
	hero.free()

func _test_merge_keeps_longer_duration(t: Object) -> void:
	var hero := _make_rogue(2)
	var potion_invis := Invisibility.new()
	potion_invis.set_duration(20.0)
	hero.add_buff(potion_invis)
	hero.on_scroll_read()
	var invis: Buff = hero.get_buff("Invisibility")
	t.check(invis != null and is_equal_approx(invis.time_left, 20.0),
		"Existing longer invisibility is not shortened (20), got %s"
			% (str(invis.time_left) if invis != null else "none"))
	t.check(hero.invisible == 1, "Merge keeps a single invisible stack")
	hero.free()

func _test_scroll_execute_triggers_hook(t: Object) -> void:
	var hero := _make_rogue(1)
	var scroll := Scroll.new()
	scroll.item_id = "test_scroll"
	scroll.item_name = "Test Scroll"
	scroll.quantity = 1
	hero.belongings.add_item(scroll)
	scroll.execute(hero)
	var invis: Buff = hero.get_buff("Invisibility")
	t.check(invis != null and is_equal_approx(invis.time_left, 3.0),
		"Scroll.execute wires the on_scroll_read hook (3 turns at +1)")
	hero.free()
