extends RefCounted
## Rogue Protective Shadows talent: while invisible the hero gradually gains a
## Barrier (upstream Talent.ProtectiveShadowsTracker), and Barrier decay now
## matches upstream's fractional min(1, shielding/20) per-turn loss.

func run(t: Object) -> void:
	_test_tracker_builds_barrier(t)
	_test_tracker_detaches_when_visible(t)
	_test_barrier_partial_decay(t)
	_test_tracker_persists(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	hero.hp_max = 30
	hero.ht = 30
	hero.hp = 30
	hero.talent_levels["rogue_protective_shadows"] = points
	return hero

func _test_tracker_builds_barrier(t: Object) -> void:
	var hero := _make_rogue(2)
	hero.add_buff(Invisibility.new())
	t.check(hero.has_buff("ProtectiveShadowsTracker"),
		"Invisibility attaches Protective Shadows tracker for talented rogue")

	for _i: int in range(6):
		hero.process_buffs(1.0)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null, "Tracker builds a Barrier while invisible")
	t.check(barrier != null and barrier.get_shielding() >= 3,
		"Two-point tracker gains roughly 1 shield per turn")
	for _i: int in range(10):
		hero.process_buffs(1.0)
	barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() <= 5,
		"Two-point tracker caps barrier at 5 shielding")
	hero.free()

func _test_tracker_detaches_when_visible(t: Object) -> void:
	var hero := _make_rogue(1)
	hero.add_buff(Invisibility.new())
	hero.remove_buff_by_id("Invisibility")
	hero.process_buffs(1.0)
	t.check(not hero.has_buff("ProtectiveShadowsTracker"),
		"Tracker detaches once the hero is no longer invisible")

	var untalented := _make_rogue(0)
	untalented.add_buff(Invisibility.new())
	t.check(not untalented.has_buff("ProtectiveShadowsTracker"),
		"Invisibility does not attach tracker without the talent")
	hero.free()
	untalented.free()

func _test_barrier_partial_decay(t: Object) -> void:
	var ch := Char.new()
	ch.hp = 20
	ch.hp_max = 20
	var barrier: Barrier = ch.add_buff(Barrier.new()) as Barrier
	barrier.set_shield(4)
	ch.process_buffs(1.0)
	t.check(barrier.get_shielding() == 4,
		"Small barrier no longer loses 1 shield every turn")
	for _i: int in range(4):
		ch.process_buffs(1.0)
	t.check(barrier.get_shielding() == 3,
		"4-shield barrier decays by 1 after five turns (4/20 per turn)")
	# 3 turns accrue 0.45 partial decay; resetting then running 4 more turns
	# (0.6) stays under 1.0, while without the reset it would cross 1.05.
	for _i: int in range(3):
		ch.process_buffs(1.0)
	barrier.inc_shield(0)
	for _i: int in range(4):
		ch.process_buffs(1.0)
	t.check(barrier.get_shielding() == 3,
		"inc_shield resets partial decay progress")
	ch.free()

func _test_tracker_persists(t: Object) -> void:
	var hero := _make_rogue(2)
	hero.add_buff(Invisibility.new())
	hero.process_buffs(1.0)
	var data: Dictionary = hero.serialize()

	var restored := Hero.new()
	restored.init_class(ConstantsData.HeroClass.ROGUE)
	restored.deserialize(data)
	t.check(restored.has_buff("ProtectiveShadowsTracker"),
		"Tracker survives serialize/deserialize")
	t.check(restored.has_buff("Invisibility"), "Invisibility survives save/load")
	hero.free()
	restored.free()
