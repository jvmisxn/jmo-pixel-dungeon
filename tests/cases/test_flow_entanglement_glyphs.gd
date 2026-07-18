extends RefCounted
## FlowGlyph and EntanglementGlyph previously attached inert base Buff.new()
## instances tagged only with a buff_id string. Those had no behavior: the fake
## "Haste" did not modify speed and the fake "Rooted" was a NEUTRAL buff with no
## proper debuff typing. The glyphs must now attach the real Haste / Rooted buff
## classes so the effects are behaviorally meaningful and findable by class.

## Records every buff handed to add_buff so the test can inspect the real type.
class DummyChar:
	extends Node

	var pos: int = 100
	var level: Node = null
	var added: Array[Node] = []
	var shielding: int = 0

	func add_buff(buff: Node) -> Node:
		added.append(buff)
		return buff

	func add_shielding(amount: int) -> void:
		shielding += amount

## Fake level whose terrain lookup is fully controllable per test.
class DummyLevel:
	extends Node

	var terrain: int = 0

	func get_terrain(_pos: int) -> int:
		return terrain

## Minimal stand-in for the Armor the glyph reads .level from.
class DummyArmor:
	extends RefCounted
	var level: int = 0

func run(t: Object) -> void:
	_check_flow_grants_real_haste(t)
	_check_entanglement_grants_real_rooted(t)

## Proc chance is 1/(level+3); loop with a fixed seed until it fires so the
## assertions run deterministically without depending on a single roll.
func _proc_until_buff(glyph: ArmorGlyph, armor: DummyArmor, defender: DummyChar) -> bool:
	seed(0xF10)
	for _i: int in range(500):
		glyph.proc(armor, null, defender, 5)
		if not defender.added.is_empty():
			return true
	return false

func _check_flow_grants_real_haste(t: Object) -> void:
	var lvl := DummyLevel.new()
	lvl.terrain = ConstantsData.Terrain.WATER
	var defender := DummyChar.new()
	defender.level = lvl
	var armor := DummyArmor.new()
	armor.level = 2
	var glyph: ArmorGlyph = ArmorGlyph.create("flow")

	var procced: bool = _proc_until_buff(glyph, armor, defender)
	t.check(procced, "Flow glyph procs while standing in water")

	var buff: Node = defender.added.back() if not defender.added.is_empty() else null
	t.check(buff is Haste, "Flow attaches a real Haste buff, not an inert Buff")
	t.check(buff != null and buff.buff_id == "Haste", "Flow buff carries the Haste id")
	# Behaviorally meaningful: real Haste triples speed; inert Buff would not.
	t.check(buff is Haste and (buff as Haste).modify_speed(1.0) == 3.0, \
		"Flow's Haste actually multiplies movement speed")
	t.check(buff != null and buff.get_time_left() == 2.0 + float(armor.level), \
		"Flow scales haste duration with armor level")

	for b: Node in defender.added:
		b.free()
	lvl.free()
	defender.free()

func _check_entanglement_grants_real_rooted(t: Object) -> void:
	var lvl := DummyLevel.new()
	lvl.terrain = ConstantsData.Terrain.GRASS
	var defender := DummyChar.new()
	defender.level = lvl
	var armor := DummyArmor.new()
	armor.level = 3
	var glyph: ArmorGlyph = ArmorGlyph.create("entanglement")

	var procced: bool = _proc_until_buff(glyph, armor, defender)
	t.check(procced, "Entanglement glyph procs on hit")

	# The first buff added by the proc is the root (shielding uses add_shielding).
	var root: Node = null
	for b: Node in defender.added:
		if b is Rooted:
			root = b
			break
	t.check(root != null, "Entanglement attaches a real Rooted buff, not an inert Buff")
	t.check(root != null and root.buff_id == "Rooted", "Entanglement buff carries the Rooted id")
	# Behaviorally meaningful: real Rooted is a movement-restricting debuff.
	t.check(root != null and (root as Rooted).is_debuff, \
		"Entanglement's Rooted is a movement-restricting debuff")
	t.check(root != null and root.get_time_left() == 2.0 + float(armor.level), \
		"Entanglement scales root duration with armor level")
	t.check(defender.shielding > 0, "Adjacent grass grants bonus shielding on proc")

	for b: Node in defender.added:
		b.free()
	lvl.free()
	defender.free()
