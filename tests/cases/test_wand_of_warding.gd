extends RefCounted
## WandOfWarding fidelity: zapping an empty passable cell must conjure a REAL
## WardSentry actor on the level (not just record a position), and that sentry
## must zap a nearby hostile mob for damage on its turn.

const WARD_SENTRY_SCRIPT: Script = preload("res://src/actors/mobs/special/ward_sentry.gd")

class _FakeLevel extends RefCounted:
	var chars: Dictionary = {}          # pos -> Char
	var mobs: Array[Node] = []
	func find_char_at(p: int) -> Variant:
		return chars.get(p, null)
	func get_mobs() -> Array[Node]:
		return mobs
	func is_passable(_p: int) -> bool:
		return true
	func add_mob(mob: Variant) -> void:
		if mob is Mob:
			chars[(mob as Mob).pos] = mob
			mobs.append(mob)
	func remove_mob(mob: Variant) -> void:
		if mob is Mob:
			chars.erase((mob as Mob).pos)
			mobs.erase(mob)
	func add_enemy(mob: Mob) -> void:
		chars[mob.pos] = mob
		mobs.append(mob)

func run(t: Object) -> void:
	_test_zap_spawns_sentry(t)
	_test_sentry_zaps_nearby_enemy(t)
	_test_damage_range_matches_upstream(t)
	_test_concurrent_ward_cap(t)

func _make_wand(lvl: int) -> Object:
	var wand: Object = Wand.WandOfWarding.new()
	wand.level = lvl
	return wand

func _make_hero(floor: _FakeLevel) -> Char:
	var hero: Char = Char.new()
	hero.name = "Warder"
	hero.is_hero = true
	hero.is_alive = true
	hero.pos = 100
	hero.level = floor
	return hero

func _make_enemy(enemy_pos: int, enemy_hp: int) -> Mob:
	var m: Mob = Mob.new()
	m.mob_name = "Rat"
	m.mob_id = "rat"
	m.hp = enemy_hp
	m.hp_max = enemy_hp
	m.ht = enemy_hp
	m.is_alive = true
	m.pos = enemy_pos
	return m

func _sentries_on(floor: _FakeLevel) -> Array:
	var out: Array = []
	for node: Variant in floor.mobs:
		if node != null and node.get_script() == WARD_SENTRY_SCRIPT:
			out.append(node)
	return out

func _test_zap_spawns_sentry(t: Object) -> void:
	var floor := _FakeLevel.new()
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(0)
	var ward_pos: int = 105  # empty + passable

	wand.on_zap(hero, [ward_pos] as Array[int])

	var sentries: Array = _sentries_on(floor)
	t.check(sentries.size() == 1,
		"Warding conjures exactly one real WardSentry actor on the level")
	t.check(ward_pos in wand._sentry_positions,
		"Warding tracks the sentry's position")
	if sentries.size() == 1:
		var s: Variant = sentries[0]
		t.check(s.is_ally, "The sentry is allied to the hero")
		t.check(s.pos == ward_pos, "The sentry stands on the target cell")
		# Clean up the globally-registered turn actor.
		s._on_death(null)

	hero.free()

func _test_sentry_zaps_nearby_enemy(t: Object) -> void:
	var floor := _FakeLevel.new()
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(1)
	var ward_pos: int = 105

	wand.on_zap(hero, [ward_pos] as Array[int])
	var sentries: Array = _sentries_on(floor)
	t.check(sentries.size() == 1, "sentry spawned")
	var sentry: Variant = sentries[0]

	# Drop a hostile mob one cell from the sentry, within zap range.
	var foe: Mob = _make_enemy(ward_pos + 1, 40)
	foe.level = floor
	floor.add_enemy(foe)

	var before_hp: int = foe.hp
	sentry.act()
	t.check(foe.hp < before_hp,
		"The sentry zaps a nearby hostile mob for damage on its turn")

	sentry._on_death(null)
	foe.free()
	hero.free()

## Upstream Ward.damageRoll() rolls heroDamageIntRange(2 + wandLevel,
## 8 + 4 * wandLevel). Lock the port's sentry damage range to that formula.
func _test_damage_range_matches_upstream(t: Object) -> void:
	for lvl: int in [0, 1, 3, 5]:
		var wand: Object = _make_wand(lvl)
		var rng: Array = wand.get_damage(lvl)
		t.check(rng[0] == 2 + lvl,
			"Warding sentry min damage == 2 + level (lvl %d)" % lvl)
		t.check(rng[1] == 8 + 4 * lvl,
			"Warding sentry max damage == 8 + 4*level (lvl %d)" % lvl)

## Upstream allows a maximum of 2 + wandLevel concurrent wards. Placing beyond
## the cap must retire the oldest sentry so the live count never exceeds it.
func _test_concurrent_ward_cap(t: Object) -> void:
	var floor := _FakeLevel.new()
	var hero: Char = _make_hero(floor)
	var lvl: int = 1
	var wand: Object = _make_wand(lvl)
	var cap: int = 2 + lvl  # MAX_SENTRIES(2) + level

	# Place cap + 2 wards on distinct cells; only `cap` should remain live.
	for i: int in range(cap + 2):
		wand.on_zap(hero, [200 + i * 2] as Array[int])

	var live: Array = _sentries_on(floor)
	t.check(live.size() == cap,
		"Concurrent wards capped at 2 + level (%d), got %d" % [cap, live.size()])
	t.check(wand._sentry_positions.size() == cap,
		"Tracked sentry positions stay in sync with live count")

	for s: Variant in live:
		s._on_death(null)
	hero.free()
