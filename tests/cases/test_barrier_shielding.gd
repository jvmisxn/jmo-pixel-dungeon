extends RefCounted

func run(t: Object) -> void:
	var ch: Char = Char.new()
	ch.hp = 20
	ch.hp_max = 20

	var barrier: Barrier = ch.add_buff(Barrier.new()) as Barrier
	barrier.set_shield(5)
	t.check(ch.shielding == 0, "Barrier does not mirror shield into flat shielding")
	t.check(ch.total_shielding() == 5, "Barrier contributes through get_shielding")

	var actual: int = ch.take_damage(3, "test")
	t.check(actual == 0, "Barrier absorbs incoming damage before HP")
	t.check(ch.hp == 20, "Barrier absorption preserves HP")
	t.check(ch.total_shielding() == 2, "Barrier loses only absorbed amount")
	t.check(ch.has_buff("Barrier"), "Partially depleted Barrier stays attached")

	actual = ch.take_damage(4, "test")
	t.check(actual == 2, "Damage overflow passes through depleted Barrier")
	t.check(ch.hp == 18, "Overflow damage reduces HP once")
	t.check(ch.total_shielding() == 0, "Depleted Barrier is no longer counted")
	t.check(not ch.has_buff("Barrier"), "Depleted Barrier detaches")

	ch.add_shielding(3)
	t.check(ch.total_shielding() == 3, "Flat shielding still contributes")
	actual = ch.take_damage(5, "test")
	t.check(actual == 2, "Flat shielding still absorbs after shield buffs")
	t.check(ch.hp == 16, "Flat shield overflow applies once")

	ch.free()
