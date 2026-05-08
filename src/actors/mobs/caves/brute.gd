class_name Brute
extends Mob
## Gnoll Brute — enrages at the moment of death, gaining shielding instead of dying.
## Original: BruteRage triggers in isAlive() when HP reaches 0, granting HT/2 + 4
## shielding. While enraged, deals increased damage. Shield decays ~4/turn.

var has_raged: bool = false

func _init() -> void:
	super._init()
	mob_id = "brute"
	mob_name = "Gnoll Brute"
	description = "A massive gnoll warrior that refuses to die, entering a berserker rage at the moment of death."
	setup(40, 20, 15, 5, 25, 8)
	xp_value = 8
	max_level = 16
	awareness = 0.4
	aggro_range = 8
	loot_table = [{"item_id": "gold", "chance": 0.5}]

## Override damage_roll to deal more damage when enraged.
## Original: NormalIntRange(5, 25) normal, NormalIntRange(15, 40) enraged.
func damage_roll() -> int:
	if has_buff("BruteRage"):
		# Triangular distribution approximating NormalIntRange(15, 40)
		var roll_a: int = randi_range(15, 40)
		var roll_b: int = randi_range(15, 40)
		return (roll_a + roll_b) / 2
	else:
		var roll_a: int = randi_range(5, 25)
		var roll_b: int = randi_range(5, 25)
		return (roll_a + roll_b) / 2

## DR roll: super + NormalIntRange(0, 8).
func dr_roll() -> int:
	var base_dr: int = super.dr_roll()
	var bonus_a: int = randi_range(0, 8)
	var bonus_b: int = randi_range(0, 8)
	return base_dr + (bonus_a + bonus_b) / 2

## Death prevention — this is the Brute's signature mechanic.
## When the Brute would die, it instead gains HT/2 + 4 shielding and enters rage.
## The shielding decays over time; when it hits 0, the Brute actually dies.
func _try_prevent_death(_source: Variant) -> bool:
	if has_raged:
		return false
	has_raged = true
	# Grant rage shielding
	@warning_ignore("integer_division")
	var shield_amount: int = ht / 2 + 4
	hp = 1  # Keep alive with 1 HP
	add_shielding(shield_amount)
	# Add BruteRage buff (handles shield decay)
	var rage_buff: Buff = Buff.new()
	rage_buff.buff_id = "BruteRage"
	rage_buff.buff_name = "Berserker Rage"
	rage_buff.buff_type = Buff.BuffType.NEGATIVE
	rage_buff.duration = -1.0
	add_buff(rage_buff)
	if MessageLog:
		MessageLog.add_negative("The brute refuses to die!")
	return true

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["has_raged"] = has_raged
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	has_raged = data.get("has_raged", false)
