extends RefCounted
## Warrior Improvised Projectiles (upstream Talent.IMPROVISED_PROJECTILES,
## Warrior T2, in Item.cast): throwing any non-missile-weapon item at an
## enemy blinds it for 1 + points turns (2/3) and puts the talent on a
## 50-turn ImprovisedProjectileCooldown. Verified through
## Hero._try_improvised_projectiles directly.

func run(t: Object) -> void:
	_test_registry_entry(t)
	_test_blind_durations(t)
	_test_cooldown_blocks_second_trigger(t)
	_test_missile_weapon_excluded(t)
	_test_untalented_no_effect(t)
	_test_invalid_targets_ignored(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	if points > 0:
		hero.talent_levels["warrior_improvised_projectiles"] = points
	return hero

func _make_mob() -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 10
	mob.hp = 10
	mob.pos = ConstantsData.xy_to_pos(5, 5)
	return mob

func _test_registry_entry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.WARRIOR, "warrior_improvised_projectiles")
	t.check(info != null, "Improvised Projectiles is registered for the Warrior")
	t.check(info != null and info.tier == 2, "Improvised Projectiles is tier 2")
	t.check(info != null and info.max_points == 2, "Improvised Projectiles caps at 2 points")

func _test_blind_durations(t: Object) -> void:
	var hero := _make_warrior(1)
	var mob := _make_mob()
	hero._try_improvised_projectiles(Torch.new(), mob)
	var blind: Blindness = mob.get_buff("Blindness") as Blindness
	t.check(blind != null, "One-point throw blinds the enemy")
	t.check(blind != null and is_equal_approx(blind.duration, 2.0),
		"One point blinds for 2 turns")
	t.check(hero.has_buff("ImprovisedProjectileCooldown"),
		"Triggering attaches the 50-turn cooldown")
	var hero2 := _make_warrior(2)
	var mob2 := _make_mob()
	hero2._try_improvised_projectiles(Torch.new(), mob2)
	var blind2: Blindness = mob2.get_buff("Blindness") as Blindness
	t.check(blind2 != null and is_equal_approx(blind2.duration, 3.0),
		"Two points blind for 3 turns")
	mob.free()
	mob2.free()
	hero.free()
	hero2.free()

func _test_cooldown_blocks_second_trigger(t: Object) -> void:
	var hero := _make_warrior(2)
	var mob := _make_mob()
	var mob2 := _make_mob()
	hero._try_improvised_projectiles(Torch.new(), mob)
	hero._try_improvised_projectiles(Torch.new(), mob2)
	t.check(mob.has_buff("Blindness"), "First throw blinds")
	t.check(not mob2.has_buff("Blindness"),
		"Second throw during cooldown does not blind")
	mob.free()
	mob2.free()
	hero.free()

func _test_missile_weapon_excluded(t: Object) -> void:
	var hero := _make_warrior(2)
	var mob := _make_mob()
	hero._try_improvised_projectiles(MissileWeapon.new(), mob)
	t.check(not mob.has_buff("Blindness"),
		"Thrown missile weapons do not trigger the talent")
	t.check(not hero.has_buff("ImprovisedProjectileCooldown"),
		"Missile weapon throws do not start the cooldown")
	mob.free()
	hero.free()

func _test_untalented_no_effect(t: Object) -> void:
	var hero := _make_warrior(0)
	var mob := _make_mob()
	hero._try_improvised_projectiles(Torch.new(), mob)
	t.check(not mob.has_buff("Blindness"),
		"Untalented throws never blind")
	mob.free()
	hero.free()

func _test_invalid_targets_ignored(t: Object) -> void:
	var hero := _make_warrior(2)
	var ally := _make_mob()
	ally.is_ally = true
	hero._try_improvised_projectiles(Torch.new(), ally)
	t.check(not ally.has_buff("Blindness"), "Allied mobs are not blinded")
	t.check(not hero.has_buff("ImprovisedProjectileCooldown"),
		"Invalid targets do not start the cooldown")
	hero._try_improvised_projectiles(Torch.new(), null)
	t.check(not hero.has_buff("ImprovisedProjectileCooldown"),
		"A throw with no target is a no-op")
	ally.free()
	hero.free()
