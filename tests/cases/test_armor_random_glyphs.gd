extends RefCounted
## Randomly generated loot armor must be able to receive glyphs. Armor.random()
## previously stubbed both effect branches, so loot armor was always glyph-less
## and glyphs were only reachable via Scroll-of-Enchantment inscribe().

func run(t: Object) -> void:
	_check_random_can_produce_glyphs(t)
	_check_curse_and_glyph_are_exclusive(t)
	_check_degrade_preserves_glyph(t)
	_check_glyph_survives_serialization(t)

## Over many rolls, some armor gains a good glyph and some becomes cursed.
## The good branch (~15%) must actually inscribe a glyph now.
func _check_random_can_produce_glyphs(t: Object) -> void:
	seed(0xA12A0)  # deterministic RNG for the counting assertions below
	var glyphed: int = 0
	var cursed: int = 0
	var glyphs_are_valid: bool = true
	for i: int in range(400):
		var armor: Armor = Armor.create("leather_armor")
		armor.random()
		if armor.has_glyph():
			glyphed += 1
			if not (armor.glyph is ArmorGlyph) or armor.glyph.glyph_id == "":
				glyphs_are_valid = false
		if armor.cursed:
			cursed += 1
	t.check(glyphed > 0, "Armor.random() can produce glyph-bearing armor")
	t.check(glyphs_are_valid, "Rolled glyphs are valid ArmorGlyph instances with ids")
	t.check(cursed > 0, "Armor.random() still produces cursed armor")

## The cursed branch and the good-glyph branch are mutually exclusive: cursed
## armor from random() should not also carry a good glyph.
func _check_curse_and_glyph_are_exclusive(t: Object) -> void:
	seed(0xB33F)
	var cursed_seen: int = 0
	var cursed_with_good_glyph: int = 0
	for i: int in range(400):
		var armor: Armor = Armor.create("mail_armor")
		armor.random()
		if armor.cursed:
			cursed_seen += 1
			if armor.has_good_glyph():
				cursed_with_good_glyph += 1
	t.check(cursed_seen > 0, "Curse branch is exercised")
	t.check(cursed_with_good_glyph == 0, "Cursed random armor carries no good glyph")

## Degrade must not strip an inscribed glyph; only str requirement recalculates.
func _check_degrade_preserves_glyph(t: Object) -> void:
	var armor: Armor = Armor.create("scale_armor")
	armor.level = 3
	armor.inscribe(ArmorGlyph.create("thorns"))
	armor._update_str_requirement()
	armor.degrade()
	t.check(armor.level == 2, "Degrade lowers level by one")
	t.check(armor.has_glyph(), "Degrade preserves the inscribed glyph")
	t.check(armor.glyph.glyph_id == "thorns", "Degrade keeps the same glyph type")

## A rolled/inscribed glyph must round-trip through serialization.
func _check_glyph_survives_serialization(t: Object) -> void:
	var armor: Armor = Armor.create("plate_armor")
	armor.level = 1
	armor.inscribe(ArmorGlyph.create("brimstone"))
	var data: Dictionary = armor.serialize()
	t.check(data.has("glyph"), "Serialized armor includes glyph data")

	var restored: Armor = Armor.new()
	restored.deserialize(data)
	t.check(restored.has_glyph(), "Deserialized armor keeps its glyph")
	t.check(restored.glyph.glyph_id == "brimstone", "Deserialized glyph id matches original")
