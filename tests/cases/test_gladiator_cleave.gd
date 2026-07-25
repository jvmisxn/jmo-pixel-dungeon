extends RefCounted
## Gladiator Cleave talent (upstream Talent.CLEAVE): a combo hit that kills an
## enemy greatly extends the combo's duration. Upstream Combo.hit() sets
## comboTime to 15 + 15*points versus a base of 5; the port's combo window is
## 1 turn normally, 3 turns after a kill, and 3 + 3*points with Cleave.

func run(t: Object) -> void:
	_test_normal_hit_keeps_base_window(t)
	_test_kill_extends_window_without_talent(t)
	_test_cleave_scales_kill_window(t)
	_test_kill_window_survives_idle_turns(t)
	_test_normal_hit_does_not_refresh_kill_window(t)
	_test_window_resets_after_combo_drop(t)
	_test_serialize_round_trip_keeps_window(t)

func _make_gladiator() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var combo := GladiatorCombo.new()
	hero.add_buff(combo)
	return hero

func _combo(hero: Hero) -> GladiatorCombo:
	return hero.get_buff("GladiatorCombo") as GladiatorCombo

func _make_victim(alive: bool) -> Char:
	var victim := Char.new()
	victim.is_alive = alive
	return victim

func _test_normal_hit_keeps_base_window(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	var victim := _make_victim(true)
	combo.on_damage_dealt(5, victim)
	t.check(combo.combo_window == GladiatorCombo.BASE_WINDOW, "Non-killing hit keeps the 1-turn combo window")
	t.check(combo.combo_count == 1, "Hit builds combo count")
	victim.free()
	hero.free()

func _test_kill_extends_window_without_talent(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	var victim := _make_victim(false)
	combo.on_damage_dealt(5, victim)
	t.check(combo.combo_window == 3, "Killing hit extends the combo window to 3 turns without Cleave")
	victim.free()
	hero.free()

func _test_cleave_scales_kill_window(t: Object) -> void:
	var hero := _make_gladiator()
	hero.talent_levels["gladiator_cleave"] = 3
	var combo := _combo(hero)
	var victim := _make_victim(false)
	combo.on_damage_dealt(5, victim)
	t.check(combo.combo_window == 12, "Cleave +3 extends the kill window to 12 turns")
	hero.talent_levels["gladiator_cleave"] = 1
	combo.on_damage_dealt(5, victim)
	t.check(combo.combo_window == 6, "Cleave +1 extends the kill window to 6 turns")
	victim.free()
	hero.free()

func _test_kill_window_survives_idle_turns(t: Object) -> void:
	var hero := _make_gladiator()
	hero.talent_levels["gladiator_cleave"] = 1
	var combo := _combo(hero)
	var victim := _make_victim(false)
	combo.on_damage_dealt(5, victim)
	for _i in range(6):
		combo.on_turn()
	t.check(combo.combo_count == 1, "Combo survives 6 idle turns inside a Cleave +1 kill window")
	combo.on_turn()
	t.check(combo.combo_count == 0, "Combo drops on the turn after the kill window expires")
	victim.free()
	hero.free()

func _test_normal_hit_does_not_refresh_kill_window(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	var dead := _make_victim(false)
	var alive := _make_victim(true)
	combo.on_damage_dealt(5, dead)
	combo.on_turn()
	combo.on_turn()
	combo.on_damage_dealt(5, alive)
	t.check(combo.combo_window == GladiatorCombo.BASE_WINDOW, "Kill window keeps ticking down through a normal hit instead of refreshing")
	dead.free()
	alive.free()
	hero.free()

func _test_window_resets_after_combo_drop(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	var victim := _make_victim(false)
	combo.on_damage_dealt(5, victim)
	for _i in range(4):
		combo.on_turn()
	t.check(combo.combo_count == 0, "Combo drops after the 3-turn kill window expires")
	t.check(combo.combo_window == GladiatorCombo.BASE_WINDOW, "Window returns to 1 turn once the combo drops")
	victim.free()
	hero.free()

func _test_serialize_round_trip_keeps_window(t: Object) -> void:
	var hero := _make_gladiator()
	hero.talent_levels["gladiator_cleave"] = 2
	var combo := _combo(hero)
	var victim := _make_victim(false)
	combo.on_damage_dealt(5, victim)
	var data: Dictionary = combo.serialize()
	var restored := GladiatorCombo.new()
	restored.deserialize(data)
	t.check(restored.combo_window == 9, "Serialize round trip preserves the extended combo window")
	t.check(restored.combo_count == 1, "Serialize round trip preserves combo count")
	restored.free()
	victim.free()
	hero.free()
