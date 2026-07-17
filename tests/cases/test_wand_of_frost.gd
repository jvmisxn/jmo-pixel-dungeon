extends RefCounted
## WandOfFrost fidelity (audit S14 P1): a frost bolt only FREEZES (paralyses) a
## target that was ALREADY chilled before this hit. SPD's Frost.freeze() reads
## the chill state prior to re-applying Chill; the port must not paralyse a fresh
## target just because it applied Cripple a line earlier.

## Minimal level stand-in: on_zap only needs find_char_at() and (optionally)
## get_terrain/set_terrain, which we deliberately omit so the water-freeze loop
## is skipped.
class _FakeLevel extends RefCounted:
	var target_char: Object = null
	func find_char_at(_pos: int) -> Object:
		return target_char

func run(t: Object) -> void:
	_test_fresh_target_is_only_chilled(t)
	_test_prechilled_target_is_frozen(t)

func _make_frost_wand() -> Object:
	var wand: Object = Wand.WandOfFrost.new()
	wand.level = 0
	return wand

func _make_target() -> Char:
	var c: Char = Char.new()
	c.name = "FrostTarget"
	c.hp_max = 1000
	c.hp = 1000
	c.is_alive = true
	c.pos = 5
	return c

func _make_hero_on_floor(target: Char) -> Char:
	var floor := _FakeLevel.new()
	floor.target_char = target
	# on_zap is typed on(hero: Char) and reads hero.level (Actor.level, a Variant)
	# to find the floor — a real Char with the fake floor injected is enough.
	var hero := Char.new()
	hero.name = "FrostCaster"
	hero.is_alive = true
	hero.level = floor
	return hero

func _test_fresh_target_is_only_chilled(t: Object) -> void:
	var target: Char = _make_target()
	var hero: Char = _make_hero_on_floor(target)
	var wand: Object = _make_frost_wand()

	wand.on_zap(hero, [target.pos] as Array[int])

	t.check(target.has_buff("Cripple"),
		"Frost bolt chills a fresh target")
	t.check(not target.has_buff("Paralysis"),
		"Frost bolt does NOT freeze a target that was not already chilled")

	target.free()
	hero.free()

func _test_prechilled_target_is_frozen(t: Object) -> void:
	var target: Char = _make_target()
	# Target is already chilled before the bolt lands.
	target.add_buff(Cripple.new())
	t.check(target.has_buff("Cripple"), "target starts chilled")
	t.check(not target.has_buff("Paralysis"), "target starts un-frozen")

	var hero: Char = _make_hero_on_floor(target)
	var wand: Object = _make_frost_wand()

	wand.on_zap(hero, [target.pos] as Array[int])

	t.check(target.has_buff("Paralysis"),
		"Frost bolt freezes a target that was already chilled")

	target.free()
	hero.free()
