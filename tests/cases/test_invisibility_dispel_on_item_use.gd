extends RefCounted
## Upstream parity: magical item use breaks invisibility. Scroll.readAnimation
## and the Wand cell selector both call Invisibility.dispel(), and the dispel
## runs BEFORE Talent.onScrollUsed, so Inscribed Stealth's fresh grant
## replaces (not merges with) any prior invisibility.

func run(t: Object) -> void:
	_test_dispel_for_helper(t)
	_test_scroll_read_dispels(t)
	_test_dispel_before_inscribed_stealth_grant(t)
	_test_wand_cursed_zap_dispels(t)

func _make_hero(hero_class: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(hero_class)
	return hero

func _test_dispel_for_helper(t: Object) -> void:
	var hero := _make_hero(ConstantsData.HeroClass.WARRIOR)
	hero.add_buff(Invisibility.new())
	t.check(hero.invisible == 1, "helper setup: hero is invisible")
	Invisibility.dispel_for(hero)
	t.check(hero.get_buff("Invisibility") == null and hero.invisible == 0,
		"dispel_for removes Invisibility and clears the counter")
	Invisibility.dispel_for(hero)
	Invisibility.dispel_for(null)
	t.check(true, "dispel_for is safe with no buff and with null char")
	hero.free()

func _test_scroll_read_dispels(t: Object) -> void:
	var hero := _make_hero(ConstantsData.HeroClass.WARRIOR)
	hero.add_buff(Invisibility.new())
	var scroll := Scroll.new()
	scroll.item_id = "test_scroll"
	scroll.item_name = "Test Scroll"
	scroll.quantity = 1
	hero.belongings.add_item(scroll)
	scroll.execute(hero)
	t.check(hero.get_buff("Invisibility") == null,
		"Reading a scroll dispels Invisibility (no talent)")
	hero.free()

func _test_dispel_before_inscribed_stealth_grant(t: Object) -> void:
	var hero := _make_hero(ConstantsData.HeroClass.ROGUE)
	hero.talent_levels["rogue_inscribed_stealth"] = 1
	var potion_invis := Invisibility.new()
	potion_invis.set_duration(20.0)
	hero.add_buff(potion_invis)
	var scroll := Scroll.new()
	scroll.item_id = "test_scroll2"
	scroll.item_name = "Test Scroll"
	scroll.quantity = 1
	hero.belongings.add_item(scroll)
	scroll.execute(hero)
	var invis: Buff = hero.get_buff("Invisibility")
	t.check(invis != null and is_equal_approx(invis.time_left, 3.0),
		"Dispel runs before Inscribed Stealth: 20-turn invis replaced by 3, got %s"
			% (str(invis.time_left) if invis != null else "none"))
	t.check(hero.invisible == 1, "Replacement keeps a single invisible stack")
	hero.free()

func _test_wand_cursed_zap_dispels(t: Object) -> void:
	var hero := _make_hero(ConstantsData.HeroClass.MAGE)
	hero.add_buff(Invisibility.new())
	var wand := Wand.new()
	wand.charges = 1
	wand.cursed = true
	wand.cursed_effect = true
	wand.zap(hero, 1)
	t.check(hero.get_buff("Invisibility") == null,
		"A cursed wand zap still dispels Invisibility")
	hero.free()
