extends RefCounted
## Scorpio SPD parity + Acidic scorpio rare alt (upstream Scorpio.java /
## Acidic.java + MobSpawner.RARE_ALTS): upstream stats, ranged-only attack
## with hunting retreat, 1/2 cripple proc, potion loot filtering, acidic
## ooze on attack/melee-defense, and guaranteed potion of experience.

func run(t: Object) -> void:
	_test_rare_alt_swap(t)
	_test_not_in_tables(t)
	_test_scorpio_stats(t)
	_test_scorpio_cripple(t)
	_test_scorpio_never_melees(t)
	_test_scorpio_ranged_attack(t)
	_test_scorpio_loot_pool(t)
	_test_acidic_stats(t)
	_test_acidic_ooze_procs(t)
	_test_acidic_loot(t)
	_test_serialization(t)


func _make_level() -> Level:
	var level := Level.new()
	level.depth = 24
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level


func _make_hero(level: Level, x: int, y: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = ConstantsData.xy_to_pos(x, y)
	hero.level = level
	return hero


func _test_rare_alt_swap(t: Object) -> void:
	t.check(MobFactory.apply_rare_alt("scorpio", 0.0) == "acidic",
		"Winning roll swaps scorpio -> acidic")
	t.check(MobFactory.apply_rare_alt("scorpio", 0.5) == "scorpio",
		"Losing roll keeps the base scorpio")
	t.check(MobFactory.create_mob("acidic") is Acidic,
		"Factory creates Acidic")


func _test_not_in_tables(t: Object) -> void:
	# Upstream: acidics spawn only via the 1/50 swap.
	for depth: int in range(1, 27):
		for entry: Dictionary in MobFactory.get_mob_table(depth):
			t.check(entry["mob_id"] != "acidic",
				"Depth %d table has no direct acidic entry" % depth)


func _test_scorpio_stats(t: Object) -> void:
	var scorpio := Scorpio.new()
	t.check(scorpio.hp == 110 and scorpio.hp_max == 110,
		"Scorpio HP 110 (upstream)")
	t.check(scorpio.attack_skill == 36, "Scorpio attackSkill 36")
	t.check(scorpio.defense_skill == 24, "Scorpio defenseSkill 24")
	t.check(scorpio.damage_roll_min == 30 and scorpio.damage_roll_max == 40,
		"Scorpio damage 30-40")
	t.check(scorpio.armor_value == 16, "Scorpio drRoll bonus 0-16 via armor 16")
	t.check(scorpio.xp_value == 14 and scorpio.max_level == 27,
		"Scorpio EXP 14 / maxLvl 27")
	t.check(scorpio._properties.has("DEMONIC"), "Scorpio is DEMONIC")
	t.check(scorpio.loot_table.is_empty(),
		"Scorpio loot handled by create_loot, not the table")


func _test_scorpio_cripple(t: Object) -> void:
	var scorpio := Scorpio.new()
	var rat := Rat.new()
	scorpio.apply_cripple(rat)
	t.check(rat.has_buff("Cripple"), "apply_cripple applies Cripple")


func _test_scorpio_never_melees(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, 5, 5)
	var scorpio := Scorpio.new()
	scorpio.pos = ConstantsData.xy_to_pos(6, 5)
	scorpio.level = level
	level.add_mob(scorpio)
	scorpio.state = Mob.AIState.HUNTING
	scorpio.target = hero
	scorpio.target_pos = hero.pos
	var hp_before: int = hero.hp
	var pos_before: int = scorpio.pos
	scorpio._act_hunting()
	t.check(hero.hp == hp_before,
		"Adjacent scorpio never attacks (upstream canAttack excludes adjacent)")
	t.check(scorpio.pos != pos_before,
		"Adjacent scorpio retreats instead (hunting getFurther)")


func _test_scorpio_ranged_attack(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, 5, 5)
	hero.defense_skill = 0
	hero.hp_max = 500
	hero.ht = 500
	hero.hp = 500
	var scorpio := Scorpio.new()
	scorpio.pos = ConstantsData.xy_to_pos(10, 5)
	scorpio.level = level
	level.add_mob(scorpio)
	scorpio.state = Mob.AIState.HUNTING
	scorpio.target = hero
	scorpio.target_pos = hero.pos
	var hp_before: int = hero.hp
	scorpio._act_hunting()
	t.check(hero.hp < hp_before,
		"Scorpio hits from 5 cells away (ranged spike attack)")


func _test_scorpio_loot_pool(t: Object) -> void:
	var scorpio := Scorpio.new()
	for _i: int in range(100):
		var potion_id: String = scorpio._random_loot_potion_id()
		t.check(potion_id != "healing" and potion_id != "strength",
			"Scorpio loot potion is never healing or strength")
	var item: Item = scorpio.create_loot()
	t.check(item != null, "Scorpio create_loot yields a potion")


func _test_acidic_stats(t: Object) -> void:
	var acidic := Acidic.new()
	t.check(acidic is Scorpio, "Acidic extends Scorpio")
	t.check(acidic.mob_id == "acidic", "Acidic mob_id")
	t.check(acidic.mob_name == "Acidic Scorpio", "Acidic display name")
	t.check(acidic.hp == 110 and acidic.xp_value == 14,
		"Acidic inherits scorpio HP/EXP")
	t.check(acidic._properties.has("DEMONIC") and acidic._properties.has("ACIDIC"),
		"Acidic is DEMONIC + ACIDIC")


func _test_acidic_ooze_procs(t: Object) -> void:
	var level := _make_level()
	var acidic := Acidic.new()
	acidic.pos = ConstantsData.xy_to_pos(6, 5)
	acidic.level = level
	# attack_proc always oozes the victim.
	var victim := Rat.new()
	acidic.attack_proc(victim, 5)
	t.check(victim.has_buff("Ooze"), "Acidic attack coats the victim in ooze")
	# defense_proc oozes adjacent (melee) attackers...
	var melee := Rat.new()
	melee.pos = ConstantsData.xy_to_pos(5, 5)
	melee.level = level
	acidic.defense_proc(melee, 3)
	t.check(melee.has_buff("Ooze"), "Melee attacker gets splashed with ooze")
	# ...but not ranged ones.
	var ranged := Rat.new()
	ranged.pos = ConstantsData.xy_to_pos(1, 1)
	ranged.level = level
	acidic.defense_proc(ranged, 3)
	t.check(not ranged.has_buff("Ooze"),
		"Ranged attacker is not splashed (upstream adjacency gate)")


func _test_acidic_loot(t: Object) -> void:
	var acidic := Acidic.new()
	var item: Item = acidic.create_loot()
	t.check(item != null and item.item_id == "experience",
		"Acidic always drops a potion of experience")


func _test_serialization(t: Object) -> void:
	var acidic := Acidic.new()
	acidic.hp = 42
	var data: Dictionary = acidic.serialize()
	var loaded: Mob = MobFactory.create_mob("acidic")
	loaded.deserialize(data)
	t.check(loaded is Acidic, "Round-trip preserves Acidic type")
	t.check(loaded.hp == 42, "Round-trip preserves HP")
