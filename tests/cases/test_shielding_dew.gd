extends RefCounted
## Warden Shielding Dew talent (upstream Dewdrop.consumeDew):
## effect = min(HT - HP, heal); shield = heal - effect, capped at
## round(HT * 0.2 * points) minus any existing Barrier shielding.

func _make_warden(points: int, hp: int = 30, hp_max: int = 30) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARDEN
	hero.hp = hp
	hero.hp_max = hp_max
	if points > 0:
		hero.talent_levels["warden_shielding_dew"] = points
	return hero

func run(t: Object) -> void:
	_test_registry(t)
	_test_shield_math(t)
	_test_pickup_at_full_hp(t)

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "warden_shielding_dew",
		ConstantsData.HeroSubclass.WARDEN
	)
	t.check(info != null and info.implemented, "Shielding Dew is registered and implemented")
	t.check(info != null and info.max_points == 3, "Shielding Dew caps at 3 points")

func _test_shield_math(t: Object) -> void:
	var dew := Dewdrop.new()

	# No points: no shield even at full HP.
	var plain := _make_warden(0)
	t.check(dew._shielding_dew_amount(plain, 3) == 0, "no shield without talent points")
	plain.free()

	# Full HP: all healing overflows into shield.
	var full := _make_warden(2)
	t.check(dew._shielding_dew_amount(full, 3) == 3, "full-HP dew converts fully to shield")
	full.free()

	# Partial damage: only the overheal portion shields.
	var hurt := _make_warden(2, 28, 30)
	t.check(dew._shielding_dew_amount(hurt, 3) == 1, "only overheal converts to shield")
	hurt.free()

	# Missing more HP than the heal: no overheal, no shield.
	var wounded := _make_warden(3, 10, 30)
	t.check(dew._shielding_dew_amount(wounded, 3) == 0, "no shield while healing is needed")
	wounded.free()

	# Cap: round(HT * 0.2 * points) minus existing barrier shielding.
	var capped := _make_warden(1)  # cap = round(30*0.2*1) = 6
	var barrier: Barrier = capped.add_buff(Barrier.new()) as Barrier
	barrier.set_shield(5)
	t.check(dew._shielding_dew_amount(capped, 3) == 1, "existing barrier counts against the cap")
	barrier.set_shield(6)
	t.check(dew._shielding_dew_amount(capped, 3) == 0, "shield stops at the talent cap")
	capped.free()

func _test_pickup_at_full_hp(t: Object) -> void:
	var hero := _make_warden(3)
	var dew := Dewdrop.new()
	dew.on_pickup(hero)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() >= 1 and barrier.get_shielding() <= 3,
		"full-HP dewdrop pickup grants 1-3 barrier shield")
	hero.free()
