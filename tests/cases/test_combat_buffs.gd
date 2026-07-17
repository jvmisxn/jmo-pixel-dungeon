extends RefCounted
## Focused combat-buff contracts for high-risk status effects.

func run(t: Object) -> void:
	_test_doom_damage_contract(t)

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
