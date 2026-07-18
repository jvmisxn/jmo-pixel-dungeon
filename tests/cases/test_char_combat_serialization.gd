extends RefCounted

func run(t: Object) -> void:
	var hero := Hero.new()
	hero.hp = 13
	hero.hp_max = 31
	hero.ht = 31
	hero.shielding = 7
	hero.str_val = 12
	hero.base_speed = 1.25
	hero.attack_skill = 15
	hero.defense_skill = 9
	hero.damage_roll_min = 2
	hero.damage_roll_max = 8
	hero.armor_value = 3
	hero.flying = true
	hero.invisible = 2
	hero.paralysed = 1

	var hero_copy := Hero.new()
	hero_copy.deserialize(hero.serialize())
	_assert_combat_state(t, hero_copy, "hero")

	var mob := Mob.new()
	mob.hp = 13
	mob.hp_max = 31
	mob.ht = 31
	mob.shielding = 7
	mob.str_val = 12
	mob.base_speed = 1.25
	mob.attack_skill = 15
	mob.defense_skill = 9
	mob.damage_roll_min = 2
	mob.damage_roll_max = 8
	mob.armor_value = 3
	mob.flying = true
	mob.invisible = 2
	mob.paralysed = 1

	var mob_copy := Mob.new()
	mob_copy.deserialize(mob.serialize())
	_assert_combat_state(t, mob_copy, "mob")

	hero.free()
	hero_copy.free()
	mob.free()
	mob_copy.free()

func _assert_combat_state(t: Object, ch: Char, label: String) -> void:
	t.check(ch.hp == 13, "%s combat serializer restores hp" % label)
	t.check(ch.hp_max == 31, "%s combat serializer restores hp_max" % label)
	t.check(ch.ht == 31, "%s combat serializer restores ht" % label)
	t.check(ch.shielding == 7, "%s combat serializer restores flat shielding" % label)
	t.check(ch.str_val == 12, "%s combat serializer restores str" % label)
	t.check(is_equal_approx(ch.base_speed, 1.25), "%s combat serializer restores base speed" % label)
	t.check(ch.attack_skill == 15, "%s combat serializer restores attack skill" % label)
	t.check(ch.defense_skill == 9, "%s combat serializer restores defense skill" % label)
	t.check(ch.damage_roll_min == 2, "%s combat serializer restores damage min" % label)
	t.check(ch.damage_roll_max == 8, "%s combat serializer restores damage max" % label)
	t.check(ch.armor_value == 3, "%s combat serializer restores armor" % label)
	t.check(ch.flying, "%s combat serializer restores flying" % label)
	t.check(ch.invisible == 2, "%s combat serializer restores invisible turns" % label)
	t.check(ch.paralysed == 1, "%s combat serializer restores paralysis counter" % label)
