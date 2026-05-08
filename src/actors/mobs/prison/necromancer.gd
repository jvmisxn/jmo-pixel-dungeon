class_name Necromancer
extends Mob
## Dark mage that raises and maintains a linked skeleton.
## Original: Necromancer.java — summons ONE linked skeleton near the enemy,
## heals it (HT/5 per turn) or gives it Adrenaline, re-teleports it if stuck,
## and when the necromancer dies, its linked skeleton dies too.
## The necromancer CANNOT directly attack — it only acts through its skeleton.

## The necromancer's linked skeleton. Only one at a time.
var my_skeleton: Mob = null
## Whether currently in the process of summoning.
var summoning: bool = false
## Position where the skeleton will be summoned.
var summoning_pos: int = -1
## First summon is faster (1 turn instead of 2).
var first_summon: bool = true
## Cooldown between healing/buffing zaps to the skeleton.
var zap_cooldown: int = 0

func _init() -> void:
	super._init()
	mob_id = "necromancer"
	mob_name = "Necromancer"
	description = "A dark mage that raises the dead to fight for it. Kill the necromancer to destroy its skeleton."
	# Original: HP=HT=40, attackSkill (irrelevant, can't attack), defenseSkill=14, DR 0-5
	setup(40, 0, 14, 0, 0, 5)
	xp_value = 7
	max_level = 14
	awareness = 0.4
	aggro_range = 10
	loot_table = [{"item_id": "potion_healing", "chance": 0.2}]
	_properties = ["UNDEAD"]

## Necromancer cannot directly attack.
func attack(_target_char: Char, _dmg_multi: float = 1.0, _dmg_bonus: float = 0.0, _acc_multi: float = 1.0) -> bool:
	return false

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	summoning = data.get("summoning", false)
	summoning_pos = data.get("summoning_pos", -1)
	first_summon = data.get("first_summon", true)
	zap_cooldown = data.get("zap_cooldown", 0)
