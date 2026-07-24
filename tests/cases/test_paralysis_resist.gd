extends RefCounted
## Paralysis break parity: damage while paralyzed accumulates in a
## ParalysisResist buff (upstream Paralysis.processDamage), which decays 10%
## per turn once paralysis ends and persists through save/load.

func run(t: Object) -> void:
	_test_damage_accumulates(t)
	_test_huge_resist_breaks_paralysis(t)
	_test_resist_decays_after_paralysis(t)
	_test_no_decay_while_paralyzed(t)
	_test_resist_persists(t)

func _make_char(hp: int) -> Char:
	var ch := Char.new()
	ch.hp_max = hp
	ch.ht = hp
	ch.hp = hp
	return ch

func _test_damage_accumulates(t: Object) -> void:
	var ch := _make_char(1000000)
	ch.add_buff(Paralysis.new())
	var para: Paralysis = ch.get_buff("Paralysis") as Paralysis
	t.check(para != null, "Paralysis attaches")
	para.process_damage(5)
	para.process_damage(7)
	var resist: ParalysisResist = ch.get_buff("ParalysisResist") as ParalysisResist
	t.check(resist != null, "process_damage attaches ParalysisResist")
	t.check(resist != null and resist.damage == 12,
		"Resist accumulates damage across hits (got %s)" % (resist.damage if resist else -1))
	t.check(ch.paralysed > 0, "Tiny hits vs huge HP leave paralysis in place")
	ch.free()

func _test_huge_resist_breaks_paralysis(t: Object) -> void:
	var ch := _make_char(10)
	ch.hp = 0
	ch.add_buff(Paralysis.new())
	var para: Paralysis = ch.get_buff("Paralysis") as Paralysis
	para.process_damage(100)
	t.check(not ch.has_buff("Paralysis"),
		"Accumulated damage vs zero HP always breaks paralysis")
	t.check(ch.paralysed == 0, "Broken paralysis clears the paralysed counter")
	t.check(ch.has_buff("ParalysisResist"),
		"Resist buff outlives the paralysis it broke")
	ch.free()

func _test_resist_decays_after_paralysis(t: Object) -> void:
	var ch := _make_char(20)
	var resist := ParalysisResist.new()
	resist.damage = 20
	ch.add_buff(resist)
	ch.process_buffs(1.0)
	t.check(resist.damage == 18,
		"Resist decays by ceil(10%%) per turn without paralysis (got %s)" % resist.damage)
	for _i: int in range(30):
		ch.process_buffs(1.0)
	t.check(not ch.has_buff("ParalysisResist"),
		"Resist detaches once fully decayed")
	ch.free()

func _test_no_decay_while_paralyzed(t: Object) -> void:
	var ch := _make_char(20)
	ch.add_buff(Paralysis.new())
	var resist := ParalysisResist.new()
	resist.damage = 10
	ch.add_buff(resist)
	ch.process_buffs(1.0)
	t.check(resist.damage == 10,
		"Resist does not decay while paralysis is still active (got %s)" % resist.damage)
	ch.free()

func _test_resist_persists(t: Object) -> void:
	var resist := ParalysisResist.new()
	resist.damage = 14
	var data: Dictionary = resist.serialize()
	var restored := ParalysisResist.new()
	restored.deserialize(data)
	t.check(restored.damage == 14, "Resist damage round-trips through serialize")
	resist.free()
	restored.free()
