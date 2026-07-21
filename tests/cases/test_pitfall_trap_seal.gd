extends RefCounted
## PitfallTrap boss/final-depth guard. Mirrors Shattered Pixel Dungeon's
## PitfallTrap.activate(), which refuses to drop anything on boss levels or past
## the last droppable depth (`if (Dungeon.bossLevel() || Dungeon.depth > 25 ...)`)
## and instead prints a "no pit" message. On droppable floors the hero falls
## (emitting `hero_fell`) and a non-levitating mob dies, unchanged.

## Minimal mob stand-in: PitfallTrap only needs die() plus the absence of the
## hero flag / levitation to route a non-hero through the death path.
class MockMob:
	extends Node
	var died: bool = false
	var death_cause: String = ""

	func die(cause: String = "") -> void:
		died = true
		death_cause = cause

## Minimal hero stand-in: is_hero=true routes through the hero_fell path.
class MockHero:
	extends Node
	var is_hero: bool = true

func _make_level(depth: int) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func run(t: Object) -> void:
	var original_depth: int = GameManager.depth
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)

	# Count hero_fell emissions across the whole test.
	var fell_count: Array = [0]
	var on_fell: Callable = func(_h: Variant) -> void:
		fell_count[0] += 1
	EventBus.hero_fell.connect(on_fell)

	# --- Sealed: boss depth. Trap fires but nothing drops. ---
	GameManager.depth = ConstantsData.BOSS_DEPTHS[0]  # 5
	var boss_level: Level = _make_level(GameManager.depth)

	var boss_mob := MockMob.new()
	var boss_trap := PitfallTrap.new()
	boss_trap.set_pos(trap_pos)
	boss_trap.activate(boss_mob, boss_level)
	t.check(not boss_mob.died, "mob does not die to a pitfall on a boss level")
	t.check(not boss_trap.active, "pitfall is still consumed (one-shot) on a boss level")

	var boss_hero := MockHero.new()
	var boss_hero_trap := PitfallTrap.new()
	boss_hero_trap.set_pos(trap_pos)
	boss_hero_trap.activate(boss_hero, boss_level)
	t.check(fell_count[0] == 0, "hero does not fall through a boss-level pitfall")

	# --- Sealed: final depth (depth >= MAX_DEPTH). ---
	GameManager.depth = ConstantsData.MAX_DEPTH
	var deep_level: Level = _make_level(GameManager.depth)
	var deep_mob := MockMob.new()
	var deep_trap := PitfallTrap.new()
	deep_trap.set_pos(trap_pos)
	deep_trap.activate(deep_mob, deep_level)
	t.check(not deep_mob.died, "mob does not die to a pitfall at the final depth")

	# --- Droppable: a normal floor drops as before. ---
	GameManager.depth = 6
	var open_level: Level = _make_level(GameManager.depth)

	var open_mob := MockMob.new()
	var open_trap := PitfallTrap.new()
	open_trap.set_pos(trap_pos)
	open_trap.activate(open_mob, open_level)
	t.check(open_mob.died, "mob falls to its death on a droppable floor")
	t.check(open_mob.death_cause == "pitfall trap", "mob death is attributed to the pitfall trap")

	var open_hero := MockHero.new()
	var open_hero_trap := PitfallTrap.new()
	open_hero_trap.set_pos(trap_pos)
	open_hero_trap.activate(open_hero, open_level)
	t.check(fell_count[0] == 1, "hero falls (hero_fell) on a droppable floor")

	EventBus.hero_fell.disconnect(on_fell)
	GameManager.depth = original_depth
	boss_mob.free()
	boss_hero.free()
	deep_mob.free()
	open_mob.free()
	open_hero.free()
