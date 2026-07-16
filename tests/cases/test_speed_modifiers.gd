extends RefCounted

func run(t: Object) -> void:
	var ch: Char = Char.new()
	ch.base_speed = 1.0

	t.check(is_equal_approx(ch.get_speed(), 1.0), "base speed starts unchanged")

	ch.add_buff(Cripple.new())
	ch.add_buff(Stamina.new())
	ch.add_buff(Adrenaline.new())
	ch.add_buff(Haste.new())
	t.check(is_equal_approx(ch.get_speed(), 4.5), "legacy speed buffs still stack through hooks")

	var dread_target: Char = Char.new()
	dread_target.base_speed = 1.0
	dread_target.add_buff(Dread.new())
	t.check(is_equal_approx(dread_target.get_speed(), 2.0), "Dread speed hook is active")

	var sleeping: Char = Char.new()
	sleeping.base_speed = 1.0
	sleeping.add_buff(SleepBuff.new())
	t.check(is_equal_approx(sleeping.get_speed(), 0.0), "Sleep speed hook prevents acting")

	var runner: Char = Char.new()
	runner.base_speed = 1.0
	var momentum: FreerunnerMomentum = FreerunnerMomentum.new()
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	runner.add_buff(momentum)
	t.check(is_equal_approx(runner.get_speed(), 1.5), "Freerunner momentum speed hook is active")

	ch.free()
	dread_target.free()
	sleeping.free()
	runner.free()
