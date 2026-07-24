extends RefCounted
## Coverage for Ankh revival item handling.
##
## Parity: SPD's unblessed-ankh lost-inventory contract (adapted). The old port
## behavior destroyed the whole backpack via `backpack.clear()`. Now unique
## items, bags, and kept-through-lost-inventory items stay with the hero, and
## everything else drops as recoverable heaps at the hero's position. The
## consumed ankh is never dropped, and blessed revival still keeps everything.

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = pos
	hero.level = level
	hero.hp_max = 40
	hero.ht = 40
	hero.hp = 0
	hero.is_alive = false
	return hero

func run(t: Object) -> void:
	_test_unblessed_drops_common_items_as_heaps(t)
	_test_unblessed_keeps_unique_kept_and_bags(t)
	_test_blessed_keeps_everything(t)

func _heap_items(level: Level, pos: int) -> Array:
	var items: Array = []
	for h: Dictionary in level.heaps_at(pos):
		items.append(h["item"])
	return items

func _test_unblessed_drops_common_items_as_heaps(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(hero_pos, level)
	# Start from an empty pack so the starting kit doesn't muddy the counts.
	hero.belongings.backpack.clear()

	var ankh := Ankh.new()
	var potion: Item = Generator.create_item("healing")
	t.check(potion != null, "test can build a droppable potion")
	hero.belongings.backpack.append(ankh)
	hero.belongings.backpack.append(potion)

	t.check(ankh.bones, "ankh is flagged for bones like SPD")
	t.check(ankh.revive(hero), "unblessed ankh revives the hero")
	t.check(hero.is_alive, "hero is alive after revival")
	t.check(hero.hp == 10, "unblessed revival restores a quarter of max HP")

	var dropped: Array = _heap_items(level, hero_pos)
	t.check(potion in dropped, "common backpack item drops as a recoverable heap")
	t.check(not (ankh in dropped), "the consumed ankh is not dropped")
	t.check(not hero.belongings.has_item(ankh), "the ankh is consumed from the inventory")
	t.check(not hero.belongings.has_item(potion), "dropped item is no longer in the inventory")
	hero.free()

func _test_unblessed_keeps_unique_kept_and_bags(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(12, 12)
	var hero: Hero = _make_hero(hero_pos, level)
	hero.belongings.backpack.clear()

	var ankh := Ankh.new()
	var unique_item: Item = Generator.create_item("healing")
	unique_item.unique = true
	var kept_item: Item = Generator.create_item("healing")
	kept_item.kept_though_lost_invent = true
	var bag: Item = Generator.create_item("velvet_pouch")
	t.check(bag is Bag, "test can build a real bag")
	var bagged: Item = Generator.create_item("healing")
	if bag is Bag and bagged != null:
		(bag as Bag).items.append(bagged)

	hero.belongings.backpack.append(ankh)
	hero.belongings.backpack.append(unique_item)
	hero.belongings.backpack.append(kept_item)
	hero.belongings.backpack.append(bag)

	t.check(ankh.revive(hero), "unblessed ankh revives the hero")
	t.check(hero.belongings.has_item(unique_item), "unique item stays with the hero")
	t.check(hero.belongings.has_item(kept_item), "kept-through-lost-inventory item stays with the hero")
	t.check(hero.belongings.has_item(bag), "bags stay with the hero")
	if bagged != null:
		t.check(not hero.belongings.has_item(bagged), "bag contents follow the lost-item rules")
		t.check(bagged in _heap_items(level, hero_pos), "bag contents drop as recoverable heaps")
	hero.free()

func _test_blessed_keeps_everything(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(14, 14)
	var hero: Hero = _make_hero(hero_pos, level)
	hero.belongings.backpack.clear()

	var ankh := Ankh.new()
	ankh.bless()
	var potion: Item = Generator.create_item("healing")
	hero.belongings.backpack.append(ankh)
	hero.belongings.backpack.append(potion)

	t.check(ankh.revive(hero), "blessed ankh revives the hero")
	t.check(hero.belongings.has_item(potion), "blessed revival keeps backpack items")
	t.check(not hero.belongings.has_item(ankh), "blessed revival still consumes the ankh")
	t.check(_heap_items(level, hero_pos).is_empty(), "blessed revival drops nothing")
	hero.free()
