extends RefCounted

func run(t: Object) -> void:
	_check_carried_wand_recharges(t)
	_check_recharging_buff_multiplier(t)
	_check_battlemage_multiplier(t)

func _check_carried_wand_recharges(t: Object) -> void:
	var hero := Hero.new()
	var wand := Wand.new()
	wand.charges_max = 2
	wand.charges = 1
	t.check(hero.belongings.add_item(wand), "test wand added to backpack")
	for _i: int in range(45):
		hero.belongings.recharge_wands(1)
	t.check(wand.charges == 2, "carried wands recharge over hero turns")

func _check_recharging_buff_multiplier(t: Object) -> void:
	var hero := Hero.new()
	var wand := Wand.new()
	wand.charges_max = 2
	wand.charges = 1
	var recharging := Recharging.new()
	recharging.duration = -1.0
	recharging.time_left = -1.0
	hero.add_buff(recharging)
	for _i: int in range(12):
		wand.recharge(1, hero)
	t.check(wand.charges == 2, "Recharging buff speeds wand recharge")

func _check_battlemage_multiplier(t: Object) -> void:
	var hero := Hero.new()
	var wand := Wand.new()
	wand.charges_max = 2
	wand.charges = 1
	hero.add_buff(BattemagePower.new())
	for _i: int in range(34):
		wand.recharge(1, hero)
	t.check(wand.charges == 2, "Battlemage passive speeds wand recharge")
