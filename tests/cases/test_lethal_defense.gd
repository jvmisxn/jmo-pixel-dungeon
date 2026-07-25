extends RefCounted
## Gladiator Lethal Defense talent (upstream Talent.LETHAL_DEFENSE): killing an
## enemy with a combo finisher reduces the broken seal shield cooldown by
## 50/100/150 turns, floored at -150 (upstream Combo.doAttack calls
## Buff.affect(hero, WarriorShield).reduceCooldown(points/3) where
## reduceCooldown subtracts COOLDOWN_START*percentage down to -COOLDOWN_START).

func run(t: Object) -> void:
	_test_reduce_cooldown_math(t)
	_test_finisher_kill_reduces_cooldown(t)
	_test_finisher_kill_attaches_shield_buff(t)
	_test_points_scale_reduction(t)
	_test_no_talent_no_effect(t)
	_test_non_kill_finisher_no_effect(t)
	_test_kill_without_finisher_no_effect(t)
	_test_negative_cooldown_makes_activation_instant(t)

func _make_gladiator(lethal_points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_subclass = ConstantsData.HeroSubclass.GLADIATOR
	if lethal_points > 0:
		hero.talent_levels["gladiator_lethal_defense"] = lethal_points
	var combo := GladiatorCombo.new()
	hero.add_buff(combo)
	return hero

func _combo(hero: Hero) -> GladiatorCombo:
	return hero.get_buff("GladiatorCombo") as GladiatorCombo

func _make_victim(alive: bool) -> Char:
	var victim := Char.new()
	victim.is_alive = alive
	return victim

## Drive a finisher hit: build the combo to 3, consume it via modify_damage
## (the finisher path), then report the hit result like Char.attack does.
func _finisher_hit(combo: GladiatorCombo, victim: Char) -> void:
	var live := Char.new()
	live.is_alive = true
	combo.on_damage_dealt(5, live)
	combo.on_damage_dealt(5, live)
	combo.on_damage_dealt(5, live)
	combo.modify_damage(10)
	combo.on_damage_dealt(15, victim)
	live.free()

func _test_reduce_cooldown_math(t: Object) -> void:
	var shield := WarriorShield.new()
	shield.cooldown = 150
	shield.reduce_cooldown(50)
	t.check(shield.cooldown == 100, "reduce_cooldown subtracts turns from a running cooldown")
	shield.reduce_cooldown(300)
	t.check(
		shield.cooldown == -WarriorShield.COOLDOWN_START,
		"reduce_cooldown floors at -150 like upstream"
	)
	shield.free()

func _test_finisher_kill_reduces_cooldown(t: Object) -> void:
	var hero := _make_gladiator(1)
	var shield := WarriorShield.new()
	hero.add_buff(shield)
	shield.cooldown = 150
	var victim := _make_victim(false)
	_finisher_hit(_combo(hero), victim)
	t.check(shield.cooldown == 100, "Finisher kill at +1 reduces the seal cooldown by 50 turns")
	victim.free()
	hero.free()

func _test_finisher_kill_attaches_shield_buff(t: Object) -> void:
	var hero := _make_gladiator(2)
	t.check(
		hero.get_buff("WarriorShield") == null,
		"Precondition: no shield buff before the finisher kill"
	)
	var victim := _make_victim(false)
	_finisher_hit(_combo(hero), victim)
	var shield: Node = hero.get_buff("WarriorShield")
	t.check(shield != null, "Finisher kill attaches WarriorShield when absent (upstream Buff.affect)")
	if shield != null:
		t.check(
			int(shield.get("cooldown")) == -100,
			"Freshly attached shield carries the -100 cooldown credit at +2"
		)
	victim.free()
	hero.free()

func _test_points_scale_reduction(t: Object) -> void:
	var hero := _make_gladiator(3)
	var shield := WarriorShield.new()
	hero.add_buff(shield)
	shield.cooldown = 150
	var victim := _make_victim(false)
	_finisher_hit(_combo(hero), victim)
	t.check(shield.cooldown == 0, "Finisher kill at +3 reduces the seal cooldown by 150 turns")
	victim.free()
	hero.free()

func _test_no_talent_no_effect(t: Object) -> void:
	var hero := _make_gladiator(0)
	var victim := _make_victim(false)
	_finisher_hit(_combo(hero), victim)
	t.check(
		hero.get_buff("WarriorShield") == null,
		"Without the talent a finisher kill attaches no shield buff"
	)
	victim.free()
	hero.free()

func _test_non_kill_finisher_no_effect(t: Object) -> void:
	var hero := _make_gladiator(3)
	var shield := WarriorShield.new()
	hero.add_buff(shield)
	shield.cooldown = 150
	var combo := _combo(hero)
	var survivor := _make_victim(true)
	_finisher_hit(combo, survivor)
	t.check(shield.cooldown == 150, "A finisher that does not kill leaves the cooldown unchanged")
	t.check(not combo._finisher_this_hit, "Finisher flag clears after the hit resolves")
	survivor.free()
	hero.free()

func _test_kill_without_finisher_no_effect(t: Object) -> void:
	var hero := _make_gladiator(3)
	var shield := WarriorShield.new()
	hero.add_buff(shield)
	shield.cooldown = 150
	var victim := _make_victim(false)
	# Plain killing hit: no modify_damage finisher consumption first.
	_combo(hero).on_damage_dealt(5, victim)
	t.check(shield.cooldown == 150, "A non-finisher kill leaves the cooldown unchanged")
	victim.free()
	hero.free()

func _test_negative_cooldown_makes_activation_instant(t: Object) -> void:
	var shield := WarriorShield.new()
	shield.cooldown = -WarriorShield.COOLDOWN_START
	shield.activate()
	t.check(
		shield.cooldown == 0,
		"Activating with -150 banked leaves the shield immediately available again"
	)
	shield.free()
