extends RefCounted
## Necromancer's first skeleton is raised faster than later re-summons.
##
## Upstream Necromancer.java charges up a summon with `spend(firstSummon ? TICK :
## 2*TICK)` at the moment summoning begins, so the very first skeleton appears one
## tick sooner than every re-summon after it. The port tracked/serialized a
## `first_summon` flag but never read it, so both the first and later charge-ups
## cost the same single tick. This pins the charge-up timing to the source model.

class FakeLevel:
	extends RefCounted

	func is_passable(_p: int) -> bool:
		return true

	func find_char_at(_p: int) -> Object:
		return null

	func has_los(_a: int, _b: int) -> bool:
		return true


func _make_target(pos: int) -> Char:
	var target: Char = Char.new()
	target.pos = pos
	target.is_alive = true
	return target


## Register the necromancer, run one hunting act from a clean cooldown, and return
## the cooldown it charged for the summon charge-up.
func _charge_cost(necro: Node, level: FakeLevel, target: Char) -> float:
	necro.level = level
	necro.target = target
	necro.target_pos = target.pos
	necro.state = Mob.AIState.HUNTING
	necro.my_skeleton = null
	necro.summoning = false
	if TurnManager:
		TurnManager.remove_actor(necro)
		TurnManager.register_actor(necro, 0.0)
	necro._act_hunting()
	var cost: float = 0.0
	if TurnManager:
		cost = TurnManager.get_cooldown(necro)
	return cost


func run(t: Object) -> void:
	var script: Variant = load("res://src/actors/mobs/prison/necromancer.gd")
	t.check(script != null and script is GDScript, "necromancer.gd compiles")
	if script == null:
		return
	if TurnManager == null:
		t.check(false, "TurnManager autoload required for summon-timing test")
		return

	var level: FakeLevel = FakeLevel.new()
	# Interior cell so the DIRS_8 neighbours around the target are valid.
	var interior: int = ConstantsData.WIDTH * 6 + 6
	var target: Char = _make_target(interior)

	var necro: Node = script.new()
	necro.pos = interior + 5  # away from the target, still in-bounds

	# First summon: charge-up costs a single TICK.
	var first_cost: float = _charge_cost(necro, level, target)
	t.check(necro.summoning, "necromancer enters the summoning state on first act")
	t.check(is_equal_approx(first_cost, 1.0),
		"first summon charge-up costs 1 tick (got %f)" % first_cost)
	t.check(not necro.first_summon or necro.summoning,
		"first_summon flag stays set until the summon completes")

	# After the first skeleton has been raised, first_summon flips off. Simulate
	# that and confirm the next charge-up costs the slower 2*TICK.
	necro.first_summon = false
	var later_cost: float = _charge_cost(necro, level, target)
	t.check(is_equal_approx(later_cost, 2.0),
		"re-summon charge-up costs 2 ticks (got %f)" % later_cost)

	# The slower re-summon must be strictly costlier than the first.
	t.check(later_cost > first_cost,
		"re-summon is slower than the first summon (%f > %f)" % [later_cost, first_cost])

	if TurnManager:
		TurnManager.remove_actor(necro)
	necro.free()
	target.free()
