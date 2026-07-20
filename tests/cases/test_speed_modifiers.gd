extends RefCounted

class SpeedActor:
	extends Node

	var speed: float = 1.0

	func get_speed() -> float:
		return speed

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

	var monk: Char = Char.new()
	monk.base_speed = 1.0
	var flurry: MonkFlurry = MonkFlurry.new()
	flurry.consecutive_hits = MonkFlurry.MAX_CONSECUTIVE
	monk.add_buff(flurry)
	t.check(is_equal_approx(monk.get_speed(), 1.0), "Monk Flurry does not change movement speed")

	var haste_hero: Hero = Hero.new()
	haste_hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var haste_ring: Ring = Ring.create("ring_of_haste")
	haste_ring.level = 1
	haste_hero.belongings.equip_ring(haste_ring)
	t.check(
		is_equal_approx(haste_hero.get_speed(), 1.175),
		"Ring of Haste uses SPD's 17.5% movement speed multiplier"
	)
	t.check(
		is_equal_approx(haste_hero._get_attack_delay() / haste_hero.get_speed(), 1.0),
		"Ring of Haste does not speed up melee attacks"
	)
	t.check(
		is_equal_approx(haste_hero._get_non_movement_action_delay() / haste_hero.get_speed(), 1.0),
		"Ring of Haste does not speed up non-movement actions"
	)

	var furor_hero: Hero = Hero.new()
	furor_hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var furor_ring: Ring = Ring.create("ring_of_furor")
	furor_ring.level = 1
	furor_hero.belongings.equip_ring(furor_ring)
	t.check(
		is_equal_approx(furor_hero.get_speed(), 1.0),
		"Ring of Furor does not change movement speed"
	)
	t.check(
		is_equal_approx(furor_hero._get_attack_delay() / furor_hero.get_speed(), 1.0 / 1.09051),
		"Ring of Furor uses SPD's 9.051% attack speed multiplier"
	)
	t.check(
		is_equal_approx(furor_hero._get_non_movement_action_delay() / furor_hero.get_speed(), 1.0),
		"Ring of Furor does not speed up non-attack actions"
	)

	var split_hero: Hero = Hero.new()
	split_hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var split_haste: Ring = Ring.create("ring_of_haste")
	var split_furor: Ring = Ring.create("ring_of_furor")
	split_haste.level = 1
	split_furor.level = 1
	split_hero.belongings.equip_ring(split_haste, true)
	split_hero.belongings.equip_ring(split_furor, false)
	var split_scheduler := TurnManagerNode.new()
	split_scheduler.register_actor(split_hero)
	split_scheduler.spend_energy(split_hero, 1.0)
	t.check(
		is_equal_approx(split_scheduler.get_cooldown(split_hero), 1.0 / 1.175),
		"Ring of Haste speeds movement turns through get_speed"
	)
	split_scheduler.spend_energy(split_hero, split_hero._get_attack_delay())
	t.check(
		is_equal_approx(split_scheduler.get_cooldown(split_hero), (1.0 / 1.175) + (1.0 / 1.09051)),
		"Ring of Furor speeds attack turns without also applying Haste"
	)

	var scheduler := TurnManagerNode.new()
	var actor := SpeedActor.new()
	scheduler.register_actor(actor)
	actor.speed = 2.0
	scheduler.spend_energy(actor)
	t.check(
		is_equal_approx(scheduler.get_cooldown(actor), 0.5),
		"TurnManager spends energy against live actor speed, not the registration cache"
	)
	actor.speed = 0.5
	scheduler.spend_energy(actor)
	t.check(
		is_equal_approx(scheduler.get_cooldown(actor), 2.5),
		"TurnManager applies later speed changes without a manual refresh"
	)

	ch.free()
	dread_target.free()
	sleeping.free()
	runner.free()
	monk.free()
	haste_hero.free()
	furor_hero.free()
	split_hero.free()
	split_scheduler.free()
	actor.free()
	scheduler.free()
