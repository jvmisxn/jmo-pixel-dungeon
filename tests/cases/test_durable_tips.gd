extends RefCounted
## Warden Durable Tips (upstream TippedDart.durabilityPerUse: use /= 1 + points):
## port adaptation — each tipped dart survives (1 + points) throws before the
## stack loses a dart, tracked deterministically via durable_tips_uses.

func _make_warden(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARDEN
	if points > 0:
		hero.talent_levels["warden_durable_tips"] = points
	return hero

func run(t: Object) -> void:
	_test_registry(t)
	_test_tipped_dart_flag(t)
	_test_no_points_consumes(t)
	_test_preserve_cycle(t)
	_test_non_tipped_unaffected(t)
	_test_serialization(t)

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "warden_durable_tips",
		ConstantsData.HeroSubclass.WARDEN
	)
	t.check(info != null and info.implemented, "Durable Tips is registered and implemented")
	t.check(info != null and info.max_points == 3, "Durable Tips caps at 3 points")

func _test_tipped_dart_flag(t: Object) -> void:
	t.check(MissileWeapon.create("curare_dart").is_tipped_dart(), "curare dart is tipped")
	t.check(MissileWeapon.create("paralytic_dart").is_tipped_dart(), "paralytic dart is tipped")
	t.check(not MissileWeapon.create("dart").is_tipped_dart(), "plain dart is not tipped")
	t.check(not MissileWeapon.create("bolas").is_tipped_dart(), "bolas is not tipped")

func _test_no_points_consumes(t: Object) -> void:
	var hero := _make_warden(0)
	var dart := MissileWeapon.create("curare_dart")
	t.check(not hero._durable_tips_preserves(dart), "no talent points: dart is consumed")
	t.check(dart.durable_tips_uses == 0, "no talent points: use counter untouched")
	hero.free()

func _test_preserve_cycle(t: Object) -> void:
	# 2 points: each dart survives 3 throws (preserve, preserve, consume).
	var hero := _make_warden(2)
	var dart := MissileWeapon.create("curare_dart")
	t.check(hero._durable_tips_preserves(dart), "2 points: first throw preserved")
	t.check(hero._durable_tips_preserves(dart), "2 points: second throw preserved")
	t.check(not hero._durable_tips_preserves(dart), "2 points: third throw consumes the dart")
	t.check(dart.durable_tips_uses == 0, "counter resets after the dart is consumed")
	t.check(hero._durable_tips_preserves(dart), "cycle repeats on the next dart in the stack")
	hero.free()

func _test_non_tipped_unaffected(t: Object) -> void:
	var hero := _make_warden(3)
	var knife := MissileWeapon.create("throwing_knife")
	t.check(not hero._durable_tips_preserves(knife), "non-tipped missiles are always consumed")
	hero.free()

func _test_serialization(t: Object) -> void:
	var dart := MissileWeapon.create("paralytic_dart")
	dart.durable_tips_uses = 2
	var restored := MissileWeapon.create("paralytic_dart")
	restored.deserialize(dart.serialize())
	t.check(restored.durable_tips_uses == 2, "durable_tips_uses survives serialize round-trip")
