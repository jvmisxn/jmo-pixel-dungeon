extends RefCounted
## WandOfLightning fidelity (SPD parity plan; backlog audit:S14 chain-lightning).
## Verifies the port matches upstream WandOfLightning:
##   - damage range min = 5+lvl, max = 10+5*lvl (was 3+lvl / 10+3*lvl)
##   - a SHARED crowd multiplier (0.4 + 0.6/N) applied EQUALLY to every affected
##     char, NOT a per-arc 0.7^n geometric falloff
##   - flood-fill arc reaches all chars within 1 tile (2 in water), recursively
##   - a struck cell in water conducts fully (multiplier forced to 1.0)
##   - the caster is only caught when the chain reaches them (adjacent / water)
##     and then takes half damage; a distant hero is untouched
##   - striking bare terrain fizzles harmlessly

const W: int = ConstantsData.WIDTH

## Grid stand-in: chars by cell, optional water cells, wrap-safe Chebyshev
## adjacency/distance, and open passability so arcs flood freely.
class _FakeLevel extends RefCounted:
	var chars: Dictionary = {}          # pos -> Char
	var water_cells: Dictionary = {}    # pos -> true
	func find_char_at(pos: int) -> Object:
		return chars.get(pos, null)
	func is_passable(_pos: int) -> bool:
		return true
	func adjacent(a: int, b: int) -> bool:
		var ax: int = a % ConstantsData.WIDTH
		var ay: int = a / ConstantsData.WIDTH
		var bx: int = b % ConstantsData.WIDTH
		var by: int = b / ConstantsData.WIDTH
		return absi(ax - bx) <= 1 and absi(ay - by) <= 1 and a != b
	func distance(a: int, b: int) -> int:
		var ax: int = a % ConstantsData.WIDTH
		var ay: int = a / ConstantsData.WIDTH
		var bx: int = b % ConstantsData.WIDTH
		var by: int = b / ConstantsData.WIDTH
		return maxi(absi(ax - bx), absi(ay - by))
	func get_terrain(pos: int) -> int:
		return ConstantsData.Terrain.WATER if water_cells.has(pos) \
			else ConstantsData.Terrain.EMPTY

## Deterministic damage roll so multiplier math is exact.
class _FixedLightning extends Wand.WandOfLightning:
	func roll_zap_damage() -> int:
		return 100

func run(t: Object) -> void:
	_test_damage_range(t)
	_test_single_target_full_damage(t)
	_test_crowd_shared_multiplier(t)
	_test_water_negates_reduction(t)
	_test_distant_hero_untouched(t)
	_test_adjacent_hero_caught_at_half(t)
	_test_arcs_skip_allied_mobs(t)
	_test_allies_conduct_without_damage(t)
	_test_directly_struck_ally_is_hit(t)
	_test_bare_terrain_fizzles(t)

func _make_wand() -> Object:
	var w: Object = _FixedLightning.new()
	w.level = 0
	return w

func _make_mob(pos: int) -> Char:
	var c: Char = Char.new()
	c.name = "Zap%d" % pos
	c.hp_max = 100000
	c.hp = 100000
	c.is_alive = true
	c.pos = pos
	return c

func _make_ally_mob(pos: int) -> Mob:
	var c: Mob = Mob.new()
	c.name = "Ally%d" % pos
	c.hp_max = 100000
	c.hp = 100000
	c.is_alive = true
	c.pos = pos
	c.is_ally = true
	return c

func _make_caster(floor: Object) -> Hero:
	var hero := Hero.new()
	hero.name = "Caster"
	hero.is_alive = true
	hero.level = floor
	return hero

func _test_damage_range(t: Object) -> void:
	var w: Object = Wand.WandOfLightning.new()
	t.check(w.get_damage(0) == [5, 10],
		"lvl0 damage range is [5,10] (SPD 5+lvl / 10+5*lvl)")
	t.check(w.get_damage(3) == [8, 25],
		"lvl3 damage range is [8,25]")

func _test_single_target_full_damage(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var mob: Char = _make_mob(center)
	floor.chars[center] = mob
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	# One target -> multiplier 1.0 -> full 100 damage.
	t.check(mob.hp == 100000 - 100, "lone target takes full damage (mult 1.0)")

	mob.free()
	hero.free()

func _test_crowd_shared_multiplier(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var m_c: Char = _make_mob(center)
	var m_e: Char = _make_mob(center + 1)
	var m_w: Char = _make_mob(center - 1)
	floor.chars[center] = m_c
	floor.chars[center + 1] = m_e
	floor.chars[center - 1] = m_w
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	# 3 affected -> multiplier 0.4 + 0.6/3 = 0.6 -> each takes round(100*0.6)=60,
	# applied EQUALLY (no per-arc falloff, which would give 60/70/49-style spread).
	t.check(m_c.hp == 100000 - 60, "struck center takes shared-multiplier 60")
	t.check(m_e.hp == 100000 - 60, "arced east mob takes 60 (same multiplier)")
	t.check(m_w.hp == 100000 - 60, "arced west mob takes 60 (same multiplier)")

	m_c.free()
	m_e.free()
	m_w.free()
	hero.free()

func _test_water_negates_reduction(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	floor.water_cells[center] = true
	var m_c: Char = _make_mob(center)
	var m_e: Char = _make_mob(center + 1)
	var m_w: Char = _make_mob(center - 1)
	floor.chars[center] = m_c
	floor.chars[center + 1] = m_e
	floor.chars[center - 1] = m_w
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	# Struck cell is water -> multiplier forced to 1.0 -> all take full 100.
	t.check(m_c.hp == 100000 - 100, "water: struck center takes full 100")
	t.check(m_e.hp == 100000 - 100, "water: arced mob still takes full 100")
	t.check(m_w.hp == 100000 - 100, "water: arced mob still takes full 100")

	m_c.free()
	m_e.free()
	m_w.free()
	hero.free()

func _test_distant_hero_untouched(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var mob: Char = _make_mob(center)
	floor.chars[center] = mob
	# Caster is a real Hero, placed 2 tiles away (out of a dry arc's reach).
	var hero := Hero.new()
	hero.is_alive = true
	hero.hp_max = 100000
	hero.hp = 100000
	hero.pos = center + 2 * W + 2
	hero.level = floor
	floor.chars[hero.pos] = hero
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	t.check(mob.hp == 100000 - 100, "struck mob takes full damage")
	t.check(hero.hp == 100000, "distant caster is NOT shocked (>1 tile, no water)")

	mob.free()
	hero.free()

func _test_adjacent_hero_caught_at_half(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var mob: Char = _make_mob(center)
	floor.chars[center] = mob
	# Caster adjacent to the struck mob -> caught by the arc.
	var hero := Hero.new()
	hero.is_alive = true
	hero.hp_max = 100000
	hero.hp = 100000
	hero.pos = center + 1
	hero.level = floor
	floor.chars[hero.pos] = hero
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	# mob + hero affected -> multiplier 0.4 + 0.6/2 = 0.7.
	# mob = round(100*0.7) = 70; hero (caster) = round(100*0.7*0.5) = 35.
	t.check(mob.hp == 100000 - 70, "adjacent-hero case: mob takes 70 (2 affected)")
	t.check(hero.hp == 100000 - 35, "caught caster takes HALF damage (35)")

	mob.free()
	hero.free()

func _test_arcs_skip_allied_mobs(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var mob: Char = _make_mob(center)
	var ally: Mob = _make_ally_mob(center + 1)
	floor.chars[center] = mob
	floor.chars[ally.pos] = ally
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	t.check(mob.hp == 100000 - 100, "only the enemy is affected when an ally is nearby")
	t.check(ally.hp == 100000, "chain lightning does not arc into allied mobs")

	mob.free()
	ally.free()
	hero.free()

func _test_allies_conduct_without_damage(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var mob: Char = _make_mob(center)
	var ally: Mob = _make_ally_mob(center + 1)
	var beyond: Char = _make_mob(center + 2)
	floor.chars[center] = mob
	floor.chars[ally.pos] = ally
	floor.chars[beyond.pos] = beyond
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	# SPD builds arcs before removing same-alignment chained targets, so the ally
	# is unharmed but still conducts the chain to the enemy beyond it.
	t.check(mob.hp == 100000 - 70,
		"ally conduit: direct enemy uses two-damage-target multiplier")
	t.check(ally.hp == 100000, "ally conduit: chained ally is not damaged")
	t.check(beyond.hp == 100000 - 70, "ally conduit: enemy beyond ally is hit")

	mob.free()
	ally.free()
	beyond.free()
	hero.free()

func _test_directly_struck_ally_is_hit(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var ally: Mob = _make_ally_mob(center)
	floor.chars[center] = ally
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	w.on_zap(hero, [center] as Array[int])

	t.check(ally.hp == 100000 - 100,
		"a directly struck ally is still affected, matching SPD's collision-cell exception")

	ally.free()
	hero.free()

func _test_bare_terrain_fizzles(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var mob: Char = _make_mob(center + 5)  # a mob well away from the struck cell
	floor.chars[mob.pos] = mob
	var hero: Char = _make_caster(floor)
	var w: Object = _make_wand()

	# Strike an empty cell: no char there, no chain starts.
	w.on_zap(hero, [center] as Array[int])

	t.check(mob.hp == 100000, "striking bare terrain harms nobody")

	mob.free()
	hero.free()
