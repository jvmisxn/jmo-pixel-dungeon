class_name Skeleton
extends Mob
## Explodes on death dealing damage to adjacent characters.

func _init() -> void:
	super._init()
	mob_id = "skeleton"
	mob_name = "Skeleton"
	description = "An animated skeleton wielding a rusty weapon. Explodes violently on death."
	setup(25, 14, 7, 2, 10, 5)
	xp_value = 5
	max_level = 10  # Original: maxLvl = 10
	awareness = 0.3
	aggro_range = 8
	loot_table = [{"item_id": "gold", "chance": 0.3}, {"item_id": "weapon_t2", "chance": 0.1667}]
	_properties = ["UNDEAD", "INORGANIC"]  # Original has both properties

func _on_death(source: Variant) -> void:
	# Explode! Original: bone explosion applies DR twice (all DR sources 2x effective).
	# Damage is NormalIntRange(6,12) approximated with triangular distribution.
	if level:
		for dir: int in ConstantsData.DIRS_8:
			var adj_pos: int = pos + dir
			if level.has_method("find_char_at"):
				var adj_char: Variant = level.find_char_at(adj_pos)
				if adj_char != null:
					var dmg: int = randi_range(6, 12)
					adj_char.take_damage(dmg, "skeleton explosion")
		super._on_death(source)
