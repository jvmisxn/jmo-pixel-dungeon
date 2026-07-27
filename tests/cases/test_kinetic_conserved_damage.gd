extends RefCounted
## Kinetic enchant conserved-damage parity (SPD; backlog audit:S13).
## Verifies the port matches upstream Kinetic + Char.damage:
##   - proc has no RNG: damage passes through unmodified when nothing is stored
##   - a killing hit banks the overkill (-HP) on the attacker as ConservedDamage
##   - the recycled conserved bonus in a hit is subtracted before re-banking
##   - the next Kinetic proc consumes the stored bonus (buff detaches)
##   - non-lethal hits bank nothing; ally-side victims bank nothing
##   - ConservedDamage decays 2.5%/turn (min 0.1) and expires at zero

func run(t: Object) -> void:
	_test_proc_passthrough_no_store(t)
	_test_overkill_banked_on_kill(t)
	_test_recycled_bonus_not_rebanked(t)
	_test_next_proc_consumes_bonus(t)
	_test_no_bank_without_overkill(t)
	_test_ally_victim_banks_nothing(t)
	_test_conserved_decay(t)

## Enemy-side victim safe to kill headless: skips loot/XP/destroy on death.
class _TestVictim extends Mob:
	func _on_death(_source: Variant) -> void:
		pass

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.name = "Attacker"
	hero.is_alive = true
	hero.hp_max = 100000
	hero.hp = 100000
	return hero

func _make_enemy(hp: int) -> Mob:
	var m: Mob = _TestVictim.new()
	m.name = "Victim"
	m.hp_max = maxi(hp, 1)
	m.hp = hp
	m.is_alive = true
	return m

func _ench() -> WeaponEnchantment:
	return WeaponEnchantment.create("kinetic")

func _test_proc_passthrough_no_store(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(100)

	var dmg: int = _ench().proc(null, hero, victim, 40)

	t.check(dmg == 40, "kinetic proc with nothing stored returns damage unmodified")
	var tracker: Node = hero.get_buff("KineticTracker")
	t.check(tracker != null and int(tracker.conserved_damage) == 0,
		"proc attaches a KineticTracker with zero recycled damage")

	hero.free()
	victim.free()

func _test_overkill_banked_on_kill(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(10)

	var dmg: int = _ench().proc(null, hero, victim, 40)
	victim.take_damage(dmg, hero)

	t.check(not victim.is_alive, "victim dies to the overkill hit")
	var cd: Node = hero.get_buff("ConservedDamage")
	t.check(cd != null and cd.damage_bonus() == 30,
		"overkill 40-10=30 is banked on the attacker as ConservedDamage")
	t.check(hero.get_buff("KineticTracker") == null,
		"the tracker detaches once the overkill is banked")

	hero.free()
	victim.free()

func _test_recycled_bonus_not_rebanked(t: Object) -> void:
	var hero: Hero = _make_hero()
	var stored := ConservedDamage.new()
	stored.set_bonus(30)
	hero.add_buff(stored)
	var victim: Mob = _make_enemy(10)

	# proc: 40 base + 30 recycled = 70; kill leaves -HP = 60 but only
	# 60 - 30 (recycled) = 30 may be re-banked.
	var dmg: int = _ench().proc(null, hero, victim, 40)
	t.check(dmg == 70, "stored bonus is added to the proc damage")
	victim.take_damage(dmg, hero)

	var cd: Node = hero.get_buff("ConservedDamage")
	t.check(cd != null and cd.damage_bonus() == 30,
		"re-banked overkill excludes the recycled conserved bonus")

	hero.free()
	victim.free()

func _test_next_proc_consumes_bonus(t: Object) -> void:
	var hero: Hero = _make_hero()
	var stored := ConservedDamage.new()
	stored.set_bonus(25)
	hero.add_buff(stored)
	var victim: Mob = _make_enemy(1000)

	var dmg: int = _ench().proc(null, hero, victim, 40)

	t.check(dmg == 65, "next kinetic proc adds the stored 25 bonus")
	t.check(hero.get_buff("ConservedDamage") == null,
		"ConservedDamage detaches when consumed")

	hero.free()
	victim.free()

func _test_no_bank_without_overkill(t: Object) -> void:
	var hero: Hero = _make_hero()
	var victim: Mob = _make_enemy(100)

	var dmg: int = _ench().proc(null, hero, victim, 40)
	victim.take_damage(dmg, hero)

	t.check(victim.is_alive and victim.hp == 60, "non-lethal hit lands normally")
	t.check(hero.get_buff("ConservedDamage") == null,
		"non-lethal hit banks no conserved damage")

	hero.free()
	victim.free()

func _test_ally_victim_banks_nothing(t: Object) -> void:
	# Upstream gates banking on the victim's ENEMY alignment. A plain Char
	# (hero-side/neutral stand-in with no is_ally flag) killed with a tracker
	# attached must bank nothing. (Ally Mobs are immune to hero damage
	# entirely, so the gate is exercised via the neutral victim.)
	var hero: Hero = _make_hero()
	var victim := Char.new()
	victim.name = "Neutral"
	victim.hp_max = 10
	victim.hp = 10
	victim.is_alive = true

	var dmg: int = _ench().proc(null, hero, victim, 40)
	victim.take_damage(dmg, hero)

	t.check(not victim.is_alive, "neutral victim still dies to the hit")
	t.check(hero.get_buff("ConservedDamage") == null,
		"killing a non-enemy-side victim banks no conserved damage")

	hero.free()
	victim.free()

func _test_conserved_decay(t: Object) -> void:
	var hero: Hero = _make_hero()
	var cd := ConservedDamage.new()
	cd.set_bonus(40)
	hero.add_buff(cd)

	# Upstream: preserved -= max(preserved * 0.025, 0.1) each turn.
	cd.on_turn()
	t.check(cd.damage_bonus() == 39, "40 stored decays by 1 (2.5%) on the first turn")

	cd.set_bonus(2)
	cd.on_turn()
	t.check(is_equal_approx(cd.preserved_damage, 1.9),
		"small values decay by the 0.1 floor per turn")

	cd.set_bonus(0)
	cd.preserved_damage = 0.05
	cd.on_turn()
	t.check(hero.get_buff("ConservedDamage") == null,
		"the buff detaches when the stored damage runs out")

	hero.free()
