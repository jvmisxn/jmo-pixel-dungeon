extends RefCounted
## RunTransitionCoordinator.parse_cause_of_death: upstream Dungeon.hero
## last_damage_source can be a Mob (with mob_name), a plain String, any other
## Object, or null. This covers the four branches so regressions surface in CI
## before they reach the death scene title.

func run(t: Object) -> void:
	_test_null_hero(t)
	_test_no_source(t)
	_test_mob_source(t)
	_test_string_source(t)
	_test_unknown_object_source(t)
	_test_mob_no_mob_name(t)

class _StubMob extends RefCounted:
	var mob_name: String = ""
	func get(prop: StringName) -> Variant:
		if prop == &"mob_name":
			return mob_name
		return null

class _StubHero extends RefCounted:
	var last_damage_source: Variant = null
	func get(prop: StringName) -> Variant:
		if prop == &"last_damage_source":
			return last_damage_source
		return null

func _test_null_hero(t: Object) -> void:
	t.check(
		RunTransitionCoordinator.parse_cause_of_death(null) == "the dungeon",
		"null hero -> 'the dungeon'"
	)

func _test_no_source(t: Object) -> void:
	var hero := _StubHero.new()
	t.check(
		RunTransitionCoordinator.parse_cause_of_death(hero) == "the dungeon",
		"hero with null last_damage_source -> 'the dungeon'"
	)

func _test_mob_source(t: Object) -> void:
	var mob := _StubMob.new()
	mob.mob_name = "Rat"
	var hero := _StubHero.new()
	hero.last_damage_source = mob
	t.check(
		RunTransitionCoordinator.parse_cause_of_death(hero) == "Rat",
		"Object source with mob_name -> mob_name string"
	)

func _test_string_source(t: Object) -> void:
	var hero := _StubHero.new()
	hero.last_damage_source = "starvation"
	t.check(
		RunTransitionCoordinator.parse_cause_of_death(hero) == "starvation",
		"String source -> that string"
	)

func _test_unknown_object_source(t: Object) -> void:
	var hero := _StubHero.new()
	var obj := RefCounted.new()
	hero.last_damage_source = obj
	var result: String = RunTransitionCoordinator.parse_cause_of_death(hero)
	t.check(
		result.length() > 0,
		"Unknown-object source -> non-empty str(src) fallback"
	)
	t.check(
		result != "the dungeon",
		"Unknown-object source does not fall back to 'the dungeon'"
	)

func _test_mob_no_mob_name(t: Object) -> void:
	var mob := _StubMob.new()
	mob.mob_name = ""
	var hero := _StubHero.new()
	hero.last_damage_source = mob
	var result: String = RunTransitionCoordinator.parse_cause_of_death(hero)
	t.check(
		result != "Rat",
		"Object with empty mob_name does not use the mob_name branch"
	)
