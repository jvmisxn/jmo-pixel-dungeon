extends RefCounted
## Grim enchant deferred-execute parity (SPD; backlog audit:S13).
## Verifies the port matches upstream Grim + Char.damage:
##   - proc has no RNG: damage passes through and a GrimTracker is attached
##     with maxChance = (0.5 + 0.05/level) * proc multiplier
##   - the execute roll happens in take_damage against post-hit HP, scaled by
##     missing-HP fraction squared; success deals the remaining HP
##   - a full-HP survivor can never be executed (chance is zero)
##   - bosses never receive a tracker (upstream BOSS property immunity)
##   - the tracker self-removes on its turn tick and is not persistent

func run(t: Object) -> void:
	_test_proc_attaches_tracker(t)
	_test_max_chance_scales_with_level(t)
	_test_boss_gets_no_tracker(t)
	_test_execute_kills_low_hp_survivor(t)
	_test_full_hp_survivor_never_executed(t)
	_test_tracker_self_removes(t)

## Enemy-side victim safe to kill headless: skips loot/XP/destroy on death.
class _TestVictim extends Mob:
	func _on_death(_source: Variant) -> void:
		pass

## Minimal weapon stand-in exposing only the level the proc reads.
class _StubWeapon extends RefCounted:
	var level: int = 0

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.name = "Attacker"
	hero.is_alive = true
	hero.hp_max = 100000
	hero.hp = 100000
	return hero

func _make_enemy(hp: int, ht: int) -> Mob:
	var m: Mob = _TestVictim.new()
	m.name = "Victim"
	m.hp_max = maxi(ht, 1)
	m.ht = maxi(ht, 1)
	m.hp = hp
	m.is_alive = true
	return m

func _ench() -> WeaponEnchantment:
	return WeaponEnchantment.create("grim")

func _test_proc_attaches_tracker(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(100, 100)

	var dmg: int = _ench().proc(null, hero, victim, 40)

	t.check(dmg == 40, "grim proc returns damage unmodified")
	var tracker: Node = victim.get_buff("GrimTracker")
	t.check(tracker != null, "grim proc attaches a GrimTracker to the defender")
	t.check(tracker != null and absf(float(tracker.max_chance) - 0.5) < 0.0001,
		"level-0 grim tracker carries the upstream 50% max chance")

	hero.free()
	victim.free()

func _test_max_chance_scales_with_level(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(100, 100)
	var weapon := _StubWeapon.new()
	weapon.level = 4

	_ench().proc(weapon, hero, victim, 10)

	var tracker: Node = victim.get_buff("GrimTracker")
	t.check(tracker != null and absf(float(tracker.max_chance) - 0.7) < 0.0001,
		"+4 weapon grim tracker carries 50% + 5%/level = 70% max chance")

	hero.free()
	victim.free()

func _test_boss_gets_no_tracker(t: Object) -> void:
	var hero: Hero = _make_hero()
	var boss: Mob = _TestVictim.new()
	boss.name = "Boss"
	boss.mob_id = "goo"
	boss.hp_max = 100
	boss.ht = 100
	boss.hp = 100
	boss.is_alive = true

	var dmg: int = _ench().proc(null, hero, boss, 25)

	t.check(dmg == 25, "grim proc vs a boss passes damage through")
	t.check(boss.get_buff("GrimTracker") == null,
		"bosses never receive a GrimTracker (BOSS grim immunity)")

	hero.free()
	boss.free()

func _test_execute_kills_low_hp_survivor(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(50, 100)

	# Force the roll deterministic: chance = max_chance * missing-fraction^2,
	# so an enormous max chance guarantees the execute for any hp < ht.
	var tracker := GrimTracker.new()
	tracker.max_chance = 1000000.0
	victim.add_buff(tracker)

	var actual: int = victim.take_damage(1, hero)

	t.check(not victim.is_alive, "guaranteed grim roll executes a wounded survivor")
	t.check(victim.hp <= 0, "grim execute drains the remaining HP")
	t.check(actual == 1 + 49, "returned damage includes the grim bonus (1 hit + 49 remaining)")

	hero.free()
	victim.free()

func _test_full_hp_survivor_never_executed(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(100, 100)

	var tracker := GrimTracker.new()
	tracker.max_chance = 1000000.0
	victim.add_buff(tracker)

	# Zero damage leaves the victim at full HP: missing fraction is 0, so the
	# quadratic curve zeroes the chance no matter how large max_chance is.
	victim.take_damage(0, hero)

	t.check(victim.is_alive and victim.hp == 100,
		"full-HP survivor is never grim-executed (quadratic curve hits zero)")

	hero.free()
	victim.free()

func _test_tracker_self_removes(t: Object) -> void:
	var victim: Mob = _make_enemy(100, 100)

	var tracker := GrimTracker.new()
	victim.add_buff(tracker)
	t.check(victim.get_buff("GrimTracker") != null, "tracker attached before tick")
	t.check(not tracker.is_persistent(), "grim tracker is never saved")

	tracker.on_turn()

	t.check(victim.get_buff("GrimTracker") == null, "grim tracker detaches on its turn tick")

	victim.free()
