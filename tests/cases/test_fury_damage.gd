extends RefCounted

func run(t: Object) -> void:
	var attacker: Char = Char.new()
	attacker.attack_skill = 1000000
	attacker.damage_roll_min = 10
	attacker.damage_roll_max = 10
	attacker.hp = 4
	attacker.hp_max = 10
	attacker.ht = 10
	attacker.add_buff(Fury.new())

	var defender: Char = Char.new()
	defender.hp = 100
	defender.hp_max = 100
	defender.ht = 100
	defender.defense_skill = 0
	defender.armor_value = 0

	t.check(attacker.attack(defender), "fury attack lands with deterministic accuracy")
	t.check(defender.hp == 85, "fury damage is applied once through modify_damage")

	attacker.free()
	defender.free()
