class_name DM201
extends Mob
## DM-201: Tougher variant of DM-200. Releases corrosive gas on death.
## Higher HP, more damage, and leaves a lingering hazard.

var gas_cooldown: int = 0
const GAS_INTERVAL: int = 4

func _init() -> void:
	super._init()
	mob_id = "dm201"
	mob_name = "DM-201"
	description = "An upgraded dwarven war machine with reinforced plating and corrosive vents."
	setup(80, 22, 12, 10, 24, 14, 0.7)  # Tougher than DM-200
	xp_value = 11
	max_level = 20
	awareness = 0.5
	aggro_range = 8
	base_speed = 0.7
	loot_table = [
		{"item_id": "gold", "chance": 0.7},
		{"item_id": "metal_shard", "chance": 0.3},
	]

func _act_hunting() -> void:
	gas_cooldown = maxi(0, gas_cooldown - 1)
	# Vent corrosive gas when adjacent
	if target and is_adjacent(target.pos) and gas_cooldown <= 0 and randf() < 0.35:
		_vent_corrosive_gas()
	super._act_hunting()

func _vent_corrosive_gas() -> void:
	did_visible_action = true
	gas_cooldown = GAS_INTERVAL
	if MessageLog:
		MessageLog.add_warning("The DM-201 vents corrosive gas!")
	# Apply corrosion/poison to all adjacent characters
	for dir: int in ConstantsData.DIRS_8:
		var adj_pos: int = pos + dir
		if level and level.has_method("find_char_at"):
			var victim: Variant = level.find_char_at(adj_pos)
			if victim and victim is Char:
				var c: Char = victim as Char
				# Corrosive gas: both poison and armor degradation
				var p: Poison = Poison.create(5.0)
				c.add_buff(p)
				# Apply ooze for ongoing acid damage
				if c.has_method("add_buff"):
					var ooze: Ooze = Ooze.new()
					c.add_buff(ooze)

func _on_death(source: Variant) -> void:
	# Release a large cloud of corrosive gas on death
	if MessageLog:
		MessageLog.add_warning("The DM-201 explodes in a cloud of corrosive gas!")
	_vent_corrosive_gas()
	# Also damage adjacent characters from the explosion
	if level:
		for dir: int in ConstantsData.DIRS_8:
			var adj_pos: int = pos + dir
			if level.has_method("find_char_at"):
				var victim: Variant = level.find_char_at(adj_pos)
				if victim and victim is Char:
					(victim as Char).take_damage(randi_range(8, 16), self)
	super._on_death(source)

func scale_to_depth(p_depth: int) -> void:
	var scale: int = maxi(0, p_depth - 12)
	hp = 80 + scale * 5
	hp_max = hp
	ht = hp
	damage_roll_min = 10 + scale * 2
	damage_roll_max = 24 + scale * 3
	armor_value = 14 + scale * 2
	attack_skill = 22 + scale * 2
