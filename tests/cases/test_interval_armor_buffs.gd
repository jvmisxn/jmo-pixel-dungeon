extends RefCounted
## Barkskin and Arcane Armor should decay once per configured interval, not every
## actor turn. High-interval sources otherwise lose their protection too quickly.

class DummyTarget:
	extends Node

	var is_alive: bool = true
	var removed: Array[Node] = []

	func remove_buff(buff: Node) -> void:
		removed.append(buff)

func run(t: Object) -> void:
	_check_barkskin_interval(t)
	_check_arcane_armor_interval(t)

func _check_barkskin_interval(t: Object) -> void:
	var target := DummyTarget.new()
	var buff := Barkskin.new()
	buff.set_level(3, 3)
	buff.attach(target)

	buff.act()
	t.check(buff.level == 3, "Barkskin keeps level before interval completes")
	buff.act()
	t.check(buff.level == 3, "Barkskin still keeps level on interval-1 turn")
	buff.act()
	t.check(buff.level == 2, "Barkskin decays on the configured interval")
	buff.act()
	t.check(buff.level == 2, "Barkskin interval resets after decay")

	buff.free()
	target.free()

func _check_arcane_armor_interval(t: Object) -> void:
	var target := DummyTarget.new()
	var buff := ArcaneArmor.new()
	buff.set_level(2, 2)
	buff.attach(target)

	buff.act()
	t.check(buff.level == 2, "Arcane Armor keeps level before interval completes")
	buff.act()
	t.check(buff.level == 1, "Arcane Armor decays on the configured interval")
	buff.act()
	t.check(buff.level == 1, "Arcane Armor interval resets after decay")

	buff.free()
	target.free()
