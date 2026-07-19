extends RefCounted

func run(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.damage_roll_min = 10
	hero.damage_roll_max = 10
	hero.attack_skill = 1000000
	SubclassAbilities.apply_subclass(hero, ConstantsData.HeroSubclass.GLADIATOR)

	var combo: GladiatorCombo = hero.get_buff("GladiatorCombo") as GladiatorCombo
	t.check(combo != null, "Gladiator subclass applies the combo tracker buff")
	t.check(hero.hero_subclass == ConstantsData.HeroSubclass.GLADIATOR, "Gladiator subclass is recorded on the hero")

	var defender := Char.new()
	defender.hp = 100
	defender.hp_max = 100
	defender.defense_skill = 0

	t.check(hero.attack(defender), "first Gladiator melee attack lands")
	t.check(combo.combo_count == 1, "first landed melee hit starts the combo")
	t.check(defender.hp == 90, "first combo hit deals base deterministic damage")

	t.check(hero.attack(defender), "second Gladiator melee attack lands")
	t.check(combo.combo_count == 2, "second landed melee hit advances the combo")

	t.check(hero.attack(defender), "third Gladiator melee attack lands")
	t.check(combo.combo_count == 3, "third landed melee hit reaches finisher threshold")
	t.check(defender.hp == 70, "third combo hit still deals base damage before the finisher")

	t.check(hero.attack(defender), "fourth Gladiator melee attack lands")
	t.check(defender.hp == 55, "Gladiator finisher consumes the built combo for boosted damage")
	t.check(combo.combo_count == 1, "finisher attack starts the next combo chain")

	var serialized: Dictionary = combo.serialize()
	var restored := GladiatorCombo.new()
	restored.deserialize(serialized)
	t.check(restored.combo_count == combo.combo_count, "Gladiator combo count survives serialization")
	t.check(restored.turns_since_attack == combo.turns_since_attack, "Gladiator combo timeout survives serialization")

	defender.free()
	hero.free()
