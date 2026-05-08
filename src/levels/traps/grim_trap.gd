class_name GrimTrap
extends Trap
## Extremely dangerous trap that deals massive damage. Can instant-kill
## heroes with low HP. Skull themed.

func _init() -> void:
	trap_name = "grim trap"
	color = Color(0.2, 0.0, 0.0)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A deadly glyph activates beneath you!")

	if triggerer == null:
		return
	if not triggerer.has_method("take_damage"):
		return

	# Grim trap deals damage based on current HP
	# If HP is low enough, it can instant-kill
	var max_hp: int = 0
	var cur_hp: int = 0

	if triggerer.get("ht") != null:
		max_hp = triggerer.ht
	if triggerer.get("hp") != null:
		cur_hp = triggerer.hp

	# Base damage scales with depth
	var base_damage: int = 10 + level.depth * 3

	# If below 50% HP, deal lethal damage (the grim reaper effect)
	if cur_hp > 0 and cur_hp <= max_hp / 2:
		base_damage = cur_hp + 1  # Lethal!
		if MessageLog:
			MessageLog.add_negative("The grim trap reaps your soul!")
	else:
		# Still very high damage
		base_damage = maxi(base_damage, max_hp / 3)

	triggerer.take_damage(base_damage, "grim trap")

	# Apply weakness debuff to survivors
	if triggerer.has_method("add_buff"):
		var weak: Weakness = Weakness.new()
		weak.duration = 20.0
		weak.time_left = 20.0
		triggerer.add_buff(weak)
