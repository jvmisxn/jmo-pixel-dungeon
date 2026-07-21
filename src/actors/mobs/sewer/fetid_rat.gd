class_name FetidRat
extends Rat

func _init() -> void:
	super._init()
	mob_id = "fetid_rat"
	mob_name = "Fetid Rat"
	description = "A diseased sewer rat that leaks corrosive filth."
	setup(20, 12, 5, 1, 4, 1)
	xp_value = 4
	max_level = 7
	awareness = 0.3
	aggro_range = 6
	loot_table = [{"item_id": "mystery_meat", "chance": 0.2}]

func attack_proc(enemy: Char, damage: int) -> int:
	var result: int = super.attack_proc(enemy, damage)
	if enemy != null and randi_range(0, 2) == 0:
		var ooze: Ooze = enemy.get_buff("Ooze") as Ooze
		if ooze == null:
			ooze = Ooze.new()
			enemy.add_buff(ooze)
		ooze.set_duration_value(Ooze.DURATION)
	return result

func defense_proc(enemy: Char, damage: int) -> int:
	if level != null and level.has_method("add_blob"):
		level.add_blob(StenchGas.new(), pos, 20.0)
	return super.defense_proc(enemy, damage)

func dr_roll() -> int:
	return super.dr_roll() + int((randi_range(0, 2) + randi_range(0, 2)) / 2.0)

func _innate_immunities() -> Array[String]:
	return ["stench_gas"]

func _on_death(_source: Variant = null) -> void:
	var death_pos: int = pos
	var death_level: Variant = level
	super._on_death(_source)
	if death_level != null and death_level.has_method("add_blob"):
		var blob: ToxicGas = ToxicGas.new()
		death_level.add_blob(blob, death_pos, 6.0)
