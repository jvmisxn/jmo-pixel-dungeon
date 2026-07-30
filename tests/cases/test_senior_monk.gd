extends RefCounted
## Dwarf Monk SPD parity + Senior monk rare alt (upstream Monk.java /
## Senior.java + MobSpawner.RARE_ALTS): monk stats/attack delay/Focus parry
## mechanic, focus cooldown burn via spending and travelling, senior 1/50
## swap with 16-25 damage, guaranteed pasty, and faster travel focus.

func run(t: Object) -> void:
	_test_rare_alt_swap(t)
	_test_not_in_tables(t)
	_test_monk_stats(t)
	_test_senior_stats(t)
	_test_focus_gain_while_hunting(t)
	_test_focus_infinite_evasion(t)
	_test_focus_gated_by_paralysis_and_sleep(t)
	_test_parry_consumes_focus(t)
	_test_travel_focus_bonus(t)
	_test_serialization(t)


func _make_level() -> Level:
	var level := Level.new()
	level.depth = 17
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level


func _test_rare_alt_swap(t: Object) -> void:
	t.check(MobFactory.apply_rare_alt("monk", 0.0) == "senior",
		"Winning roll swaps monk -> senior")
	t.check(MobFactory.apply_rare_alt("monk", 0.5) == "monk",
		"Losing roll keeps the base monk")
	t.check(MobFactory.create_mob("senior") is SeniorMonk,
		"Factory creates SeniorMonk")


func _test_not_in_tables(t: Object) -> void:
	# Upstream: seniors spawn only via the 1/50 swap.
	for depth: int in range(1, 25):
		for entry: Dictionary in MobFactory.get_mob_table(depth):
			t.check(entry["mob_id"] != "senior",
				"Depth %d table has no direct senior entry" % depth)


func _test_monk_stats(t: Object) -> void:
	var monk := MonkMob.new()
	t.check(monk.hp == 70 and monk.hp_max == 70, "Monk HP 70 (upstream)")
	t.check(monk.attack_skill == 30, "Monk attackSkill 30")
	t.check(monk.defense_skill == 30, "Monk defenseSkill 30")
	t.check(monk.damage_roll_min == 12 and monk.damage_roll_max == 25,
		"Monk damage 12-25")
	t.check(monk.armor_value == 2, "Monk drRoll bonus 0-2 via armor 2")
	t.check(monk.xp_value == 11 and monk.max_level == 21,
		"Monk EXP 11 / maxLvl 21")
	t.check(is_equal_approx(monk.attack_delay(), 0.5),
		"Monk attack delay 0.5x (two hits per turn)")
	t.check(is_equal_approx(monk.base_speed, 1.0),
		"Monk moves at normal speed (upstream has no speed boost)")
	t.check(monk._properties.has("UNDEAD"), "Monk is UNDEAD")
	t.check(monk.loot_table.size() == 1
		and monk.loot_table[0]["item_id"] == "ration"
		and is_equal_approx(float(monk.loot_table[0]["chance"]), 0.083),
		"Monk loot: ration @ 0.083")


func _test_senior_stats(t: Object) -> void:
	var senior := SeniorMonk.new()
	t.check(senior is MonkMob, "Senior extends MonkMob")
	t.check(senior.mob_id == "senior", "Senior mob_id")
	t.check(senior.mob_name == "Senior Monk", "Senior display name")
	t.check(senior.hp == 70 and senior.xp_value == 11,
		"Senior inherits monk HP/EXP")
	t.check(senior.damage_roll_min == 16 and senior.damage_roll_max == 25,
		"Senior damage 16-25 (upstream damageRoll)")
	t.check(senior.loot_table.size() == 1
		and senior.loot_table[0]["item_id"] == "pasty"
		and is_equal_approx(float(senior.loot_table[0]["chance"]), 1.0),
		"Senior always drops a pasty")
	t.check(senior.description.contains("mastered the art"),
		"Senior has its upstream description")


func _test_focus_gain_while_hunting(t: Object) -> void:
	var level := _make_level()
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = ConstantsData.xy_to_pos(5, 5)
	hero.level = level
	var monk := MonkMob.new()
	monk.pos = ConstantsData.xy_to_pos(6, 5)
	monk.level = level
	level.add_mob(monk)
	monk.state = Mob.AIState.HUNTING
	monk.target = hero
	monk.target_pos = hero.pos
	monk.focus_cooldown = 0.0
	monk.act()
	t.check(monk.has_buff("MonkFocus"),
		"Hunting monk off cooldown gains Focus after acting")
	# On cooldown: no new focus.
	var monk2 := MonkMob.new()
	monk2.pos = ConstantsData.xy_to_pos(6, 6)
	monk2.level = level
	level.add_mob(monk2)
	monk2.state = Mob.AIState.HUNTING
	monk2.target = hero
	monk2.target_pos = hero.pos
	monk2.focus_cooldown = 5.0
	monk2.act()
	t.check(not monk2.has_buff("MonkFocus"),
		"Hunting monk on cooldown does not gain Focus")


func _test_focus_infinite_evasion(t: Object) -> void:
	var monk := MonkMob.new()
	monk.state = Mob.AIState.HUNTING  # fresh mobs default to SLEEPING
	monk.add_buff(MonkFocus.new())
	t.check(monk.evasion() >= 1000000,
		"Focused monk has infinite evasion")
	var rat := Rat.new()
	var hit_any: bool = false
	for _i: int in range(50):
		if Char.hit(rat, monk):
			hit_any = true
	t.check(not hit_any, "No attack lands on a focused monk (50 rolls)")


func _test_focus_gated_by_paralysis_and_sleep(t: Object) -> void:
	var monk := MonkMob.new()
	monk.add_buff(MonkFocus.new())
	monk.paralysed = 1
	t.check(monk.evasion() == 30,
		"Paralysed monk loses infinite evasion (base 30)")
	monk.paralysed = 0
	monk.state = Mob.AIState.SLEEPING
	t.check(monk.evasion() == 30,
		"Sleeping monk loses infinite evasion (base 30)")
	monk.state = Mob.AIState.HUNTING
	t.check(monk.evasion() >= 1000000,
		"Awake unparalysed monk regains infinite evasion")


func _test_parry_consumes_focus(t: Object) -> void:
	var monk := MonkMob.new()
	var focus := MonkFocus.new()
	monk.add_buff(focus)
	monk.focus_cooldown = 0.0
	# Char's miss path notifies defender buffs with amount 0.
	focus.on_damage_taken(0, null)
	t.check(not monk.has_buff("MonkFocus"), "Parry consumes the Focus buff")
	t.check(monk.focus_cooldown >= 6.0 and monk.focus_cooldown <= 7.0,
		"Parry starts a 6-7 turn focus cooldown (got %f)" % monk.focus_cooldown)


func _test_travel_focus_bonus(t: Object) -> void:
	var monk := MonkMob.new()
	t.check(is_equal_approx(monk._travel_focus_bonus(), 0.67),
		"Monk travel focus bonus 0.67")
	monk.focus_cooldown = 5.0
	monk.on_move(0, 1)
	t.check(is_equal_approx(monk.focus_cooldown, 4.33),
		"Moving burns an extra 0.67 focus cooldown")
	var senior := SeniorMonk.new()
	t.check(is_equal_approx(senior._travel_focus_bonus(), 2.33),
		"Senior travel focus bonus 2.33 (0.67 + 1.66)")
	senior.focus_cooldown = 5.0
	senior.on_move(0, 1)
	t.check(is_equal_approx(senior.focus_cooldown, 2.67),
		"Senior moving burns 2.33 focus cooldown")
	# Spending a turn burns cooldown by the time spent.
	var monk2 := MonkMob.new()
	monk2.focus_cooldown = 3.0
	monk2.spend_turn(1.0)
	t.check(is_equal_approx(monk2.focus_cooldown, 2.0),
		"Spending a turn burns 1.0 focus cooldown")


func _test_serialization(t: Object) -> void:
	var senior := SeniorMonk.new()
	senior.focus_cooldown = 4.5
	senior.add_buff(MonkFocus.new())
	var data: Dictionary = senior.serialize()
	var loaded: Mob = MobFactory.create_mob("senior")
	loaded.deserialize(data)
	t.check(loaded is SeniorMonk, "Round-trip preserves SeniorMonk type")
	t.check(is_equal_approx(loaded.focus_cooldown, 4.5),
		"Round-trip preserves focus_cooldown")
	t.check(loaded.has_buff("MonkFocus"), "Round-trip preserves Focus buff")
