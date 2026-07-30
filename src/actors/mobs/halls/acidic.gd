class_name Acidic
extends Scorpio
## Acidic scorpio: rare 1-in-50 alt of the scorpio (upstream Acidic.java,
## swapped in via MobSpawner.RARE_ALTS). Its spikes coat victims in caustic
## ooze, melee attackers get splashed with ooze in return, and it always
## drops a potion of experience.

func _init() -> void:
	super._init()
	mob_id = "acidic"
	mob_name = "Acidic Scorpio"
	description = "These huge arachnid-like demonic creatures avoid close combat by all means, firing crippling serrated spikes from long distances.\n\nThis scorpio's spikes and carapace drip with acrid ooze: its attacks coat victims in caustic ooze, and attacking it in melee splashes the attacker as well."
	_properties.append("ACIDIC")

## Upstream attackProc: Ooze.set(Ooze.DURATION) on every hit, then super
## (which keeps the 1/2 cripple).
func attack_proc(enemy: Char, damage: int) -> int:
	if enemy != null:
		apply_ooze(enemy)
	return super.attack_proc(enemy, damage)

## Upstream defenseProc: adjacent attackers get splashed with ooze.
func defense_proc(enemy: Char, damage: int) -> int:
	if enemy != null and is_adjacent(enemy.pos):
		apply_ooze(enemy)
	return super.defense_proc(enemy, damage)

## Split out so tests can exercise the ooze application deterministically.
func apply_ooze(enemy: Char) -> void:
	var ooze: Ooze = Ooze.new()
	ooze.set_duration_value(Ooze.DURATION)
	enemy.add_buff(ooze)

## Upstream: loot = PotionOfExperience, lootChance = 1f.
func _drop_loot(killer: Variant = null) -> void:
	if level == null or not level.has_method("drop_item"):
		return
	if randf() >= _loot_chance_multiplier(killer):
		return
	var item: Item = create_loot()
	if item != null:
		level.drop_item(pos, item)

func create_loot() -> Item:
	return Generator.create_item("experience") if Generator else null
