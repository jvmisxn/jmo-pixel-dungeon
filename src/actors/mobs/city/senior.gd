class_name SeniorMonk
extends MonkMob
## Senior monk: rare 1-in-50 alt of the dwarf monk (upstream Senior.java,
## swapped in via MobSpawner.RARE_ALTS). Hits harder (16-25) and builds
## focus twice as fast while moving (extra 1.66 cooldown reduction, 3.33
## total per step with the base 0.67 and the spent turn), and always drops
## a pasty.

func _init() -> void:
	super._init()
	mob_id = "senior"
	mob_name = "Senior Monk"
	description = "These monks are fanatics, who have devoted themselves to protecting their king through physical might. So great is their devotion that they have totally surrendered their minds to their king, and now roam the dwarven city like mindless zombies.\n\nThis monk has mastered the art of hand-to-hand combat, and is able to gain focus while moving much more quickly than regular monks. When they become focused, monks will parry the next physical attack used against them, even if it was otherwise guaranteed to hit. Monks build focus more quickly while on the move, and more slowly when in direct combat."
	# Upstream Senior.damageRoll: NormalIntRange(16, 25).
	damage_roll_min = 16
	# Upstream: loot = Pasty, lootChance = 1f.
	loot_table = [{"item_id": "pasty", "chance": 1.0}]

## Upstream Senior.move: an additional 1.66 cooldown reduction on top of
## the monk's 0.67.
func _travel_focus_bonus() -> float:
	return super._travel_focus_bonus() + 1.66
