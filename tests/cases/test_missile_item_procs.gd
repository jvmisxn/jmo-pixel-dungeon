extends RefCounted
## Per-item missile hit procs (upstream Tomahawk.proc / FishingSpear.proc).
## Covers:
##   - tomahawk bleed range 3 + lvl/2 .. 6 + lvl (level + Sharpshooting scale)
##   - tomahawk proc applies a Bleeding buff with a level inside that range
##     and merges via set_level (existing higher bleed is kept)
##   - fishing spear floors damage at half the piranha's current HP, leaves
##     higher rolls and non-piranha targets untouched
##   - missiles without a per-item proc return damage unchanged, no buffs


func run(t: Object) -> void:
	_test_tomahawk_bleed_range(t)
	_test_tomahawk_proc_applies_bleeding(t)
	_test_tomahawk_bleed_merges(t)
	_test_fishing_spear_piranha_floor(t)
	_test_no_proc_passthrough(t)


func _test_tomahawk_bleed_range(t: Object) -> void:
	var tomahawk: MissileWeapon = MissileWeapon.create("tomahawk")
	var r: Array[float] = tomahawk.tomahawk_bleed_range(null)
	t.check(r[0] == 3.0 and r[1] == 6.0, "tomahawk bleed range is 3..6 at level 0")
	tomahawk.level = 4
	r = tomahawk.tomahawk_bleed_range(null)
	t.check(r[0] == 5.0 and r[1] == 10.0, "tomahawk bleed range is 5..10 at level 4")


func _test_tomahawk_proc_applies_bleeding(t: Object) -> void:
	var tomahawk: MissileWeapon = MissileWeapon.create("tomahawk")
	var victim := Char.new()
	victim.hp = 30
	victim.hp_max = 30
	var dmg: int = tomahawk.proc_hit(null, victim, 12)
	t.check(dmg == 12, "tomahawk proc does not modify the damage dealt")
	var bleeding: Bleeding = victim.get_buff("Bleeding") as Bleeding
	t.check(bleeding != null, "tomahawk hit applies Bleeding")
	if bleeding != null:
		t.check(
			bleeding.bleed_level >= 3.0 and bleeding.bleed_level <= 6.0,
			"tomahawk bleed level rolls within 3..6 at level 0 (got %f)"
				% bleeding.bleed_level
		)
	victim.free()


func _test_tomahawk_bleed_merges(t: Object) -> void:
	var tomahawk: MissileWeapon = MissileWeapon.create("tomahawk")
	var victim := Char.new()
	victim.hp = 30
	victim.hp_max = 30
	var existing: Bleeding = Bleeding.create(50.0)
	victim.add_buff(existing)
	tomahawk.proc_hit(null, victim, 12)
	var bleeding: Bleeding = victim.get_buff("Bleeding") as Bleeding
	t.check(
		bleeding == existing and bleeding.bleed_level == 50.0,
		"tomahawk bleed merges into the existing buff and keeps the higher level"
	)
	victim.free()


func _test_fishing_spear_piranha_floor(t: Object) -> void:
	var spear: MissileWeapon = MissileWeapon.create("fishing_spear")
	var piranha := Piranha.new()
	piranha.hp = 40
	t.check(
		spear.proc_hit(null, piranha, 5) == 20,
		"fishing spear floors damage at half the piranha's current HP"
	)
	t.check(
		spear.proc_hit(null, piranha, 25) == 25,
		"fishing spear leaves rolls above the floor untouched"
	)
	piranha.free()

	var rat := Char.new()
	rat.hp = 40
	rat.hp_max = 40
	t.check(
		spear.proc_hit(null, rat, 5) == 5,
		"fishing spear does not modify damage against non-piranhas"
	)
	rat.free()


func _test_no_proc_passthrough(t: Object) -> void:
	var javelin: MissileWeapon = MissileWeapon.create("javelin")
	var victim := Char.new()
	victim.hp = 30
	victim.hp_max = 30
	t.check(javelin.proc_hit(null, victim, 9) == 9, "javelin proc_hit passes damage through")
	t.check(victim.get_buff("Bleeding") == null, "javelin applies no bleed")
	victim.free()
