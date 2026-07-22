extends RefCounted
## PitfallTrap parity coverage against Shattered Pixel Dungeon's PitfallTrap +
## DelayedPit. Upstream a pitfall does NOT drop anyone the instant it fires: it
## attaches a one-turn DelayedPit buff to the hero recording the 3x3 open
## footprint, and one game-turn later every non-flying character still on a
## footprint cell falls together (mobs die via Chasm.mobFall, the hero last via
## the fall/descent path). On boss levels or past the last droppable depth the
## trap fires, is consumed, but nothing is scheduled or dropped.

## Minimal footprint-mob stand-in. find_char_at()/mob_at() are duck-typed, so a
## plain Node with pos/is_alive/flying is enough to be caught (or spared) by the
## collapse without pulling in the full Mob death pipeline. add_buff() lets a mob
## host the DelayedPit on the hero-less fallback path.
class MockMob:
	extends Node
	var pos: int = -1
	var is_alive: bool = true
	var is_hero: bool = false
	var flying: bool = false
	var died: bool = false
	var death_cause: String = ""

	func die(cause: String = "") -> void:
		died = true
		death_cause = cause
		is_alive = false

	func add_buff(buff: Node) -> Node:
		add_child(buff)
		if buff.has_method("attach"):
			buff.attach(self)
		return buff

func _make_level(depth: int) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _hero_has_delayed_pit(hero: Hero) -> bool:
	return hero.has_buff("DelayedPit")

func run(t: Object) -> void:
	var original_depth: int = GameManager.depth
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Variant = GameManager.current_level

	# Count hero_fell emissions across the whole test.
	var fell_count: Array = [0]
	var on_fell: Callable = func(_h: Variant) -> void:
		fell_count[0] += 1
	EventBus.hero_fell.connect(on_fell)

	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)

	# --- Droppable floor: delayed 3x3 collapse ---
	GameManager.depth = 6
	var level: Level = _make_level(6)
	GameManager.current_level = level

	var hero := Hero.new()
	hero.pos = trap_pos
	hero.level = level
	GameManager.hero = hero
	GameManager.heroes = [hero]

	# Adjacent mob (inside the 3x3 footprint), a distant mob (outside it), and a
	# flying mob adjacent to the trap that should float over the collapse.
	var near_mob := MockMob.new()
	near_mob.pos = trap_pos + 1
	level.add_mob(near_mob)
	var far_mob := MockMob.new()
	far_mob.pos = trap_pos + 5 * ConstantsData.WIDTH
	level.add_mob(far_mob)
	var flyer := MockMob.new()
	flyer.pos = trap_pos - 1
	flyer.flying = true
	level.add_mob(flyer)

	var trap := PitfallTrap.new()
	level.place_trap(trap_pos, trap)
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	level.trigger_trap(trap_pos, hero)

	# Nothing falls on the turn the trap fires — only a DelayedPit is scheduled.
	t.check(fell_count[0] == 0, "hero does not fall on the turn the pitfall fires")
	t.check(not near_mob.died, "adjacent mob does not fall on the turn the pitfall fires")
	t.check(_hero_has_delayed_pit(hero), "pitfall schedules a DelayedPit buff on the hero")
	t.check(not trap.active, "pitfall is consumed (one-shot) when it fires")

	# One game-turn later the footprint collapses.
	hero.process_buffs(1.0)

	t.check(fell_count[0] == 1, "hero falls one turn after the pitfall fires")
	t.check(near_mob.died, "adjacent mob in the footprint falls to its death")
	t.check(near_mob.death_cause == "chasm", "footprint mob death is attributed to the fall")
	t.check(not far_mob.died, "a mob outside the 3x3 footprint is not dropped")
	t.check(not flyer.died, "a flying mob in the footprint floats over the collapse")
	t.check(not _hero_has_delayed_pit(hero), "DelayedPit detaches after the collapse")

	# --- Sealed: boss depth. Trap fires but schedules/drops nothing. ---
	GameManager.depth = ConstantsData.BOSS_DEPTHS[0]
	var boss_level: Level = _make_level(GameManager.depth)
	GameManager.current_level = boss_level
	var boss_hero := Hero.new()
	boss_hero.pos = trap_pos
	boss_hero.level = boss_level
	GameManager.hero = boss_hero
	GameManager.heroes = [boss_hero]
	var boss_mob := MockMob.new()
	boss_mob.pos = trap_pos + 1
	boss_level.add_mob(boss_mob)

	var boss_trap := PitfallTrap.new()
	boss_level.place_trap(trap_pos, boss_trap)
	boss_level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	boss_level.trigger_trap(trap_pos, boss_hero)
	t.check(not _hero_has_delayed_pit(boss_hero), "no pit is scheduled on a boss level")
	t.check(not boss_trap.active, "pitfall is still consumed (one-shot) on a boss level")
	boss_hero.process_buffs(1.0)
	t.check(fell_count[0] == 1, "hero does not fall through a boss-level pitfall")
	t.check(not boss_mob.died, "mob does not fall to a pitfall on a boss level")

	# --- Sealed: final depth (depth >= MAX_DEPTH). ---
	GameManager.depth = ConstantsData.MAX_DEPTH
	var deep_level: Level = _make_level(GameManager.depth)
	GameManager.current_level = deep_level
	var deep_hero := Hero.new()
	deep_hero.pos = trap_pos
	deep_hero.level = deep_level
	GameManager.hero = deep_hero
	GameManager.heroes = [deep_hero]
	var deep_trap := PitfallTrap.new()
	deep_level.place_trap(trap_pos, deep_trap)
	deep_level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	deep_level.trigger_trap(trap_pos, deep_hero)
	deep_hero.process_buffs(1.0)
	t.check(fell_count[0] == 1, "hero does not fall to a pitfall at the final depth")

	# --- No hero present: a mob-triggered pitfall still collapses via the mob. ---
	GameManager.depth = 6
	GameManager.hero = null
	GameManager.heroes = []
	var lone_level: Level = _make_level(6)
	GameManager.current_level = lone_level
	var lone_mob := MockMob.new()
	lone_mob.pos = trap_pos
	lone_level.add_mob(lone_mob)
	var lone_trap := PitfallTrap.new()
	lone_trap.set_pos(trap_pos)
	lone_level.place_trap(trap_pos, lone_trap)
	lone_level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	lone_trap.activate(lone_mob, lone_level)
	t.check(not lone_mob.died, "lone mob does not fall on the turn the pitfall fires")
	# The buff was hosted on the triggering mob; MockMob has no Char buff pipeline,
	# so drive the hosted DelayedPit's turn directly.
	var hosted: Variant = null
	for child: Node in lone_mob.get_children():
		if child is DelayedPit:
			hosted = child
	t.check(hosted != null, "hero-less pitfall hosts the DelayedPit on the triggering mob")
	if hosted != null:
		hosted.act()
	t.check(lone_mob.died, "mob-triggered pitfall drops the mob one turn later with no hero present")

	EventBus.hero_fell.disconnect(on_fell)
	GameManager.depth = original_depth
	GameManager.hero = original_hero
	GameManager.heroes = original_heroes
	GameManager.current_level = original_level
	hero.free()
	boss_hero.free()
	deep_hero.free()
	near_mob.free()
	far_mob.free()
	flyer.free()
	boss_mob.free()
	lone_mob.free()
