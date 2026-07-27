extends RefCounted
## Upstream Mob.holdAllies/restoreAllies: the Dried Rose ghost follows the
## party across floor transitions instead of being destroyed on departure.
## FloorTransitionCoordinator.hold_party_allies serializes follower allies off
## the departing level; restore_party_allies respawns them beside the party on
## the arrival level and re-links the rose to its ghost.

func _make_level(depth: int) -> Level:
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
	hero.hp = 30
	hero.hp_max = 30
	hero.ht = 30
	return hero

func run(t: Object) -> void:
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level
	var original_held: Array[Dictionary] = GameManager.held_allies.duplicate()
	GameManager.held_allies.clear()

	var level_a: Level = _make_level(3)
	var hero: Hero = _make_hero(ConstantsData.xy_to_pos(10, 10), level_a)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level_a
	GameManager.add_hero(hero)

	# Equip a Dried Rose and summon its ghost.
	var rose: Variant = Generator.create_item("dried_rose")
	t.check(rose != null, "generator creates the dried rose")
	hero.belongings.artifact = rose
	rose.charge = rose.charge_max
	var summoned: bool = rose.activate(hero)
	t.check(summoned, "rose summons the ghost on the first floor")
	var ghost: Variant = rose.current_ghost
	t.check(ghost != null and bool(ghost.get("follows_hero")),
		"summoned rose ghost is marked as a follower ally")
	if ghost != null:
		ghost.hp = 13

	# A plain mob on the level must not follow the party.
	var rat: Mob = MobFactory.create_mob("rat")
	rat.pos = ConstantsData.xy_to_pos(20, 20)
	level_a.add_mob(rat)

	# Departure: artifact hook syncs HP + drops the reference, hold pulls the
	# ghost off the level.
	FloorTransitionCoordinator.notify_party_floor_change(RefCounted.new())
	t.check(int(rose.ghost_hp) == 13, "rose syncs ghost HP on departure")
	t.check(bool(rose.ghost_summoned), "ghost_summoned stays true across floors")
	t.check(rose.current_ghost == null, "rose drops the node reference on departure")
	t.check(GameManager.held_allies.size() == 1
			and str(GameManager.held_allies[0].get("mob_id")) == "rose_ghost",
		"only the follower ghost is held, not regular mobs")
	var still_has_ghost: bool = false
	for mob: Variant in level_a.mobs:
		if is_instance_valid(mob) and str(mob.get("mob_id")) == "rose_ghost":
			still_has_ghost = true
	t.check(not still_has_ghost, "held ghost is removed from the departing level")
	t.check(rat in level_a.mobs, "the rat stays behind on the old level")

	# Arrival: restore beside the hero on the new level and re-link the rose.
	var level_b: Level = _make_level(4)
	GameManager.current_level = level_b
	hero.level = level_b
	hero.pos = ConstantsData.xy_to_pos(15, 15)
	FloorTransitionCoordinator.restore_party_allies(level_b)
	t.check(GameManager.held_allies.is_empty(), "held list clears after restore")
	var restored: Variant = null
	for mob: Variant in level_b.mobs:
		if str(mob.get("mob_id")) == "rose_ghost":
			restored = mob
	t.check(restored != null, "ghost respawns on the arrival level")
	if restored != null:
		t.check(int(restored.get("hp")) == 13, "ghost HP carries across the transition")
		t.check(level_b.distance(restored.pos, hero.pos) == 1,
			"ghost arrives adjacent to the hero")
		t.check(rose.current_ghost == restored, "rose re-links to the restored ghost")
		t.check(restored.get("source_artifact") == rose,
			"restored ghost points back at the rose")
		t.check(restored.get("ally_hero") == hero, "restored ghost follows the hero")

	# A dead ghost is not held on a later transition.
	if restored != null:
		restored.hp = 0
		restored.is_alive = false
	FloorTransitionCoordinator.hold_party_allies()
	t.check(GameManager.held_allies.is_empty(), "dead allies are not held")

	for mob: Variant in level_a.mobs:
		if is_instance_valid(mob) and mob is Node:
			(mob as Node).free()
	for mob: Variant in level_b.mobs:
		if is_instance_valid(mob) and mob is Node:
			(mob as Node).free()
	hero.free()
	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
	GameManager.held_allies = original_held
