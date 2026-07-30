class_name ArmoredBrute
extends Brute
## Armored brute: rare 1-in-50 alt of the gnoll brute (upstream
## ArmoredBrute.java, swapped in via MobSpawner.RARE_ALTS). Wears scavenged
## armor: +4 flat DR on top of the brute's roll (4-12 total upstream), a
## smaller rage shield (HT/2 + 1 vs HT/2 + 4 — upstream's ArmoredRage decays
## far slower instead), and always drops armor: 1/4 plate, else scale.

func _init() -> void:
	super._init()
	mob_id = "armored_brute"
	mob_name = "Armored Brute"
	description = "The most senior gnoll brutes often wear powerful armor to show their status. The armor makes these brutes much more resilient to physical damage, and their greater discipline means they can rage for much longer before succumbing to their wounds."
	# Guaranteed armor drop handled by _drop_loot/create_loot below.
	loot_table = []


## Upstream: super.drRoll() + 4 (4-12 DR total).
func dr_roll() -> int:
	return super.dr_roll() + 4


## Upstream ArmoredRage: setShield(HT/2 + 1).
func _rage_shield() -> int:
	@warning_ignore("integer_division")
	return ht / 2 + 1


## Upstream: loot = ARMOR, lootChance = 1f -> createLoot().
func _drop_loot(killer: Variant = null) -> void:
	if level == null or not level.has_method("drop_item"):
		return
	if randf() >= _loot_chance_multiplier(killer):
		return
	var armor: Item = create_loot()
	if armor != null:
		level.drop_item(pos, armor)


## Upstream createLoot: Random.Int(4) == 0 -> PlateArmor, else ScaleArmor,
## both .random() (random upgrade level / curse).
func create_loot() -> Item:
	var item_id: String = "plate_armor" if randi_range(0, 3) == 0 else "scale_armor"
	var armor: Item = Generator.create_item(item_id) if Generator else null
	if armor is Armor and armor.has_method("random"):
		armor.random()
	return armor
