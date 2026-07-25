extends RefCounted
## Warlock Soul Mark parity (upstream Mob.defenseProc block + Talent.SOUL_SIPHON):
## physical damage to a marked mob restores the Warlock. Hero damage heals
## ceil(0.4 * restoration); other attackers are scaled by Soul Siphon points
## (round(restoration * 0.4 * pts/3)); restoration caps at the mob's
## hp + shielding; Soul Eater points grant satiety (restoration * pts/3).

func run(t: Object) -> void:
	_test_hero_damage_heals(t)
	_test_restoration_caps_at_mob_hp(t)
	_test_non_hero_damage_needs_soul_siphon(t)
	_test_soul_siphon_scaling(t)
	_test_full_hp_no_heal(t)
	_test_non_warlock_no_restoration(t)
	_test_soul_eater_satiety(t)
	_test_prolong(t)
	_test_mob_defense_proc_integration(t)

func _make_warlock() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARLOCK
	return hero

func _make_marked_mob(mob_hp: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = mob_hp
	mob.hp = mob_hp
	mob.add_buff(SoulMark.new())
	return mob

func _mark(mob: Mob) -> SoulMark:
	return mob.get_buff("SoulMark") as SoulMark

func _with_hero(hero: Hero, body: Callable) -> void:
	var prev: Variant = GameManager.hero
	GameManager.hero = hero
	body.call()
	GameManager.hero = prev

func _test_hero_damage_heals(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(30)
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 10
		var healed: int = _mark(mob).process_restoration(10, hero)
		t.check(healed == 4, "Hero-dealt 10 damage heals ceil(0.4*10) = 4, got %d" % healed)
	)
	mob.free()
	hero.free()

func _test_restoration_caps_at_mob_hp(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(5)
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 10
		var healed: int = _mark(mob).process_restoration(50, hero)
		t.check(healed == 2, "Overkill restoration caps at mob hp (5): heal ceil(0.4*5) = 2, got %d" % healed)
	)
	mob.free()
	hero.free()

func _test_non_hero_damage_needs_soul_siphon(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(30)
	var ally := Char.new()
	ally.is_alive = true
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 10
		var healed: int = _mark(mob).process_restoration(10, ally)
		t.check(healed == 0, "Non-hero damage restores nothing without Soul Siphon")
	)
	ally.free()
	mob.free()
	hero.free()

func _test_soul_siphon_scaling(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(60)
	var ally := Char.new()
	ally.is_alive = true
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 20
		hero.talent_levels["warlock_soul_siphon"] = 1
		var healed: int = _mark(mob).process_restoration(30, ally)
		t.check(healed == 2, "Soul Siphon +1: restoration round(30*0.1333)=4, heal ceil(1.6)=2, got %d" % healed)
		hero.talent_levels["warlock_soul_siphon"] = 3
		healed = _mark(mob).process_restoration(30, ally)
		t.check(healed == 5, "Soul Siphon +3: restoration round(30*0.4)=12, heal ceil(4.8)=5, got %d" % healed)
	)
	ally.free()
	mob.free()
	hero.free()

func _test_full_hp_no_heal(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(30)
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max
		var healed: int = _mark(mob).process_restoration(10, hero)
		t.check(healed == 0, "No heal is credited at full HP")
	)
	mob.free()
	hero.free()

func _test_non_warlock_no_restoration(t: Object) -> void:
	var hero := _make_warlock()
	hero.hero_subclass = ConstantsData.HeroSubclass.BATTLEMAGE
	var mob := _make_marked_mob(30)
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 10
		var healed: int = _mark(mob).process_restoration(10, hero)
		t.check(healed == 0, "Non-Warlock subclass gains no soul mark restoration")
	)
	mob.free()
	hero.free()

func _test_soul_eater_satiety(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(30)
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 10
		var hunger: Variant = hero.get_buff("Hunger")
		if hunger == null:
			hunger = hero.add_buff(Hunger.new())
		hunger.hunger_value = 100.0
		hero.talent_levels["warlock_soul_eater"] = 3
		_mark(mob).process_restoration(10, hero)
		t.check(is_equal_approx(hunger.hunger_value, 90.0),
			"Soul Eater +3 grants 1 satiety per restoration point (100 -> 90), got %f" % hunger.hunger_value)
	)
	mob.free()
	hero.free()

func _test_prolong(t: Object) -> void:
	var mark := SoulMark.new()
	mark.time_left = 4.0
	mark.prolong(12.0)
	t.check(is_equal_approx(mark.time_left, 12.0), "prolong raises time_left to 12")
	mark.prolong(5.0)
	t.check(is_equal_approx(mark.time_left, 12.0), "prolong never shortens an existing mark")
	mark.free()

func _test_mob_defense_proc_integration(t: Object) -> void:
	var hero := _make_warlock()
	var mob := _make_marked_mob(30)
	_with_hero(hero, func() -> void:
		hero.hp = hero.hp_max - 10
		var before: int = hero.hp
		mob.defense_proc(hero, 10)
		t.check(hero.hp == before + 4, "Mob.defense_proc routes marked damage into a 4 HP heal")
	)
	mob.free()
	hero.free()
