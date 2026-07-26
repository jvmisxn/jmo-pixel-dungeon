extends RefCounted
## Warrior Iron Stomach (upstream Talent.IRON_STOMACH, Warrior T2):
## Talent.onFoodEaten attaches a WarriorFoodImmunity FlavourBuff lasting the
## eating cooldown, and Hero.damage divides damage by 4 at +1 and zeroes it
## at +2 while the buff is active. Port adaptation: eating always takes 1
## turn here (upstream base 3 is cut to 1 by this talent), so the buff lasts
## the single eating turn and the resistance half is the live effect.

func run(t: Object) -> void:
	_test_eating_attaches_immunity(t)
	_test_no_talent_no_immunity(t)
	_test_damage_quartered_at_one(t)
	_test_damage_negated_at_two(t)
	_test_no_reduction_without_buff(t)
	_test_buff_duration(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hp_max = 30
	hero.ht = 30
	hero.hp = 30
	if points > 0:
		hero.talent_levels["warrior_iron_stomach"] = points
	return hero

func _test_eating_attaches_immunity(t: Object) -> void:
	var hero := _make_warrior(1)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(hero.has_buff("WarriorFoodImmunity"),
		"Eating with Iron Stomach attaches the food-immunity buff")
	hero.free()

func _test_no_talent_no_immunity(t: Object) -> void:
	var hero := _make_warrior(0)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(not hero.has_buff("WarriorFoodImmunity"),
		"Eating without the talent attaches nothing")
	hero.free()

func _test_damage_quartered_at_one(t: Object) -> void:
	var hero := _make_warrior(1)
	hero.add_buff(WarriorFoodImmunity.new())
	hero.take_damage(8)
	t.check(hero.hp == 30 - 2,
		"+1 quarters 8 damage to 2 while eating, hp %d" % hero.hp)
	hero.free()

func _test_damage_negated_at_two(t: Object) -> void:
	var hero := _make_warrior(2)
	hero.add_buff(WarriorFoodImmunity.new())
	hero.take_damage(12)
	t.check(hero.hp == 30,
		"+2 negates all damage while eating, hp %d" % hero.hp)
	hero.free()

func _test_no_reduction_without_buff(t: Object) -> void:
	var hero := _make_warrior(2)
	hero.take_damage(8)
	t.check(hero.hp == 30 - 8,
		"Without the immunity buff damage lands in full, hp %d" % hero.hp)
	hero.free()

func _test_buff_duration(t: Object) -> void:
	var buff := WarriorFoodImmunity.new()
	t.check(buff.duration == 1.0,
		"Immunity lasts the port's 1-turn eating window")
	buff.free()
