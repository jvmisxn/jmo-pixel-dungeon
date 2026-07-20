extends RefCounted
## Coverage for the Stone of Disarming.
##
## Regression: the stone applied a `Weakness` debuff to an adjacent character,
## which is not what SPD's Stone of Disarming does. Upstream `StoneOfDisarming`
## reveals and disarms up to the nine nearest active traps within range
## (`t.reveal(); t.disarm();`, capped at nine). This port centres the effect on
## the hero (no thrown-cell target for runestones yet) using a Chebyshev radius.

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
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60
	return hero

## Place a fresh trap at [pos] as visible/hidden and paint its terrain.
func _place_trap(level: Level, pos: int, hidden: bool) -> Trap:
	var trap := ParalyticTrap.new()
	level.place_trap(pos, trap)
	trap.visible = not hidden
	level.set_terrain(pos, ConstantsData.Terrain.SECRET_TRAP if hidden else ConstantsData.Terrain.TRAP)
	return trap

func run(t: Object) -> void:
	seed(0xD15A2)
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(15, 15)
	var hero: Hero = _make_hero(hero_pos, level)

	# Two traps in range (one hidden), one just out of range.
	var near_pos: int = ConstantsData.xy_to_pos(15, 17)          # dist 2
	var hidden_pos: int = ConstantsData.xy_to_pos(18, 15)        # dist 3, hidden
	var far_pos: int = ConstantsData.xy_to_pos(15 + Stone.DISARM_DIST + 2, 15)  # out of range

	var near_trap: Trap = _place_trap(level, near_pos, false)
	var hidden_trap: Trap = _place_trap(level, hidden_pos, true)
	var far_trap: Trap = _place_trap(level, far_pos, false)

	t.check(level.distance(hero_pos, near_pos) <= Stone.DISARM_DIST, "near trap is within disarm range")
	t.check(level.distance(hero_pos, far_pos) > Stone.DISARM_DIST, "far trap is out of disarm range")

	var stone: Stone = Stone.create("disarming")
	t.check(stone != null, "factory builds a Stone of Disarming")
	t.check(stone.stone_type == Stone.StoneType.DISARMING, "stone has the DISARMING type")

	stone._use_disarming(hero)

	# In-range traps are disarmed: inactive, dropped from the live table, tile
	# turned to INACTIVE_TRAP; the hidden one is revealed along the way.
	t.check(not near_trap.active, "in-range trap is deactivated")
	t.check(not hidden_trap.active, "in-range hidden trap is deactivated")
	t.check(hidden_trap.visible, "hidden trap was revealed before being disarmed")
	t.check(not level.traps.has(near_pos), "disarmed trap is removed from the level trap table")
	t.check(not level.traps.has(hidden_pos), "disarmed hidden trap is removed from the level trap table")
	t.check(level.terrain_at(near_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"disarmed trap tile becomes INACTIVE_TRAP")
	t.check(level.terrain_at(hidden_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"disarmed hidden trap tile becomes INACTIVE_TRAP")

	# Out-of-range trap is untouched.
	t.check(far_trap.active, "out-of-range trap stays active")
	t.check(level.traps.has(far_pos), "out-of-range trap stays in the trap table")

	# The stone no longer applies Weakness to a bystander.
	t.check(hero.get_buff("Weakness") == null, "stone does not weaken the hero")

	hero.free()

	# Nine-trap cap: seed 12 in-range traps, only nine should be disarmed.
	var level2: Level = _make_level()
	var hero2_pos: int = ConstantsData.xy_to_pos(15, 15)
	var hero2: Hero = _make_hero(hero2_pos, level2)
	var seeded: Array[Trap] = []
	for i: int in range(12):
		var col: int = 8 + i  # columns 8..19, all on row 15, within DIST 8 of col 15
		var tp: int = ConstantsData.xy_to_pos(col, 15)
		if tp == hero2_pos:
			continue
		seeded.append(_place_trap(level2, tp, false))
	# Keep only those actually in range for the assertion count.
	var in_range: Array[Trap] = []
	for tr: Trap in seeded:
		if level2.distance(hero2_pos, tr.pos) <= Stone.DISARM_DIST:
			in_range.append(tr)
	t.check(in_range.size() > Stone.DISARM_MAX_TRAPS, "more than nine traps are in range for the cap test")

	Stone.create("disarming")._use_disarming(hero2)

	var disarmed_count: int = 0
	for tr: Trap in in_range:
		if not tr.active:
			disarmed_count += 1
	t.check(disarmed_count == Stone.DISARM_MAX_TRAPS,
		"exactly nine traps are disarmed when more are in range (cap)")

	hero2.free()
