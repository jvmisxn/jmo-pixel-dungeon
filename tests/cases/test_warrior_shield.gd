extends RefCounted
## Warrior broken seal (SPD 3.1 BrokenSeal.WarriorShield): a hit that leaves
## the Warrior at or below half HP triggers a full seal shield before shield
## absorption, then a 150-turn cooldown; the shield fades 5 turns after combat
## with a proportional cooldown refund. Max shield = 3 + 2*tier + Iron Will.

func run(t: Object) -> void:
	_test_starting_loadout(t)
	_test_max_shield_formula(t)
	_test_activation_on_half_hp_hit(t)
	_test_no_activation_above_half(t)
	_test_no_activation_while_cooling(t)
	_test_hunger_never_triggers(t)
	_test_fade_after_combat_with_refund(t)
	_test_seal_transfers_on_armor_swap(t)
	_test_serialize_round_trip(t)

func _make_warrior() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.give_starting_items()
	hero.hp_max = 20
	hero.ht = 20
	hero.hp = 20
	return hero

func _shield(hero: Hero) -> WarriorShield:
	return hero.get_buff("WarriorShield") as WarriorShield

func _test_starting_loadout(t: Object) -> void:
	var hero := _make_warrior()
	var armor: Armor = hero.belongings.armor as Armor
	t.check(armor != null and armor.has_seal(), "Warrior starts with the seal on his cloth armor")
	t.check(_shield(hero) != null, "Warrior starts with the WarriorShield buff attached")
	hero.free()

func _test_max_shield_formula(t: Object) -> void:
	var hero := _make_warrior()
	var shield := _shield(hero)
	t.check(shield.max_shield() == 5, "Tier-1 armor seal max shield is 3 + 2*1 = 5")
	hero.talent_levels["warrior_iron_will"] = 2
	t.check(shield.max_shield() == 7, "Iron Will +2 raises max shield to 7")
	hero.talent_levels["warrior_iron_will"] = 0
	(hero.belongings.armor as Armor).tier = 5
	t.check(shield.max_shield() == 13, "Tier-5 armor seal max shield is 3 + 2*5 = 13")
	hero.free()

func _test_activation_on_half_hp_hit(t: Object) -> void:
	var hero := _make_warrior()
	var taken: int = hero.take_damage(15)
	var shield := _shield(hero)
	t.check(shield.is_cooling_down(), "A hit that would drop below half HP starts the cooldown")
	t.check(taken == 10, "The fresh 5-point shield absorbs part of the triggering hit (15 -> 10)")
	t.check(hero.hp == 10, "HP after the shielded hit is 20 - 10 = 10")
	t.check(shield.get_shielding() == 0, "The triggering hit consumed the whole shield")
	hero.free()

func _test_no_activation_above_half(t: Object) -> void:
	var hero := _make_warrior()
	hero.take_damage(3)
	var shield := _shield(hero)
	t.check(not shield.is_cooling_down(), "A light hit leaving HP above half does not trigger the seal")
	t.check(hero.hp == 17, "Light hit lands unshielded")
	hero.free()

func _test_no_activation_while_cooling(t: Object) -> void:
	var hero := _make_warrior()
	hero.take_damage(15)
	var shield := _shield(hero)
	var cd: int = shield.cooldown
	hero.take_damage(4)
	t.check(hero.hp == 6, "While cooling down a second hit lands unshielded")
	t.check(shield.cooldown == cd, "The second hit does not restart the cooldown")
	hero.free()

func _test_hunger_never_triggers(t: Object) -> void:
	var hero := _make_warrior()
	hero.hp = 8
	var hunger: Node = hero.get_buff("Hunger")
	hero.take_damage(2, hunger)
	t.check(not _shield(hero).is_cooling_down(), "Hunger damage never triggers the seal shield")
	hero.free()

func _test_fade_after_combat_with_refund(t: Object) -> void:
	var hero := _make_warrior()
	var shield := _shield(hero)
	shield.activate()
	t.check(shield.get_shielding() == 5 and shield.cooldown == 150, "Manual activation grants full shield + 150 cooldown")
	for i: int in range(5):
		shield.on_turn()
	t.check(shield.get_shielding() == 0, "Shield fades after 5 enemy-free turns")
	# 5 ticks: 150 -> 145, then a full-shield refund of 150 * (1.0 / 2) = 75.
	t.check(shield.cooldown == 70, "Untouched shield refunds half the cooldown (145 - 75 = 70)")
	hero.free()

func _test_seal_transfers_on_armor_swap(t: Object) -> void:
	var hero := _make_warrior()
	var new_armor: Item = Generator.create_item("leather_armor")
	var old: Item = hero.belongings.equip_armor(new_armor)
	t.check((new_armor as Armor).has_seal(), "The seal follows the newly equipped armor")
	t.check(not (old as Armor).has_seal(), "The old armor gives up the seal")
	t.check(_shield(hero).max_shield() == 7, "Max shield follows the new tier-2 armor (3 + 4 = 7)")
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var hero := _make_warrior()
	var shield := _shield(hero)
	shield.activate()
	shield.absorb_damage(2)
	shield.on_turn()
	var buff_data: Dictionary = shield.serialize()
	var restored := WarriorShield.new()
	restored.deserialize(buff_data)
	t.check(restored.shield_amount == 3 and restored.cooldown == shield.cooldown
		and restored.initial_shield == 5,
		"WarriorShield state survives a serialize round-trip")
	var armor_data: Dictionary = (hero.belongings.armor as Armor).serialize()
	var fresh: Item = Generator.create_item("cloth_armor")
	fresh.deserialize(armor_data)
	t.check((fresh as Armor).has_seal(), "Armor seal flag survives a serialize round-trip")
	hero.free()
