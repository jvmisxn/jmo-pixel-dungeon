extends RefCounted
## Assassin Preparation parity (upstream Preparation buff + Char.attack block):
## attaches with Invisibility for Assassins only, builds one level tier per
## invisible turn (1/3/5/9 turns), prepared attacks take the best of N damage
## rolls times a staged bonus (10/20/35/50%), and can execute enemies under a
## KO threshold scaled by Enhanced Lethality. Detaches when visibility returns.

func run(t: Object) -> void:
	_test_attach_with_invisibility(t)
	_test_non_assassin_no_attach(t)
	_test_level_thresholds(t)
	_test_detach_when_visible(t)
	_test_prep_damage_roll(t)
	_test_can_ko_thresholds(t)
	_test_enhanced_lethality_scaling(t)
	_test_boss_threshold_divided(t)
	_test_attack_integration_ko(t)
	_test_serialize_round_trip(t)

func _make_assassin() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	hero.hero_subclass = ConstantsData.HeroSubclass.ASSASSIN
	return hero

func _make_mob(mob_hp: int, mob_hp_max: int = -1) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = mob_hp_max if mob_hp_max > 0 else mob_hp
	mob.hp = mob_hp
	return mob

func _prep_at(hero: Hero, turns: int) -> AssassinPreparation:
	hero.add_buff(Invisibility.new())
	var prep := hero.get_buff("AssassinPreparation") as AssassinPreparation
	prep.turns_invis = turns
	return prep

func _test_attach_with_invisibility(t: Object) -> void:
	var hero := _make_assassin()
	t.check(not hero.has_buff("AssassinPreparation"),
		"Assassin has no Preparation before going invisible")
	hero.add_buff(Invisibility.new())
	t.check(hero.has_buff("AssassinPreparation"),
		"Invisibility attaches Preparation to an Assassin")
	hero.free()

func _test_non_assassin_no_attach(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	hero.hero_subclass = ConstantsData.HeroSubclass.FREERUNNER
	hero.add_buff(Invisibility.new())
	t.check(not hero.has_buff("AssassinPreparation"),
		"Invisibility does not attach Preparation to a non-Assassin")
	hero.free()

func _test_level_thresholds(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 0)
	var expected: Array = [[0, 1], [1, 1], [2, 1], [3, 2], [5, 3], [8, 3], [9, 4], [20, 4]]
	var ok := true
	for pair: Array in expected:
		prep.turns_invis = pair[0]
		if prep.attack_level() != pair[1]:
			ok = false
	t.check(ok, "Attack level tiers match upstream turn thresholds 1/3/5/9")
	hero.free()

func _test_detach_when_visible(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 2)
	prep.on_turn()
	t.check(prep.turns_invis == 3, "Preparation builds while invisible")
	var invis: Node = hero.get_buff("Invisibility")
	(invis as Invisibility).dispel()
	t.check(not hero.has_buff("AssassinPreparation"),
		"Dispelling invisibility consumes Preparation")
	t.check(hero.invisible == 0, "Dispel clears the invisible counter")
	hero.free()

func _test_prep_damage_roll(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 1)
	# Level 1: single roll, +10%
	var dmg: int = prep.prep_damage_roll(func() -> int: return 10)
	t.check(dmg == 11, "Level 1 prepared roll is roll * 1.10 (10 -> 11), got %d" % dmg)
	# Level 3 (5 turns): best of 2 rolls, +35%
	prep.turns_invis = 5
	var rolls: Array[int] = [4, 20]
	var i: Array[int] = [0]
	dmg = prep.prep_damage_roll(func() -> int:
		var r: int = rolls[i[0] % rolls.size()]
		i[0] += 1
		return r)
	t.check(dmg == 27, "Level 3 takes best of 2 rolls * 1.35 (20 -> 27), got %d" % dmg)
	t.check(i[0] == 2, "Level 3 rolls exactly twice, rolled %d times" % i[0])
	# Level 4 (9 turns): best of 3 rolls, +50%
	prep.turns_invis = 9
	i[0] = 0
	dmg = prep.prep_damage_roll(func() -> int:
		var r: int = rolls[i[0] % rolls.size()]
		i[0] += 1
		return r)
	t.check(dmg == 30 and i[0] == 3,
		"Level 4 takes best of 3 rolls * 1.50 (20 -> 30), got %d in %d rolls" % [dmg, i[0]])
	hero.free()

func _test_can_ko_thresholds(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 9)
	# Level 4, no talent: threshold 50%
	var low := _make_mob(9, 20)
	var high := _make_mob(10, 20)
	t.check(prep.can_ko(low), "Full preparation KOs an enemy under 50% HP")
	t.check(not prep.can_ko(high), "Threshold is exclusive: exactly 50% HP survives")
	# Level 1: threshold 3%
	prep.turns_invis = 1
	var tiny := _make_mob(1, 100)
	t.check(prep.can_ko(tiny), "Level 1 KOs under 3% HP (1/100)")
	t.check(not prep.can_ko(low), "Level 1 does not KO 45% HP")
	low.free()
	high.free()
	tiny.free()
	hero.free()

func _test_enhanced_lethality_scaling(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 9)
	var mob := _make_mob(9, 10)
	t.check(not prep.can_ko(mob), "90% HP is safe without Enhanced Lethality")
	hero.talent_levels["assassin_enhanced_lethality"] = 3
	t.check(prep.can_ko(mob), "Enhanced Lethality +3 raises full-prep threshold to 100%")
	hero.talent_levels["assassin_enhanced_lethality"] = 1
	var mid := _make_mob(13, 20)
	t.check(prep.can_ko(mid), "Enhanced Lethality +1 full-prep threshold is 67% (13/20 KOs)")
	mob.free()
	mid.free()
	hero.free()

func _test_boss_threshold_divided(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 9)
	var boss := _make_mob(3, 20)
	boss._properties.append("BOSS")
	t.check(not prep.can_ko(boss), "Boss at 15% HP survives the 50%/5 = 10% threshold")
	boss.hp = 1
	t.check(prep.can_ko(boss), "Boss at 5% HP is under the divided threshold")
	boss.free()
	hero.free()

func _test_attack_integration_ko(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 9)
	prep.turns_invis = 9
	var mob := _make_mob(2, 100)
	mob.armor_value = 1000
	var prev: Variant = GameManager.hero
	GameManager.hero = hero
	hero.attack(mob)
	GameManager.hero = prev
	t.check(not mob.is_alive,
		"Char.attack executes a 2%-HP enemy through full armor at full preparation")
	mob.free()
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var hero := _make_assassin()
	var prep := _prep_at(hero, 6)
	var data: Dictionary = prep.serialize()
	var restored := AssassinPreparation.new()
	restored.deserialize(data)
	t.check(restored.turns_invis == 6, "turns_invis survives serialize round-trip")
	restored.free()
	hero.free()
