extends RefCounted
## Coverage for CorrosionTrap seeding a lasting CorrosiveGas blob, mirroring
## Shattered Pixel Dungeon's CorrosionTrap (single-cell CorrosiveGas seed of
## `80 + 5 * scalingDepth` volume, strength `1 + scalingDepth/4`).
##
## The trap no longer applies the wrong Ooze buff or a one-shot hit: it seeds
## CorrosiveGas at its cell and the blob spreads by diffusion and applies the
## real escalating Corrosion debuff as it rides the shared blob timeline.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 8
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
	hero.hp = 999
	hero.hp_max = 999
	hero.ht = 999
	return hero

func _get_blob(level: Level, blob_id: String) -> Variant:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return blob
	return null

func run(t: Object) -> void:
	seed(0xC0FF)

	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(hero_pos, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var trap := CorrosionTrap.new()
	trap.set_pos(hero_pos)
	trap.activate(hero, level)

	var gas: Variant = _get_blob(level, "corrosive_gas")
	t.check(gas != null, "corrosion trap seeds a lasting CorrosiveGas blob")
	t.check(not hero.has_buff("Ooze"), "corrosion trap no longer applies the wrong Ooze buff")
	t.check(not hero.has_buff("Corrosion"), "corrosion trap waits for the blob tick before corroding")
	t.check(hero.hp == 999, "corrosion trap deals no one-shot direct damage")
	t.check(not trap.active, "corrosion trap remains one-shot after activation")

	# SPD depth-8 seed: volume 80 + 5*8 = 120, strength 1 + 8/4 = 3.
	t.check(int(gas.strength) == 3, "corrosion trap sets strength = 1 + depth/4")
	t.check(
		abs(float(gas.density[hero_pos]) - 120.0) < 0.001,
		"corrosion trap seeds 80 + 5*depth volume at its cell"
	)

	# One blob step: the standing hero gains the real escalating Corrosion debuff.
	level.tick_blobs()
	var corrosion: Variant = hero.get_buff("Corrosion")
	t.check(corrosion != null, "corrosion trap's CorrosiveGas applies the real Corrosion debuff")

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
	hero.free()
