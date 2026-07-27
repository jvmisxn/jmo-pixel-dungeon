extends RefCounted
## Shocking enchant chain lightning (SPD parity; backlog audit:S13).
## Verifies the port matches upstream Shocking.proc/arc:
##   - the struck defender takes NO bonus damage (proc returns damage unmodified)
##   - lightning arcs from the defender: initial reach 2, then 1 per hop
##     (2 when the caught char stands in water and is not flying)
##   - each other opposing caught char takes round(damage * 0.5 * power_multi)
##   - the attacker is never caught by an arc
##   - allied mobs are not damaged but still conduct the chain
##   - power_multi scales the arc damage (Enraged Catalyst hook)

const W: int = ConstantsData.WIDTH

## Grid stand-in: chars by cell, optional water cells, wrap-safe adjacency,
## open passability so arcs flood freely (same shape as test_wand_of_lightning).
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
	func get_terrain(pos: int) -> int:
		return ConstantsData.Terrain.WATER if water_cells.has(pos) \
			else ConstantsData.Terrain.EMPTY

func run(t: Object) -> void:
	_test_defender_unhurt_by_arc(t)
	_test_arc_reach_and_hop_chain(t)
	_test_water_extends_hop_reach(t)
	_test_attacker_never_caught(t)
	_test_ally_conducts_without_damage(t)
	_test_power_multi_scales_damage(t)

func _make_mob(pos: int) -> Char:
	var c: Char = Char.new()
	c.name = "Mob%d" % pos
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

func _make_attacker(floor: Object, pos: int) -> Hero:
	var hero := Hero.new()
	hero.name = "Attacker"
	hero.is_alive = true
	hero.hp_max = 100000
	hero.hp = 100000
	hero.pos = pos
	hero.level = floor
	floor.chars[pos] = hero
	return hero

func _ench() -> WeaponEnchantment:
	return WeaponEnchantment.create("shocking")

func _test_defender_unhurt_by_arc(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var defender: Char = _make_mob(center)
	floor.chars[center] = defender
	var hero: Hero = _make_attacker(floor, center - 1)

	_ench()._shocking_discharge(hero, defender, 100, 1.0)

	t.check(defender.hp == 100000,
		"struck defender takes no bonus damage from the lightning")

	defender.free()
	hero.free()

func _test_arc_reach_and_hop_chain(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var defender: Char = _make_mob(center)
	var near: Char = _make_mob(center + 2)   # initial reach 2 from defender
	var hop: Char = _make_mob(center + 3)    # reach 1 re-arc from `near`
	var far: Char = _make_mob(center + 5)    # beyond any hop -> untouched
	floor.chars[defender.pos] = defender
	floor.chars[near.pos] = near
	floor.chars[hop.pos] = hop
	floor.chars[far.pos] = far
	var hero: Hero = _make_attacker(floor, center - 1)

	_ench()._shocking_discharge(hero, defender, 100, 1.0)

	# Arced enemies take round(100 * 0.5 * 1.0) = 50.
	t.check(near.hp == 100000 - 50, "enemy within initial reach 2 takes 50")
	t.check(hop.hp == 100000 - 50, "enemy one hop (reach 1) further takes 50")
	t.check(far.hp == 100000, "enemy beyond the chain is untouched")

	defender.free()
	near.free()
	hop.free()
	far.free()
	hero.free()

func _test_water_extends_hop_reach(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var defender: Char = _make_mob(center)
	var conduit: Char = _make_mob(center + 2)  # standing in water -> re-arc reach 2
	var beyond: Char = _make_mob(center + 4)
	floor.water_cells[conduit.pos] = true
	floor.chars[defender.pos] = defender
	floor.chars[conduit.pos] = conduit
	floor.chars[beyond.pos] = beyond
	var hero: Hero = _make_attacker(floor, center - 1)

	_ench()._shocking_discharge(hero, defender, 100, 1.0)

	t.check(conduit.hp == 100000 - 50, "wet conduit enemy takes arc damage")
	t.check(beyond.hp == 100000 - 50,
		"water extends the hop reach to 2: enemy at +4 is caught")

	defender.free()
	conduit.free()
	beyond.free()
	hero.free()

func _test_attacker_never_caught(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var defender: Char = _make_mob(center)
	floor.chars[center] = defender
	var hero: Hero = _make_attacker(floor, center + 1)

	_ench()._shocking_discharge(hero, defender, 100, 1.0)

	t.check(hero.hp == 100000, "adjacent attacker is never caught by the arc")

	defender.free()
	hero.free()

func _test_ally_conducts_without_damage(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var defender: Char = _make_mob(center)
	var ally: Mob = _make_ally_mob(center + 2)   # caught by initial reach 2
	var beyond: Char = _make_mob(center + 3)     # reachable only via the ally
	floor.chars[defender.pos] = defender
	floor.chars[ally.pos] = ally
	floor.chars[beyond.pos] = beyond
	var hero: Hero = _make_attacker(floor, center - 1)

	_ench()._shocking_discharge(hero, defender, 100, 1.0)

	t.check(ally.hp == 100000, "allied mob caught by the chain is not damaged")
	t.check(beyond.hp == 100000 - 50,
		"ally still conducts the chain to the enemy beyond it")

	defender.free()
	ally.free()
	beyond.free()
	hero.free()

func _test_power_multi_scales_damage(t: Object) -> void:
	var floor := _FakeLevel.new()
	var center: int = 8 * W + 8
	var defender: Char = _make_mob(center)
	var near: Char = _make_mob(center + 1)
	floor.chars[defender.pos] = defender
	floor.chars[near.pos] = near
	var hero: Hero = _make_attacker(floor, center - 1)

	_ench()._shocking_discharge(hero, defender, 100, 1.2)

	t.check(near.hp == 100000 - 60,
		"power_multi 1.2 scales arc damage to round(100*0.5*1.2)=60")

	defender.free()
	near.free()
	hero.free()
