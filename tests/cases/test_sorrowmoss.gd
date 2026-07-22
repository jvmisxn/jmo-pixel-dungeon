extends RefCounted
## Sorrowmoss plant + ToxicImbue parity with current Shattered Pixel Dungeon.
##
## Upstream `Sorrowmoss.activate()` applies Poison for `5 + round(2*scalingDepth/3)`
## turns to whoever steps on it, and grants a Warden hero a short `ToxicImbue`
## (`ToxicImbue.DURATION * 0.3`) instead. `ToxicImbue.act()` seeds 6 units of
## ToxicGas into every open NEIGHBOURS8 cell each turn (redirecting a solid
## neighbour's share into the owner's own cell) and makes the owner immune to
## Poison / Toxic Gas, so the Warden walks unharmed inside their own cloud.

func _make_level(depth: int) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level, subclass: int = -1) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if subclass >= 0:
		hero.hero_subclass = subclass
	hero.pos = pos
	hero.level = level
	hero.hp = 200
	hero.hp_max = 200
	hero.ht = 200
	return hero

func _install_hero(hero: Hero, level: Level) -> void:
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

func _toxic_blob(level: Level) -> Variant:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == "toxic_gas":
			return blob
	return null

func run(t: Object) -> void:
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	_test_poison_formula(t)
	_test_non_warden_poison(t)
	_test_warden_imbue_and_immunity(t)
	_test_imbue_seeds_cloud(t)
	_test_imbue_solid_redirect(t)

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

func _test_poison_formula(t: Object) -> void:
	# 5 + round(2*depth/3): depth 1 -> 6, depth 3 -> 7, depth 6 -> 9, depth 12 -> 13.
	t.check(is_equal_approx(Sorrowmoss.poison_amount(1), 6.0), "Sorrowmoss depth 1 poison = 6")
	t.check(is_equal_approx(Sorrowmoss.poison_amount(3), 7.0), "Sorrowmoss depth 3 poison = 7")
	t.check(is_equal_approx(Sorrowmoss.poison_amount(6), 9.0), "Sorrowmoss depth 6 poison = 9")
	t.check(is_equal_approx(Sorrowmoss.poison_amount(12), 13.0), "Sorrowmoss depth 12 poison = 13")

func _test_non_warden_poison(t: Object) -> void:
	var level: Level = _make_level(6)
	var pos: int = ConstantsData.xy_to_pos(15, 15)
	var hero: Hero = _make_hero(pos, level)
	_install_hero(hero, level)

	var moss := Sorrowmoss.new()
	moss.pos = pos
	moss._do_effect(hero, level)

	t.check(hero.has_buff("Poison"), "Sorrowmoss poisons a non-Warden hero")
	var poison: Variant = hero.get_buff("Poison")
	t.check(poison != null and is_equal_approx(poison.get_time_left(), 9.0),
		"Sorrowmoss depth-6 poison lasts 9 turns")
	t.check(not hero.has_buff("ToxicImbue"), "Sorrowmoss gives a non-Warden no Toxic Imbue")

func _test_warden_imbue_and_immunity(t: Object) -> void:
	var level: Level = _make_level(6)
	var pos: int = ConstantsData.xy_to_pos(15, 15)
	var hero: Hero = _make_hero(pos, level, ConstantsData.HeroSubclass.WARDEN)
	_install_hero(hero, level)

	var moss := Sorrowmoss.new()
	moss.pos = pos
	moss._do_effect(hero, level)

	t.check(hero.has_buff("ToxicImbue"), "Sorrowmoss grants a Warden Toxic Imbue")
	var imbue: Variant = hero.get_buff("ToxicImbue")
	t.check(imbue != null and is_equal_approx(imbue.get_duration(), ToxicImbue.BASE_DURATION * 0.3),
		"Warden Toxic Imbue lasts 30% of full duration")
	# Immune to its own gas: the plant's Poison application is rejected.
	t.check(hero.is_immune("Poison"), "Toxic Imbue grants Poison immunity")
	t.check(not hero.has_buff("Poison"), "Warden is not self-poisoned by the burst")

func _test_imbue_seeds_cloud(t: Object) -> void:
	var level: Level = _make_level(6)
	var pos: int = ConstantsData.xy_to_pos(20, 20)
	var hero: Hero = _make_hero(pos, level)
	_install_hero(hero, level)

	var imbue := ToxicImbue.new()
	hero.add_buff(imbue)
	imbue.on_turn()

	var blob: Variant = _toxic_blob(level)
	t.check(blob != null, "Toxic Imbue seeds a ToxicGas blob")
	t.check(is_equal_approx(blob.get_density(pos), ToxicImbue.CENTER_BASE_VOLUME),
		"Toxic Imbue seeds the base centre volume when all neighbours are open")
	var open_neighbours: int = 0
	for dir: int in ConstantsData.DIRS_8:
		if is_equal_approx(blob.get_density(pos + dir), ToxicImbue.NEIGHBOUR_VOLUME):
			open_neighbours += 1
	t.check(open_neighbours == 8, "Toxic Imbue seeds gas into all 8 open neighbours")

func _test_imbue_solid_redirect(t: Object) -> void:
	var level: Level = _make_level(6)
	var pos: int = ConstantsData.xy_to_pos(25, 25)
	var wall_cell: int = pos + 1
	level.set_terrain(wall_cell, ConstantsData.Terrain.WALL)
	var hero: Hero = _make_hero(pos, level)
	_install_hero(hero, level)

	var imbue := ToxicImbue.new()
	hero.add_buff(imbue)
	imbue.on_turn()

	var blob: Variant = _toxic_blob(level)
	t.check(blob != null, "Toxic Imbue seeds a ToxicGas blob (solid case)")
	t.check(is_equal_approx(blob.get_density(wall_cell), 0.0),
		"Toxic Imbue seeds no gas into a solid neighbour")
	t.check(is_equal_approx(blob.get_density(pos),
		ToxicImbue.CENTER_BASE_VOLUME + ToxicImbue.NEIGHBOUR_VOLUME),
		"a solid neighbour's gas share is redirected to the owner's cell")
