extends RefCounted
## Warden Barkskin talent (upstream Talent.BARKSKIN, Hero.act() tail):
## ending a turn standing in furrowed grass calls
## Barkskin.conditionallyAppend(hero, lvl * points / 2, 1) — a decaying
## barkskin whose level refreshes while the hero stays in the furrow.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_warden(points: int, hero_pos: int, level: Level, lvl: int = 10) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARDEN
	hero.pos = hero_pos
	hero.level = level
	hero.hero_level = lvl
	hero.hp = 30
	hero.hp_max = 30
	if points > 0:
		hero.talent_levels["warden_barkskin"] = points
	return hero

func _hero_barkskin(hero: Hero) -> Barkskin:
	return hero.get_buff("Barkskin") as Barkskin

func run(t: Object) -> void:
	_test_registry(t)
	_test_trigger_and_scaling(t)
	_test_gating(t)
	_test_refresh_and_decay(t)

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "warden_barkskin",
		ConstantsData.HeroSubclass.WARDEN
	)
	t.check(info != null and info.implemented, "Warden Barkskin is registered and implemented")
	t.check(info != null and info.max_points == 3, "Barkskin caps at 3 points")
	var old_slot: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "warden_barkskin_mastery",
		ConstantsData.HeroSubclass.WARDEN
	)
	t.check(old_slot == null, "non-upstream barkskin_mastery slot is gone")

func _test_trigger_and_scaling(t: Object) -> void:
	var level: Level = _make_level()
	var furrow: int = ConstantsData.xy_to_pos(10, 10)
	level.set_terrain(furrow, ConstantsData.Terrain.FURROWED_GRASS)

	var hero: Hero = _make_warden(2, furrow, level, 10)
	hero._apply_barkskin_talent()
	var bark: Barkskin = _hero_barkskin(hero)
	t.check(bark != null, "furrowed grass grants barkskin with the talent")
	t.check(bark != null and bark.level == 10, "+2 at hero level 10 gives 10*2/2 = 10")
	t.check(bark != null and bark.interval == 1, "talent barkskin decays every turn")
	hero.free()

	# Integer division: level 9 at +1 -> 9*1/2 = 4.
	var low: Hero = _make_warden(1, furrow, level, 9)
	low._apply_barkskin_talent()
	var low_bark: Barkskin = _hero_barkskin(low)
	t.check(low_bark != null and low_bark.level == 4, "+1 at hero level 9 gives 9/2 = 4")
	low.free()

	var strong: Hero = _make_warden(3, furrow, level, 10)
	strong._apply_barkskin_talent()
	var strong_bark: Barkskin = _hero_barkskin(strong)
	t.check(strong_bark != null and strong_bark.level == 15, "+3 at hero level 10 gives 15")
	strong.free()

func _test_gating(t: Object) -> void:
	var level: Level = _make_level()
	var furrow: int = ConstantsData.xy_to_pos(10, 10)
	var grass: int = ConstantsData.xy_to_pos(11, 10)
	level.set_terrain(furrow, ConstantsData.Terrain.FURROWED_GRASS)
	level.set_terrain(grass, ConstantsData.Terrain.GRASS)

	var untalented: Hero = _make_warden(0, furrow, level)
	untalented._apply_barkskin_talent()
	t.check(_hero_barkskin(untalented) == null, "no talent points -> no barkskin")
	untalented.free()

	var off_furrow: Hero = _make_warden(3, grass, level)
	off_furrow._apply_barkskin_talent()
	t.check(_hero_barkskin(off_furrow) == null, "plain grass does not trigger the talent")
	off_furrow.free()

func _test_refresh_and_decay(t: Object) -> void:
	var level: Level = _make_level()
	var furrow: int = ConstantsData.xy_to_pos(10, 10)
	level.set_terrain(furrow, ConstantsData.Terrain.FURROWED_GRASS)

	var hero: Hero = _make_warden(2, furrow, level, 10)
	hero._apply_barkskin_talent()
	var bark: Barkskin = _hero_barkskin(hero)
	t.check(bark != null and bark.level == 10, "initial barkskin level is 10")

	# Decay one turn, then re-trigger: same interval-1 instance refreshes.
	if bark != null:
		bark.on_turn()
	t.check(bark != null and bark.level == 9, "barkskin decays by 1 per turn")
	hero._apply_barkskin_talent()
	var buff_count: int = 0
	for buff: Node in hero.get_buffs():
		if buff is Barkskin:
			buff_count += 1
	t.check(buff_count == 1, "re-trigger reuses the interval-1 barkskin instance")
	var refreshed: Barkskin = _hero_barkskin(hero)
	t.check(refreshed != null and refreshed.level == 10, "re-trigger refreshes level to 10")
	hero.free()
