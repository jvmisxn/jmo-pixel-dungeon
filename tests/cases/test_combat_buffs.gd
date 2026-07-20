extends RefCounted
## Focused combat-buff contracts for high-risk status effects.

func run(t: Object) -> void:
	_test_doom_damage_contract(t)
	_test_weakness_damage_contract(t)

func _test_weakness_damage_contract(t: Object) -> void:
	var attacker: Char = Char.new()
	attacker.attack_skill = 1000000
	attacker.damage_roll_min = 10
	attacker.damage_roll_max = 10
	attacker.add_buff(Weakness.new())

	var weakness: Weakness = attacker.get_buff("Weakness") as Weakness
	t.check(weakness != null, "Weakness attaches as a debuff")
	t.check(weakness.duration == 20.0, "Weakness uses SPD's 20-turn duration")
	t.check(weakness.time_left == 20.0, "Weakness starts with full duration")

	var defender: Char = Char.new()
	defender.hp = 100
	defender.hp_max = 100
	defender.ht = 100
	defender.defense_skill = 0
	defender.armor_value = 0

	t.check(attacker.attack(defender), "weakness attack lands with deterministic accuracy")
	t.check(defender.hp == 93, "Weakness reduces outgoing damage to 67%")

	attacker.free()
	defender.free()

func _test_doom_damage_contract(t: Object) -> void:
	var doomed: Char = Char.new()
	doomed.name = "Doom target"
	doomed.hp = 100
	doomed.hp_max = 100
	doomed.ht = 100

	var doom: Doom = Doom.new()
	doomed.add_buff(doom)

	t.check(doomed.has_buff("Doom"), "Doom attaches as a permanent debuff")
	t.check(doomed.take_damage(10, "test") == 17, "Doom amplifies incoming damage by 67%")
	t.check(doomed.hp == 83, "Doom damage is applied after amplification")

	for _i: int in range(35):
		doomed.process_buffs()

	t.check(doomed.is_alive, "Doom does not kill on a countdown")
	t.check(doomed.has_buff("Doom"), "Doom persists until explicit curse removal")

	doomed.free()
