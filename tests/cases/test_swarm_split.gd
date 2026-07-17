extends RefCounted
## Swarm split should divide current HP between the two swarms, never duplicate it.
##
## SPD's Swarm.split() hands half the current HP to the clone and subtracts it from
## the parent, so total swarm HP is conserved. A regression duplicated the parent's
## HP onto the child and left the parent untouched, doubling effective enemy HP (and
## over-granting XP) every time a swarm split.

class FakeLevel:
	extends RefCounted

	var added: Array = []

	func is_passable(_p: int) -> bool:
		return true

	func find_char_at(_p: int) -> Object:
		return null

	func add_mob(mob: Object) -> void:
		added.append(mob)

func run(t: Object) -> void:
	var script: Variant = load("res://src/actors/mobs/sewer/swarm.gd")
	t.check(script != null and script is GDScript, "swarm.gd compiles")
	if script == null:
		return

	var level: FakeLevel = FakeLevel.new()

	# Interior cell so pos + 1 is a valid adjacent split target.
	var interior: int = ConstantsData.WIDTH * 5 + 5

	var swarm: Node = script.new()
	swarm.level = level
	swarm.pos = interior
	swarm.hp_max = 12
	swarm.ht = 12
	swarm.hp = 6  # already at the half-HP split threshold

	swarm._split()

	t.check(level.added.size() == 1, "swarm spawns exactly one child on split")
	if level.added.size() != 1:
		swarm.free()
		return

	var child: Node = level.added[0]
	t.check(swarm.has_split, "parent is flagged so it cannot split again")
	t.check(child.has_split, "child is flagged so it cannot split again")

	# HP is divided, not duplicated: child gets floor(6/2)=3, parent keeps 6-3=3.
	t.check(child.hp == 3, "child receives half the current HP (got %d)" % child.hp)
	t.check(swarm.hp == 3, "parent keeps the remaining half (got %d)" % swarm.hp)
	t.check(child.hp + swarm.hp == 6, "total swarm HP is conserved across the split")
	t.check(child.hp != 6, "child HP is not a full duplicate of the parent")

	# Child's max HP mirrors the parent's scaled cap, not its raw current HP.
	t.check(child.hp_max == 12, "child hp_max mirrors the parent cap (got %d)" % child.hp_max)
	t.check(child.ht == 12, "child ht mirrors the parent cap (got %d)" % child.ht)

	if TurnManager and TurnManager.has_method("remove_actor"):
		TurnManager.remove_actor(child)
		TurnManager.remove_actor(swarm)
	child.free()
	swarm.free()
