class_name Bandit
extends Mob
## Bandit: A purple-tinted variant of Thief. Steals items and uses them.

var stolen_item: Variant = null

func _init() -> void:
	super._init()
	mob_id = "bandit"
	mob_name = "Crazy Bandit"
	description = "A deranged bandit in purple garb. Steals your items and uses them against you."
	setup(24, 14, 7, 2, 8, 4, 1.2)
	xp_value = 5
	max_level = 12
	awareness = 0.4
	aggro_range = 8
	base_speed = 1.2
	loot_table = [{"item_id": "gold", "chance": 0.4}]

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	if stolen_item != null:
		return  # Already stole something
	# Higher steal chance than regular thief
	if target_char is Hero and randf() < 0.4:
		var hero: Hero = target_char as Hero
		if hero.belongings and hero.belongings.item_count() > 0:
			stolen_item = true  # Placeholder
			# Bandit uses stolen items — apply a random debuff to simulate
			_use_stolen_item(target_char)
			_set_state(AIState.FLEEING)
			if MessageLog:
				MessageLog.add_negative("The bandit steals from you and uses it!")

## Simulate using a stolen item against the hero.
func _use_stolen_item(victim: Char) -> void:
	# Random debuff effect to simulate using a stolen potion/scroll
	var roll: float = randf()
	if roll < 0.33:
		var p: Poison = Poison.create(3.0)
		victim.add_buff(p)
	elif roll < 0.66:
		var blind: Blindness = Blindness.new()
		victim.add_buff(blind)
	# else: the item was mundane, no extra effect

func should_flee() -> bool:
	return stolen_item != null

func _on_death(source: Variant) -> void:
	if stolen_item != null:
		if MessageLog:
			MessageLog.add_positive("The bandit drops your stolen item!")
	super._on_death(source)

func scale_to_depth(p_depth: int) -> void:
	var scale: int = maxi(0, p_depth - 5)
	hp = 24 + scale * 3
	hp_max = hp
	ht = hp
	damage_roll_min = 2 + scale
	damage_roll_max = 8 + scale * 2
	attack_skill = 14 + scale * 2
	defense_skill = 7 + scale
