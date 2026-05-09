class_name DM200
extends Mob
## Mechanical guardian. Releases toxic gas cloud on death and periodically.

var gas_cooldown: int = 0
const GAS_INTERVAL: int = 5

func _init() -> void:
	super._init()
	mob_id = "dm200"
	mob_name = "DM-200"
	description = "A dwarven war machine that vents toxic fumes."
	setup(65, 20, 10, 8, 20, 12)
	xp_value = 9
	max_level = 18
	awareness = 0.5
	aggro_range = 8
	base_speed = 0.8  # Heavy and slow
	loot_table = [{"item_id": "gold", "chance": 0.6}]

func _act_hunting() -> void:
	gas_cooldown = maxi(0, gas_cooldown - 1)
	if target and is_adjacent(target.pos) and gas_cooldown <= 0 and randf() < 0.3:
		_vent_gas()
	super._act_hunting()

func _vent_gas() -> void:
	did_visible_action = true
	gas_cooldown = GAS_INTERVAL
	if MessageLog:
		MessageLog.add_warning("The DM-200 vents toxic gas!")
	# Apply poison to all adjacent characters
	for dir: int in ConstantsData.DIRS_8:
		var adj_pos: int = pos + dir
		if level and level.has_method("find_char_at"):
			var victim: Variant = level.find_char_at(adj_pos)
			if victim and victim is Char:
				var p: Poison = Poison.create(4.0)
				(victim as Char).add_buff(p)

func _on_death(_source: Variant) -> void:
	# Release gas cloud on death
	_vent_gas()
