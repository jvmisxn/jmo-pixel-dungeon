extends RefCounted
## Floor-pickup time cost (upstream Item.TIME_TO_PICK_UP / pickupDelay +
## ThrowingClub/ThrowingHammer.pickupDelay overrides): taking an item off the
## floor costs the hero 1 turn, except throwing clubs and throwing hammers,
## which are picked up instantly. Covers:
##   - base Item.pickup_delay() is the upstream 1-turn cost
##   - throwing_club and throwing_hammer pick up for free
##   - other missiles keep the standard 1-turn cost
##   - a 1-turn pickup spends real cooldown through the scheduler


func run(t: Object) -> void:
	_test_base_item_delay(t)
	_test_instant_missiles(t)
	_test_other_missiles_standard(t)
	_test_pickup_spends_cooldown(t)


func _test_base_item_delay(t: Object) -> void:
	var item := Item.new()
	t.check(
		item.pickup_delay() == 1.0,
		"base Item pickup_delay is the upstream TIME_TO_PICK_UP of 1 turn"
	)


func _test_instant_missiles(t: Object) -> void:
	for id: String in ["throwing_club", "throwing_hammer"]:
		var missile: MissileWeapon = MissileWeapon.create(id)
		t.check(
			missile != null and missile.pickup_delay() == 0.0,
			"%s is picked up instantly (upstream pickupDelay 0)" % id
		)


func _test_other_missiles_standard(t: Object) -> void:
	for id: String in ["shuriken", "throwing_knife", "javelin", "trident"]:
		var missile: MissileWeapon = MissileWeapon.create(id)
		t.check(
			missile != null and missile.pickup_delay() == 1.0,
			"%s keeps the standard 1-turn pickup cost" % id
		)


func _test_pickup_spends_cooldown(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var scheduler := TurnManagerNode.new()
	scheduler.register_actor(hero)
	var item := Item.new()
	scheduler.spend_energy(hero, item.pickup_delay())
	t.check(
		scheduler.get_cooldown(hero) > 0.0,
		"a standard pickup spends real cooldown on the hero"
	)
	var club: MissileWeapon = MissileWeapon.create("throwing_club")
	var before: float = scheduler.get_cooldown(hero)
	if club.pickup_delay() > 0.0:
		scheduler.spend_energy(hero, club.pickup_delay())
	t.check(
		scheduler.get_cooldown(hero) == before,
		"an instant pickup spends no cooldown"
	)
	hero.free()
