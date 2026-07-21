extends RefCounted
## Coverage for WeakeningTrap, mirroring Shattered Pixel Dungeon's WeakeningTrap:
## a one-shot City trap that prolongs Weakness for `Weakness.DURATION * 3` on the
## character standing on it. The port's Weakness base duration is 20, so the trap
## applies a 60-turn Weakness. The upstream boss/miniboss `DURATION/2` floor and
## the mob HazardAssistTracker hint are documented divergences (not modelled).

func _make_level(depth: int = 12) -> Level:
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

func run(t: Object) -> void:
	seed(0x3EA)

	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level(12)
	var hero: Hero = _make_hero(trap_pos, level)

	# Terrain becomes an active trap so activation flips it to INACTIVE_TRAP.
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)

	var trap := WeakeningTrap.new()
	trap.set_pos(trap_pos)

	t.check(trap.trap_name == "weakening trap", "trap reports its name")
	t.check(not hero.has_buff("Weakness"), "hero starts without Weakness")

	trap.activate(hero, level)

	t.check(hero.has_buff("Weakness"), "weakening trap applies Weakness to the triggerer")
	var weakness: Buff = hero.get_buff("Weakness")
	t.check(weakness != null and is_equal_approx(weakness.get_time_left(), Weakness.BASE_DURATION * 3.0),
		"weakening trap applies Weakness for 3x the base duration (60 turns)")

	# One-shot: trap goes inactive and its tile becomes INACTIVE_TRAP.
	t.check(not trap.active, "weakening trap is consumed as a one-shot")
	t.check(level.terrain_at(trap_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"weakening trap tile becomes inactive after firing")

	# Re-applying (prolong) extends but never shortens an existing Weakness.
	var short := Weakness.new()
	short.set_duration(5.0)
	hero.add_buff(short)
	var again := WeakeningTrap.new()
	again.set_pos(trap_pos)
	again._do_effect(hero, level)
	var refreshed: Buff = hero.get_buff("Weakness")
	t.check(refreshed != null and refreshed.get_time_left() >= Weakness.BASE_DURATION * 3.0,
		"re-triggering prolongs Weakness to at least the trap duration (never shortens)")
