extends RefCounted
## Armor curse glyphs (upstream items/armor/curses/): is_curse flag, cursed
## armor generation inscribing a curse glyph, and deterministic effect checks
## via each curse's activate() helper.

const CurseGlyphs := preload("res://src/items/armor/curse_glyph.gd")

func run(t: Object) -> void:
	_test_curse_flags_and_factory(t)
	_test_serialize_round_trip(t)
	_test_cursed_generation_inscribes_curse(t)
	_test_anti_entropy(t)
	_test_corrosion(t)
	_test_displacement(t)
	_test_metabolism(t)
	_test_stench(t)
	_test_multiplicity_mirror_image(t)
	_test_bulk_speed(t)
	_test_display_name_hides_unknown_curse(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
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
	hero.hp_max = 30
	hero.ht = 30
	hero.hp = 30
	return hero

func _test_curse_flags_and_factory(t: Object) -> void:
	for id: String in CurseGlyphs.CURSE_IDS:
		var g: ArmorGlyph = ArmorGlyph.create(id)
		t.check(g != null and g.is_curse and g.glyph_id == id,
			"ArmorGlyph.create('%s') yields a curse glyph" % id)
	var good: ArmorGlyph = ArmorGlyph.create("swiftness")
	t.check(good != null and not good.is_curse, "Normal glyphs are not curses")
	var rc: ArmorGlyph = ArmorGlyph.random_curse()
	t.check(rc != null and rc.is_curse and CurseGlyphs.CURSE_IDS.has(rc.glyph_id),
		"random_curse returns one of the 8 upstream curses")

func _test_serialize_round_trip(t: Object) -> void:
	var g: ArmorGlyph = ArmorGlyph.create("stench")
	var restored := ArmorGlyph.new()
	restored.deserialize(g.serialize())
	t.check(restored.is_curse, "is_curse survives serialize/deserialize")

func _test_cursed_generation_inscribes_curse(t: Object) -> void:
	var saw_cursed := false
	for _i: int in range(200):
		var armor := Armor.new()
		armor.tier = 2
		armor.random()
		if armor.cursed:
			saw_cursed = true
			t.check(armor.has_curse_glyph(),
				"Cursed generated armor carries a curse glyph")
			break
	t.check(saw_cursed, "Armor.random() produced a cursed armor within 200 rolls")

func _test_anti_entropy(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(ConstantsData.xy_to_pos(10, 10), level)
	var mob := Mob.new()
	mob.pos = ConstantsData.xy_to_pos(11, 10)
	mob.level = level
	level.add_mob(mob)
	var curse: Variant = ArmorGlyph.create("anti_entropy")
	curse.activate(null, mob, hero)
	t.check(mob.has_buff("Frozen"), "Anti-Entropy freezes adjacent characters")
	t.check(hero.has_buff("Burning"), "Anti-Entropy ignites the wearer")

	var wet_hero := _make_hero(ConstantsData.xy_to_pos(20, 20), level)
	level.map[wet_hero.pos] = ConstantsData.Terrain.WATER
	curse.activate(null, null, wet_hero)
	t.check(not wet_hero.has_buff("Burning"),
		"Anti-Entropy does not ignite a wearer standing in water")
	hero.free()
	wet_hero.free()
	mob.free()

func _test_corrosion(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(ConstantsData.xy_to_pos(10, 10), level)
	var mob := Mob.new()
	mob.pos = ConstantsData.xy_to_pos(11, 11)
	mob.level = level
	level.add_mob(mob)
	var curse: Variant = ArmorGlyph.create("corrosion")
	curse.activate(null, mob, hero)
	t.check(hero.has_buff("Ooze"), "Corrosion oozes the wearer")
	t.check(mob.has_buff("Ooze"), "Corrosion oozes characters in the 3x3 area")
	hero.free()
	mob.free()

func _test_displacement(t: Object) -> void:
	var level := _make_level()
	var start: int = ConstantsData.xy_to_pos(10, 10)
	var hero := _make_hero(start, level)
	var curse: Variant = ArmorGlyph.create("displacement")
	var moved: bool = curse.activate(null, null, hero)
	t.check(moved and hero.pos != start,
		"Displacement teleports the wearer to a new cell")
	t.check(level.is_passable(hero.pos), "Displacement lands on a passable cell")
	hero.free()

func _test_metabolism(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(ConstantsData.xy_to_pos(10, 10), level)
	hero.hp = 20
	var hunger: Variant = hero.get_buff("Hunger")
	if hunger == null:
		hunger = hero.add_buff(Hunger.new())
	var before_hunger: float = hunger.hunger_value
	var curse: Variant = ArmorGlyph.create("metabolism")
	curse.activate(null, null, hero)
	t.check(hero.hp == 24, "Metabolism heals STARVING/100 = 4 HP")
	t.check(hunger.hunger_value > before_hunger,
		"Metabolism healing costs 10 hunger per HP")

	hunger.hunger_value = Hunger.STARVING_THRESHOLD
	hunger._update_level()
	var starving_hp: int = hero.hp
	curse.activate(null, null, hero)
	t.check(hero.hp == starving_hp, "Metabolism does not heal while starving")
	hero.free()

func _test_stench(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(ConstantsData.xy_to_pos(10, 10), level)
	var curse: Variant = ArmorGlyph.create("stench")
	curse.activate(null, null, hero)
	var found := false
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == "toxic_gas":
			found = blob.density[hero.pos] > 0.0
	t.check(found, "Stench seeds toxic gas at the wearer's cell")
	hero.free()

func _test_multiplicity_mirror_image(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(ConstantsData.xy_to_pos(10, 10), level)
	var curse: Variant = ArmorGlyph.create("multiplicity")
	# Roll until an effect happens; both branches must add exactly one mob.
	var before: int = level.mobs.size()
	for _i: int in range(40):
		curse.activate(null, null, hero)
		if level.mobs.size() > before:
			break
	t.check(level.mobs.size() == before + 1,
		"Multiplicity spawns a single duplicate/mirror image next to the wearer")
	hero.free()

func _test_bulk_speed(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(ConstantsData.xy_to_pos(10, 10), level)
	hero.str_val = 18
	var armor := Armor.new()
	armor.tier = 1
	armor.inscribe(ArmorGlyph.create("bulk"))
	var open_speed: float = armor.speed_factor(hero)
	level.map[hero.pos] = ConstantsData.Terrain.DOOR
	var door_speed: float = armor.speed_factor(hero)
	t.check(is_equal_approx(open_speed, 1.0), "Bulk does not slow open-floor movement")
	t.check(door_speed < open_speed and is_equal_approx(door_speed, 1.0 / 3.0),
		"Bulk slows movement to 1/3 in doorways")
	hero.free()

func _test_display_name_hides_unknown_curse(t: Object) -> void:
	var armor := Armor.new()
	armor.tier = 1
	armor.item_name = "leather armor"
	armor.identified = true
	armor.cursed_known = false
	armor.inscribe(ArmorGlyph.create("stench"))
	t.check(not armor.get_display_name().contains("Stench"),
		"Curse glyph name is hidden until the curse is known")
	armor.cursed_known = true
	t.check(armor.get_display_name().contains("Stench"),
		"Curse glyph name shows once the curse is known")
