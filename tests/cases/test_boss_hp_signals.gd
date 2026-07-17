extends RefCounted

func run(t: Object) -> void:
	var started: Array[Dictionary] = []
	var damaged: Array[Dictionary] = []
	var defeated: Array[bool] = []
	var on_started := func(boss_name: String, boss_hp: int) -> void:
		started.append({"name": boss_name, "hp": boss_hp})
	var on_damaged := func(current_hp: int, max_hp: int) -> void:
		damaged.append({"hp": current_hp, "max": max_hp})
	var on_defeated := func() -> void:
		defeated.append(true)

	EventBus.boss_fight_started.connect(on_started)
	EventBus.boss_damaged.connect(on_damaged)
	EventBus.boss_defeated.connect(on_defeated)

	var rat := Mob.new()
	rat.mob_id = "rat"
	rat.mob_name = "Rat"
	rat.setup(8, 8, 2, 1, 4, 0)
	rat.take_damage(1, null)
	t.check(started.is_empty() and damaged.is_empty() and defeated.is_empty(),
		"non-boss mob damage does not emit boss HP signals")
	rat.free()

	var boss := Tengu.new()
	t.check(boss.is_boss(), "known boss ids are recognized as boss mobs")
	boss.take_damage(10, null)
	t.check(started.size() == 1, "boss damage starts the boss HP bar once")
	t.check(started[0]["name"] == "Tengu", "boss HP start signal includes boss name")
	t.check(started[0]["hp"] == 160, "boss HP start signal includes initial HP")
	t.check(damaged.size() == 1, "non-fatal boss damage updates the boss HP bar")
	t.check(damaged[0]["hp"] == 150 and damaged[0]["max"] == 160,
		"boss HP damage signal includes current and max HP")

	boss.take_damage(999, null)
	t.check(defeated.size() == 1, "fatal boss damage emits boss defeated")
	t.check(damaged.size() == 1, "fatal boss damage does not re-show the bar after defeat")

	EventBus.boss_fight_started.disconnect(on_started)
	EventBus.boss_damaged.disconnect(on_damaged)
	EventBus.boss_defeated.disconnect(on_defeated)
