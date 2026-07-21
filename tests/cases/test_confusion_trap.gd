extends RefCounted
## Coverage for ConfusionTrap routing through the shared ConfusionGas blob,
## mirroring Shattered Pixel Dungeon's ConfusionTrap (single-cell ConfusionGas
## seed of `300 + 20 * scalingDepth` volume). The trap applies no one-shot
## effect: the seeded ConfusionGas rides the shared blob timeline and prolongs
## Vertigo on anyone caught in the cloud.

func _make_level(depth: int = 6) -> Level:
	var level := Level.new()
	level.depth = depth
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
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60
	return hero

func _blob_at(level: Level, blob_id: String, pos: int) -> Variant:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			if blob.get_density(pos) > 0.0:
				return blob
	return null

func run(t: Object) -> void:
	seed(0xC0F)

	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level(6)
	var hero: Hero = _make_hero(trap_pos, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var trap := ConfusionTrap.new()
	trap.set_pos(trap_pos)
	trap.activate(hero, level)

	var gas: Variant = _blob_at(level, "confusion_gas", trap_pos)
	t.check(gas != null, "confusion trap seeds a lasting ConfusionGas blob")
	t.check(is_equal_approx(gas.get_density(trap_pos), 420.0),
		"confusion trap seeds 300 + 20*depth gas volume")
	t.check(not hero.has_buff("Vertigo"),
		"confusion trap does not apply Vertigo immediately")
	t.check(not trap.active, "confusion trap remains one-shot after activation")

	# One blob step: the standing hero gains SPD's prolonged Vertigo debuff.
	level.tick_blobs()
	t.check(hero.has_buff("Vertigo"),
		"seeded ConfusionGas applies Vertigo on the blob tick")

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
	hero.free()
