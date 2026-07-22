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
	_test_boss_gets_doomed_not_corrupted(t)
	_test_full_hp_enemy_resists_and_is_debuffed(t)
	_test_debuffs_weaken_resistance(t)

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

func _make_injured_mob(mob_pos: int) -> Mob:
	# Low HP fraction (1/20) → resistance ≈ base 1, easily overcome by the wand.
	var m: Mob = _make_mob(mob_pos, 20)
	m.hp = 1
	return m

func _test_full_corruption_makes_ally(t: Object) -> void:
	var floor := _FakeLevel.new()
	var enemy: Mob = _make_injured_mob(105)  # low HP fraction → easy to corrupt
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
	var ally: Mob = _make_injured_mob(105)
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

func _test_boss_gets_doomed_not_corrupted(t: Object) -> void:
	# SPD: a corruption-immune target (bosses) that the wand overpowers receives
	# Doom instead of switching sides. Use a low-HP boss so power > resistance.
	var floor := _FakeLevel.new()
	var boss: Mob = _make_injured_mob(105)
	boss.mob_id = "goo"  # a BOSS_MOB_ID → is_boss() true
	boss.level = floor
	floor.add(boss)
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(5)

	wand.on_zap(hero, [boss.pos] as Array[int])

	t.check(not boss.is_ally, "Bosses cannot become allies (is_ally stays false)")
	t.check(not boss.has_buff("Corruption"), "Bosses receive no CorruptionBuff")
	t.check(boss.has_buff("Doom"), "An overpowered corruption-immune boss is doomed instead")

	boss.free()
	hero.free()

func _test_full_hp_enemy_resists_and_is_debuffed(t: Object) -> void:
	# At full HP resistance is base*(1+4)=5, above a low-level wand's power, so the
	# enemy is never corrupted outright — it receives a debuff instead.
	var floor := _FakeLevel.new()
	var enemy: Mob = _make_mob(105, 20)  # full HP → high resistance
	enemy.level = floor
	floor.add(enemy)
	var hero: Char = _make_hero(floor)
	var wand: Object = _make_wand(1)

	wand.on_zap(hero, [enemy.pos] as Array[int])

	t.check(not enemy.is_ally, "Full-HP enemy resists outright corruption")
	t.check(not enemy.has_buff("Corruption"), "Full-HP enemy gets no CorruptionBuff")
	# Some debuff (major or minor) must have landed from the applicable pools.
	var applied: bool = false
	for bid: String in ["Amok", "Slow", "Hex", "Paralysis",
			"Weakness", "Vulnerable", "Cripple", "Blindness", "Terror"]:
		if enemy.has_buff(bid):
			applied = true
			break
	t.check(applied, "A resisted corruption still lands a random debuff")

	enemy.free()
	hero.free()

func _test_debuffs_weaken_resistance(t: Object) -> void:
	# Existing debuffs cut resistance: an enemy that would resist at full HP can be
	# corrupted once enough major debuffs stack (each halves resistance).
	var floor := _FakeLevel.new()
	var enemy: Mob = _make_mob(105, 20)  # full HP: base resist 5
	enemy.level = floor
	floor.add(enemy)
	# Two major debuffs → resist *= 0.5 * 0.5 = 1.25.
	enemy.add_buff(Slow.new())
	enemy.add_buff(Hex.new())
	var hero: Char = _make_hero(floor)
	# Power at level 6 = 3 + 6/3 = 5 > 1.25 → corruption succeeds.
	var wand: Object = _make_wand(6)

	wand.on_zap(hero, [enemy.pos] as Array[int])

	t.check(enemy.is_ally, "Stacked major debuffs let the wand corrupt a full-HP enemy")
	t.check(enemy.has_buff("Corruption"), "Weakened resistance yields a real CorruptionBuff")

	enemy.free()
	hero.free()
