class_name CorruptionBuff
extends Buff
## Corruption: converts an enemy to fight for the hero. Permanent until death.

func _init() -> void:
	buff_id = "Corruption"
	buff_name = "Corrupted"
	is_debuff = false  # Positive from the caster's perspective
	duration = -1.0  # Permanent
	time_left = -1.0
	icon_color = Color(0.3, 0.0, 0.3)

func on_attach() -> void:
	if target == null:
		return
	# Switch alignment to ally
	if target.has_method("set_alignment"):
		target.set_alignment(ConstantsData.Alignment.ALLY)
	elif target.get("alignment") != null:
		target.alignment = ConstantsData.Alignment.ALLY
	if MessageLog:
		MessageLog.add_positive("%s has been corrupted to your side!" % target.name)

func on_detach() -> void:
	# If corruption is somehow removed, the mob dies
	if target:
		if MessageLog:
			MessageLog.add_negative("The corruption fades and %s collapses!" % target.name)
		target.take_damage(target.hp, self)

func on_turn() -> void:
	# Corrupted mobs slowly lose HP over time (they are burning through life force)
	if target and target.hp > 1:
		# Lose 1 HP per turn — they are expendable
		pass  # Optional: enable slow drain if desired

func description() -> String:
	return "Mind corrupted. Fighting for the hero until death."
