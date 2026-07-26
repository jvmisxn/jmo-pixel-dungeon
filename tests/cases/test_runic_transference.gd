extends RefCounted
## Warrior Runic Transference talent (upstream Talent.RUNIC_TRANSFERENCE,
## BrokenSeal.canTransferGlyph() + Armor.detachSeal()/affixSeal()): when the
## broken seal transfers between armors, the old armor's glyph moves with it —
## +1 only common/uncommon glyphs, +2 any glyph (including curses). Port
## adaptation: the seal auto-transfers at equip time, and the glyph only moves
## when the new armor is unglyphed (no silent overwrite prompt exists).

func run(t: Object) -> void:
	_test_registry(t)
	_test_rarity_helper(t)
	_test_no_points_no_transfer(t)
	_test_one_point_common_transfers(t)
	_test_one_point_rare_blocked(t)
	_test_two_points_rare_transfers(t)
	_test_curse_gating(t)
	_test_glyphed_new_armor_untouched(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	if points > 0:
		hero.talent_levels["warrior_runic_transference"] = points
	# Starting gear is not populated in the headless harness; equip the
	# Warrior's sealed cloth armor explicitly.
	var cloth: Armor = Armor.create("cloth_armor")
	cloth.affix_seal()
	hero.belongings.equip_armor(cloth)
	return hero

func _old_armor(hero: Hero) -> Armor:
	return hero.belongings.armor as Armor

func _swap(hero: Hero, glyph_id: String) -> Armor:
	_old_armor(hero).inscribe(ArmorGlyph.create(glyph_id))
	var new_armor: Armor = Armor.create("leather_armor")
	hero.belongings.equip_armor(new_armor)
	return new_armor

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.WARRIOR, "warrior_runic_transference"
	)
	t.check(info != null and info.implemented, "Runic Transference is registered and implemented")
	t.check(info != null and info.max_points == 2, "Runic Transference caps at 2 points")
	t.check(info != null and info.tier == 2, "Runic Transference is a tier-2 talent")

func _test_rarity_helper(t: Object) -> void:
	t.check(ArmorGlyph.create("swiftness").is_common_or_uncommon(), "Swiftness is common")
	t.check(ArmorGlyph.create("stone").is_common_or_uncommon(), "Stone is uncommon")
	t.check(not ArmorGlyph.create("thorns").is_common_or_uncommon(), "Thorns is rare")
	t.check(not ArmorGlyph.create("corrosion").is_common_or_uncommon(), "Curse glyphs are not common/uncommon")

func _test_no_points_no_transfer(t: Object) -> void:
	var hero := _make_warrior(0)
	var old: Armor = _old_armor(hero)
	var new_armor: Armor = _swap(hero, "swiftness")
	t.check(new_armor.has_seal(), "Seal still auto-transfers without the talent")
	t.check(not new_armor.has_glyph(), "No glyph transfer without talent points")
	t.check(old.has_glyph() and old.glyph.glyph_id == "swiftness", "Old armor keeps its glyph without the talent")
	hero.free()

func _test_one_point_common_transfers(t: Object) -> void:
	var hero := _make_warrior(1)
	var old: Armor = _old_armor(hero)
	var new_armor: Armor = _swap(hero, "swiftness")
	t.check(new_armor.has_glyph() and new_armor.glyph.glyph_id == "swiftness", "+1 transfers a common glyph to the new armor")
	t.check(not old.has_glyph(), "Old armor loses the transferred glyph")
	hero.free()

func _test_one_point_rare_blocked(t: Object) -> void:
	var hero := _make_warrior(1)
	var old: Armor = _old_armor(hero)
	var new_armor: Armor = _swap(hero, "thorns")
	t.check(not new_armor.has_glyph(), "+1 does not transfer a rare glyph")
	t.check(old.has_glyph() and old.glyph.glyph_id == "thorns", "Rare glyph stays on the old armor at +1")
	hero.free()

func _test_two_points_rare_transfers(t: Object) -> void:
	var hero := _make_warrior(2)
	var old: Armor = _old_armor(hero)
	var new_armor: Armor = _swap(hero, "thorns")
	t.check(new_armor.has_glyph() and new_armor.glyph.glyph_id == "thorns", "+2 transfers a rare glyph")
	t.check(not old.has_glyph(), "Old armor loses the rare glyph at +2")
	hero.free()

func _test_curse_gating(t: Object) -> void:
	var hero := _make_warrior(1)
	var new_armor: Armor = _swap(hero, "corrosion")
	t.check(not new_armor.has_glyph(), "+1 does not transfer a curse glyph")
	hero.free()
	var hero2 := _make_warrior(2)
	var new_armor2: Armor = _swap(hero2, "corrosion")
	t.check(new_armor2.has_glyph() and new_armor2.glyph.glyph_id == "corrosion", "+2 transfers even curse glyphs")
	hero2.free()

func _test_glyphed_new_armor_untouched(t: Object) -> void:
	var hero := _make_warrior(2)
	var old: Armor = _old_armor(hero)
	old.inscribe(ArmorGlyph.create("swiftness"))
	var new_armor: Armor = Armor.create("leather_armor")
	new_armor.inscribe(ArmorGlyph.create("stone"))
	hero.belongings.equip_armor(new_armor)
	t.check(new_armor.has_seal(), "Seal transfers onto pre-glyphed armor")
	t.check(new_armor.glyph.glyph_id == "stone", "Pre-glyphed new armor keeps its own glyph")
	t.check(old.glyph != null and old.glyph.glyph_id == "swiftness", "Old armor keeps its glyph when transfer is skipped")
	hero.free()
