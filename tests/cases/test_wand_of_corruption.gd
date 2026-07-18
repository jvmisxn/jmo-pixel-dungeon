extends RefCounted
## WandOfCorruption fidelity: a successful corruption must turn the target into a
## real ally (Mob.is_ally, CorruptionBuff, no XP) that hunts hostile mobs instead
## of the hero — NOT merely apply an Amok buff with a bogus alignment string.
## Bosses cannot be corrupted.

class _FakeLevel extends RefCounted:
	var chars: Dictionary = {}          # pos -> Char
	var mobs: Array[Node] = []
	func find_char_at(p: int) -> Variant:
		return chars.get(p, null)
	func get_mobs() -> Array[Node]:
		return mobs
	func add(mob: Mob) -> void:
		chars[mob.pos] = mob
		mobs.append(mob)

func run(t: Object) -> void:
	_test_full_corruption_makes_ally(t)
	_test_ally_ignores_hero_and_hunts_mobs(t)
	_test_boss_cannot_be_corrupted(t)

func _make_wand(lvl: int) -> Object:
	var wand: Object = Wand.WandOfCorruption.new()
	wand.level = lvl
	return wand

func _make_mob(mob_pos: int, mob_hp: int) -> Mob:
	var m: Mob = Mob.new()
	m.mob_name = "Rat"
	m.mob_id = "rat"
	m.hp = mob_hp
	m.hp_max = mob_hp
	m.ht = mob_hp
	m.is_alive = true
	m.pos = mob_pos
	m.xp_value = 5
	return m

func _make_hero(floor: _FakeLevel) -> Char:
	var hero: Char = Char.new()
	hero.name = "Caster"
	hero.is_hero = true
	hero.is_alive = true
	hero.pos = 100
	hero.level = floor
	return hero

func _test_full_corruption_makes_ally(t: Object) -> void:
	var floor := _FakeLevel.new()
	var enemy: Mob = _make_mob(105, 5)  # low HP → easy to corrupt
	enemy.level = floor
	floor.add(enemy)
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(3)

	wand.on_zap(hero, [enemy.pos] as Array[int])

	t.check(enemy.is_ally, "Corruption flips the target to the hero's side (is_ally)")
	t.check(enemy.has_buff("Corruption"), "Corruption attaches the CorruptionBuff")
	t.check(not enemy.has_buff("Amok"),
		"Corruption no longer relies on a permanent Amok buff")
	t.check(enemy.xp_value == 0, "Corrupted mobs grant no XP")

	enemy.free()
	hero.free()

func _test_ally_ignores_hero_and_hunts_mobs(t: Object) -> void:
	var floor := _FakeLevel.new()
	var ally: Mob = _make_mob(105, 5)
	ally.level = floor
	floor.add(ally)
	# A second, still-hostile mob one cell away from the ally.
	var foe: Mob = _make_mob(106, 20)
	foe.level = floor
	floor.add(foe)
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(3)

	wand.on_zap(hero, [ally.pos] as Array[int])
	t.check(ally.is_ally, "target corrupted")

	# The ally shrugs off the hero's own damage.
	var before_hp: int = ally.hp
	ally.take_damage(999, hero)
	t.check(ally.hp == before_hp, "Corrupted ally is immune to the hero's damage")

	# The ally picks the hostile mob as its target, not the hero.
	var enemy_target: Mob = ally._find_nearest_enemy_mob()
	t.check(enemy_target == foe,
		"Corrupted ally hunts the nearest hostile mob")

	ally.free()
	foe.free()
	hero.free()

func _test_boss_cannot_be_corrupted(t: Object) -> void:
	var floor := _FakeLevel.new()
	var boss: Mob = _make_mob(105, 5)
	boss.mob_id = "goo"  # a BOSS_MOB_ID → is_boss() true
	boss.level = floor
	floor.add(boss)
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(5)

	wand.on_zap(hero, [boss.pos] as Array[int])

	t.check(not boss.is_ally, "Bosses cannot be corrupted (is_ally stays false)")
	t.check(not boss.has_buff("Corruption"), "Bosses receive no CorruptionBuff")

	boss.free()
	hero.free()
