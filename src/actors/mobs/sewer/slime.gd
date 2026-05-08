class_name Slime
extends Mob
## Splits into two smaller slimes when at low HP.

var split_done: bool = false

func _init() -> void:
	super._init()
	mob_id = "slime"
	mob_name = "Caustic Slime"
	description = "A gelatinous blob of acidic ooze."
	setup(20, 8, 2, 1, 5, 2)
	xp_value = 3
	max_level = 7
	awareness = 0.1
	aggro_range = 5
	base_speed = 0.8

func act() -> void:
	# Check if should split
	@warning_ignore("integer_division")
	if not split_done and hp <= hp_max / 2:
		_try_split()
	super.act()

func _try_split() -> void:
	split_done = true
	did_visible_action = true
	# Find adjacent empty cell
	for dir: int in ConstantsData.DIRS_4:
		var spawn_pos: int = pos + dir
		if _can_move_to(spawn_pos):
			# Create a new smaller slime
			var child: Slime = Slime.new()
			@warning_ignore("integer_division")
			child.hp = hp / 2
			@warning_ignore("integer_division")
			child.hp_max = hp_max / 2
			@warning_ignore("integer_division")
			child.ht = hp_max / 2
			child.split_done = true
			child.pos = spawn_pos
			child.level = level
			child.state = AIState.HUNTING
			child.target = target
			if level and level.has_method("add_mob"):
				level.add_mob(child)
			child.activate()
			@warning_ignore("integer_division")
			hp = hp / 2
			if MessageLog:
				MessageLog.add_info("The slime splits in two!")
			return

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	# Acid degrades armor
	if randf() < 0.3 and target_char is Hero:
		if MessageLog:
			MessageLog.add_warning("The slime's attack degrades your armor!")
