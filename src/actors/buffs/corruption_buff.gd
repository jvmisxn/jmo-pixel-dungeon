class_name CorruptionBuff
extends Buff
## Corruption: converts an enemy mob to fight for the hero. Permanent until the
## mob dies. Mirrors SPD's Corruption buff — the mob switches allegiance, stops
## granting XP, and can no longer be harmed by the hero.

func _init() -> void:
	buff_id = "Corruption"
	buff_name = "Corrupted"
	buff_type = BuffType.POSITIVE  # Positive from the caster's perspective
	duration = -1.0  # Permanent
	time_left = -1.0
	icon_color = Color(0.3, 0.0, 0.3)

func on_attach() -> void:
	if target == null:
		return
	# Flip the mob to the hero's side using the Mob ally mechanism.
	if target is Mob:
		var mob: Mob = target as Mob
		mob.is_ally = true
		mob.xp_value = 0  # Corrupted mobs grant no XP
		if GameManager and GameManager.hero is Char:
			mob.ally_hero = GameManager.hero as Char
		# Clear conflicting AI buffs / stale enemy target.
		mob.remove_buff_by_id("Amok")
		mob.remove_buff_by_id("Terror")
		mob.remove_buff_by_id("Dread")
		mob.target = null
		mob.target_pos = -1
		mob.state = Mob.AIState.HUNTING  # Active; _act_ally ignores the state value
	if MessageLog:
		MessageLog.add_positive("%s has been corrupted to your side!" % target.name)

func on_detach() -> void:
	# Corruption is permanent and only detaches when the mob dies; simply clear
	# the ally flags. We must NOT deal damage here — the mob is already dying and
	# re-entering take_damage would recurse through death handling.
	if target is Mob:
		var mob: Mob = target as Mob
		mob.is_ally = false
		mob.ally_hero = null

func description() -> String:
	return "Mind corrupted. Fighting for the hero until death."
