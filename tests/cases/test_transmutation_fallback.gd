extends RefCounted
## Scroll of Transmutation headless/no-HUD fallback must actually transmute
## the chosen item into a different item of the same category (upstream
## ScrollOfTransmutation.onItemSelected → Recipe/changeItem behavior), not
## just identify it and claim it transformed.

func run(t: Object) -> void:
	_test_fallback_transmutes_item(t)
	_test_fallback_with_nothing_transmutable(t)

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	return hero

func _test_fallback_transmutes_item(t: Object) -> void:
	var hero := _make_hero()
	var potion: Potion = Potion.create("healing")
	hero.belongings.add_item(potion)
	var scroll: Scroll = Scroll.create("transmutation")
	scroll._transmutation_fallback(hero)
	t.check(not hero.belongings.backpack.has(potion), "original potion is removed from the backpack")
	var replacement: Variant = null
	for item: Item in hero.belongings.backpack:
		if item != null and item.category == ConstantsData.ItemCategory.POTION:
			replacement = item
			break
	t.check(replacement != null, "a replacement potion exists in the backpack")
	if replacement != null:
		t.check(replacement.item_id != "healing", "replacement is a different potion type")
		t.check(replacement.is_identified() if replacement.has_method("is_identified") else true,
			"transmuted result is identified")
	hero.free()

func _test_fallback_with_nothing_transmutable(t: Object) -> void:
	var hero := _make_hero()
	var before: int = hero.belongings.backpack.size()
	var scroll: Scroll = Scroll.create("transmutation")
	scroll._transmutation_fallback(hero)
	t.check(hero.belongings.backpack.size() == before, "empty fallback leaves the backpack unchanged")
	hero.free()
