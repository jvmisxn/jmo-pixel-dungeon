extends RefCounted
## Coverage for GeyserTrap (SPD parity: teal water-burst trap).

func run(t: Object) -> void:
	_test_floods_water_and_douses_burning(t)
	_test_knocks_back_neighbour_and_center(t)
	_test_scalds_fire_elemental(t)
	_test_is_one_shot_and_serializes(t)

func _test_floods_water_and_douses_burning(t: Object) -> void:
	seed(3)
	var level := _make_level()
	var trap_pos := ConstantsData.xy_to_pos(15, 12)
	var mob := Mob.new()
	mob.pos = trap_pos
	mob.level = level
	mob.hp = 30
	mob.hp_max = 30
	level.add_mob(mob)
	var burn := Burning.new()
	mob.add_buff(burn)
	t.check(mob.has_buff("Burning"), "setup: mob is burning before the geyser")

	var trap := GeyserTrap.new()
	# Force the centre push into a known-open direction so the mob does not
	# block its own flooded cell check.
	trap.center_knock_back_direction = ConstantsData.DIR_E
	level.place_trap(trap_pos, trap)
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	level.trigger_trap(trap_pos, mob)

	# Inner ring always floods; check a cardinal neighbour that was EMPTY.
	var inner := trap_pos + ConstantsData.DIR_N
	t.check(level.terrain_at(inner) == ConstantsData.Terrain.WATER,
		"geyser floods an adjacent floor cell with water")
	t.check(not mob.has_buff("Burning"), "geyser water douses the character's Burning")

func _test_knocks_back_neighbour_and_center(t: Object) -> void:
	seed(5)
	var level := _make_level()
	var trap_pos := ConstantsData.xy_to_pos(15, 12)

	# Neighbour due east should be pushed further east (away from the trap).
	var neighbour := Mob.new()
	neighbour.pos = trap_pos + ConstantsData.DIR_E
	neighbour.level = level
	level.add_mob(neighbour)

	# Centre character pushed in a forced, known-open direction.
	var center := Mob.new()
	center.pos = trap_pos
	center.level = level
	level.add_mob(center)

	var trap := GeyserTrap.new()
	trap.center_knock_back_direction = ConstantsData.DIR_S
	trap.set_pos(trap_pos)
	trap.activate(null, level)

	t.check(ConstantsData.pos_to_x(neighbour.pos) > ConstantsData.pos_to_x(trap_pos + ConstantsData.DIR_E),
		"geyser knocks an east neighbour further away from the trap")
	t.check(level.distance(neighbour.pos, trap_pos) >= 2,
		"knocked-back neighbour ends at least 2 tiles from the trap")
	t.check(center.pos != trap_pos and ConstantsData.pos_to_y(center.pos) > ConstantsData.pos_to_y(trap_pos),
		"geyser pushes the centre character in the forced direction")

func _test_scalds_fire_elemental(t: Object) -> void:
	seed(9)
	var level := _make_level()
	level.depth = 15
	var trap_pos := ConstantsData.xy_to_pos(15, 12)
	var elemental := Elemental.new()
	elemental.pos = trap_pos
	elemental.level = level
	var full_hp: int = elemental.hp
	level.add_mob(elemental)

	var trap := GeyserTrap.new()
	trap.center_knock_back_direction = ConstantsData.DIR_W
	trap.set_pos(trap_pos)
	trap.activate(null, level)

	t.check(elemental.hp < full_hp, "geyser scalds a fire elemental standing on the trap")

func _test_is_one_shot_and_serializes(t: Object) -> void:
	seed(1)
	var level := _make_level()
	var trap_pos := ConstantsData.xy_to_pos(15, 12)
	var trap := GeyserTrap.new()
	level.place_trap(trap_pos, trap)
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	level.trigger_trap(trap_pos, null)

	t.check(not trap.active, "geyser trap is a one-shot: inactive after activation")
	t.check(level.terrain_at(trap_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"geyser trap tile becomes inactive after firing")

	var proto := GeyserTrap.new()
	proto.set_pos(77)
	proto.visible = true
	var restored := GeyserTrap.new()
	restored.deserialize(proto.serialize())
	t.check(restored.pos == 77, "geyser trap restores base position")
	t.check(restored.visible, "geyser trap restores visibility")

func _make_level() -> Level:
	var level := Level.new()
	level.map.fill(ConstantsData.Terrain.EMPTY)
	for i: int in range(ConstantsData.LENGTH):
		level.set_terrain(i, ConstantsData.Terrain.EMPTY)
	level.entrance = 0
	level.exit_pos = ConstantsData.LENGTH - 1
	return level
