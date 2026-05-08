class_name Thief
extends Mob
## Steals an item from the hero and tries to flee.

var stolen_item: Variant = null

func _init() -> void:
	super._init()
	mob_id = "thief"
	mob_name = "Crazy Thief"
	description = "A deranged thief who will steal your belongings and flee."
	setup(20, 12, 6, 1, 7, 3)
	xp_value = 4
	max_level = 12
	awareness = 0.4
	aggro_range = 8
	base_speed = 1.2

## Thief attacks at 2x speed (0.5x delay). Original: attackDelay() = super * 0.5f.
func attack_delay() -> float:
	return super.attack_delay() * 0.5

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	if stolen_item != null:
		return  # Already stole something
	# Try to steal
	if target_char is Hero and randf() < 0.3:
		var hero: Hero = target_char as Hero
		if hero.belongings and hero.belongings.item_count() > 0:
			# Steal random item (simplified — Phase 3 will flesh this out)
			stolen_item = true  # Placeholder
			_set_state(AIState.FLEEING)
			if MessageLog:
				MessageLog.add_negative("The thief steals from you!")

func should_flee() -> bool:
	return stolen_item != null

func _on_death(source: Variant) -> void:
	# Drop stolen item
	if stolen_item != null:
		if MessageLog:
			MessageLog.add_positive("The thief drops your stolen item!")
	super._on_death(source)
