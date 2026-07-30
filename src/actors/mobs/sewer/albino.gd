class_name Albino
extends Rat
## Albino rat: rare 1-in-50 alt of the marsupial rat (upstream Albino.java,
## swapped in via MobSpawner.RARE_ALTS). Tougher, bleeds on hit, always
## drops mystery meat.

func _init() -> void:
	super._init()
	mob_id = "albino"
	mob_name = "Albino Rat"
	description = "This is a rare breed of marsupial rat, with pure white fur and jagged teeth."
	# Upstream: HP = HT = 12, EXP = 2; attack stats inherited from Rat.
	setup(12, 8, 2, 1, 4, 0)
	xp_value = 2
	loot_table = [{"item_id": "mystery_meat", "chance": 1.0}]


func attack_proc(enemy: Char, damage: int) -> int:
	var result: int = super.attack_proc(enemy, damage)
	# Upstream: if damage > 0 and Random.Int(2) == 0, Bleeding.set(NormalFloat(2, 3)).
	if enemy != null and result > 0 and randi_range(0, 1) == 0:
		apply_bleed(enemy)
	return result


## Split out so tests can exercise the bleed application deterministically.
func apply_bleed(enemy: Char) -> void:
	var bleeding: Bleeding = enemy.get_buff("Bleeding") as Bleeding
	if bleeding == null:
		bleeding = Bleeding.new()
		enemy.add_buff(bleeding)
	# Random.NormalFloat(2, 3): average of two uniform rolls in [2, 3].
	bleeding.set_level((randf_range(2.0, 3.0) + randf_range(2.0, 3.0)) / 2.0)
