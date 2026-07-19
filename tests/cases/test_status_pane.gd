extends RefCounted

class FakeHero:
	extends Node

	var hp: int = 20
	var hp_max: int = 20
	var is_alive: bool = true
	var shielding: int = 0
	var xp: int = 0
	var xp_to_next: int = 10
	var hero_level: int = 1
	var str_val: int = 10
	var hero_class: int = ConstantsData.HeroClass.WARRIOR
	var buffs: Array[Node] = []
	var belongings: RefCounted = null

	func get_buffs() -> Array[Node]:
		return buffs

	func get_buff(_buff_id: String) -> Variant:
		return null

class FakeBelongings:
	extends RefCounted

	var weapon: Variant = null
	var spirit_bow: Variant = null
	var armor: Variant = null
	var artifact: Variant = null
	var ring_left: Variant = null
	var ring_right: Variant = null
	var misc: Variant = null

class TestStatusPane:
	extends StatusPane

	var fake_hero: Variant = null

	func _get_hero() -> Variant:
		return fake_hero

func run(t: Object) -> void:
	var script: Variant = load("res://src/ui/status_pane.gd")
	t.check(script != null and script is GDScript, "status_pane.gd loads as a script")

	var pane: TestStatusPane = TestStatusPane.new()
	t.root.add_child(pane)
	pane._ready()
	t.check(pane.get_parent() == t.root, "StatusPane can be added to the scene tree")

	pane.set_compact_mode(true)
	t.check(bool(pane.get("_compact_mode")), "StatusPane compact mode is applied")

	pane.update_all()
	t.check(pane.get_parent() == t.root, "StatusPane update path remains alive after compact layout")

	var hero := FakeHero.new()
	hero.belongings = FakeBelongings.new()
	var buff := Buff.new()
	buff.buff_id = "TestBuff"
	buff.buff_name = "Testing"
	buff.time_left = 2.0
	buff.icon_color = Color(0.25, 0.5, 0.75)
	hero.buffs.append(buff)
	pane.fake_hero = hero
	pane.set_compact_mode(false)
	pane.update_all()
	var buffs_container: HFlowContainer = pane.get_node_or_null("BuffsContainer") as HFlowContainer
	var icon: BuffIcon = null
	if buffs_container != null:
		for child: Node in buffs_container.get_children():
			var candidate: BuffIcon = child as BuffIcon
			if candidate != null and candidate.buff_ref == buff:
				icon = candidate
				break
	t.check(
		icon != null,
		"StatusPane renders active buffs with BuffIcon components"
	)
	t.check(
		icon != null
				and icon.tooltip_text == "Testing (2 turns)",
		"StatusPane buff icons keep the buff reference and duration tooltip"
	)
	buff.free()
	hero.free()

	pane.free()
