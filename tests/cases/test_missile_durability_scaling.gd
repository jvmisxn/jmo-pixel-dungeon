extends RefCounted
## Missile durability upgrade scaling (upstream MissileWeapon.durabilityFactor:
## round(base_uses * 1.2^level)).
## Covers:
##   - durability_factor() matches round(base_uses * 1.2^lvl) at levels 0-5
##   - reset_uses() sets uses_left = durability_factor()
##   - upgrade() increments level AND refreshes uses_left
##   - multi-upgrade accumulates correctly (1.2^n)
##   - use_once() still counts down from the level-scaled maximum
##   - is_broken() fires at 0 from the scaled max


func run(t: Object) -> void:
	_test_durability_factor(t)
	_test_reset_uses(t)
	_test_upgrade_refreshes_uses(t)
	_test_multi_upgrade(t)
	_test_use_once_from_scaled_max(t)
	_test_broken_from_scaled_max(t)


func _test_durability_factor(t: Object) -> void:
	# Dart: base_uses = 8
	var dart = _make("dart")
	# Level 0: factor = round(8 * 1.2^0) = 8
	t.check(dart.durability_factor() == 8, "dart level-0 durability_factor == 8")
	# Level 1: round(8 * 1.2) = round(9.6) = 10
	dart.level = 1
	t.check(dart.durability_factor() == 10, "dart level-1 durability_factor == 10")
	# Level 2: round(8 * 1.44) = round(11.52) = 12
	dart.level = 2
	t.check(dart.durability_factor() == 12, "dart level-2 durability_factor == 12")
	# Level 3: round(8 * 1.728) = round(13.824) = 14
	dart.level = 3
	t.check(dart.durability_factor() == 14, "dart level-3 durability_factor == 14")

	# Shuriken: base_uses = 5
	var shuriken = _make("shuriken")
	t.check(shuriken.durability_factor() == 5, "shuriken level-0 durability_factor == 5")
	shuriken.level = 1
	# round(5 * 1.2) = round(6.0) = 6
	t.check(shuriken.durability_factor() == 6, "shuriken level-1 durability_factor == 6")


func _test_reset_uses(t: Object) -> void:
	var dart = _make("dart")
	dart.uses_left = 0
	dart.reset_uses()
	t.check(dart.uses_left == dart.durability_factor(),
		"reset_uses sets uses_left to durability_factor at level 0")

	dart.level = 2
	dart.uses_left = 0
	dart.reset_uses()
	t.check(dart.uses_left == dart.durability_factor(),
		"reset_uses sets uses_left to durability_factor at level 2")


func _test_upgrade_refreshes_uses(t: Object) -> void:
	# Fresh dart has uses_left = base_uses (level 0)
	var dart = _make("dart")
	t.check(dart.level == 0, "dart starts at level 0")
	t.check(dart.uses_left == 8, "dart starts with 8 uses")
	dart.upgrade()
	t.check(dart.level == 1, "dart.upgrade() raises level to 1")
	# After upgrade, uses_left = durability_factor(level=1) = round(8*1.2) = 10
	t.check(dart.uses_left == dart.durability_factor(),
		"upgrade() refreshes uses_left to new durability_factor")
	t.check(dart.uses_left == 10, "dart level-1 uses_left == 10")


func _test_multi_upgrade(t: Object) -> void:
	var javelin = _make("javelin")  # base_uses = 10
	t.check(javelin.uses_left == 10, "javelin starts with 10 uses")
	javelin.upgrade()  # level 1
	javelin.upgrade()  # level 2
	# round(10 * 1.44) = round(14.4) = 14
	t.check(javelin.uses_left == 14, "javelin at +2 has 14 uses")
	t.check(javelin.level == 2, "javelin level == 2 after two upgrades")


func _test_use_once_from_scaled_max(t: Object) -> void:
	var dart = _make("dart")
	dart.upgrade()  # level 1, uses_left = 10
	var expected_max: int = dart.durability_factor()
	t.check(dart.uses_left == expected_max, "uses_left == durability_factor after upgrade")
	# use_once counts down
	dart.use_once()
	t.check(dart.uses_left == expected_max - 1,
		"use_once decrements from the scaled max")


func _test_broken_from_scaled_max(t: Object) -> void:
	var shuriken = _make("shuriken")
	shuriken.upgrade()  # level 1, uses_left = 6
	var max_uses: int = shuriken.uses_left
	var broke: bool = false
	for i in max_uses:
		broke = shuriken.use_once()
	t.check(broke, "shuriken breaks exactly after durability_factor uses")
	t.check(shuriken.is_broken(), "is_broken() true after all uses spent")


static func _make(id: String) -> MissileWeapon:
	return MissileWeapon.create(id)
