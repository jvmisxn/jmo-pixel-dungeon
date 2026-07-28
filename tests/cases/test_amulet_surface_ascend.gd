extends RefCounted
## Upstream Hero.actAscend depth-1 gate: ascending floor 1 with the Amulet of
## Yendor ends the run in victory; without it the hero cannot leave. The port
## checks the whole party's backpacks (co-op adaptation) via
## FloorTransitionCoordinator.party_has_amulet/_hero_has_amulet.

func run(t: Object) -> void:
	_test_hero_has_amulet(t)
	_test_fallback_hero(t)

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	return hero

func _test_hero_has_amulet(t: Object) -> void:
	t.check(not FloorTransitionCoordinator._hero_has_amulet(null),
		"Null hero never holds the amulet")
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	t.check(not FloorTransitionCoordinator._hero_has_amulet(hero),
		"Fresh hero has no amulet")
	var amulet: Item = Generator.create_item("amulet_of_yendor")
	t.check(amulet != null, "Generator can create the Amulet of Yendor")
	hero.belongings.backpack.append(amulet)
	t.check(FloorTransitionCoordinator._hero_has_amulet(hero),
		"Amulet in backpack is detected")
	hero.belongings.backpack.erase(amulet)
	t.check(not FloorTransitionCoordinator._hero_has_amulet(hero),
		"Removing the amulet clears the check")

func _test_fallback_hero(t: Object) -> void:
	# party_has_amulet must fall back to the acting hero even when the
	# GameManager party list does not include it (headless: party is empty).
	var hero := _make_hero()
	t.check(not FloorTransitionCoordinator.party_has_amulet(hero),
		"No amulet anywhere -> no victory ascent")
	var amulet: Item = Generator.create_item("amulet_of_yendor")
	hero.belongings.backpack.append(amulet)
	t.check(FloorTransitionCoordinator.party_has_amulet(hero),
		"Acting hero's amulet unlocks the depth-1 victory ascent")
	t.check(not FloorTransitionCoordinator.party_has_amulet(null),
		"Null fallback hero is safe")
