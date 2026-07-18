extends RefCounted
## Verifies the Mage's Staff imbued-wand slice: generator construction, the
## imbued Wand of Magic Missile default, the hero zap route for held items that
## expose zap(), serialize/deserialize round-trips, and the Mage starting kit.

func run(t: Object) -> void:
	_check_generator_default_imbue(t)
	_check_zap_route(t)
	_check_staff_round_trip(t)
	_check_belongings_round_trip(t)
	_check_mage_starting_kit(t)

func _check_generator_default_imbue(t: Object) -> void:
	var staff: Variant = Generator.create_item("mages_staff")
	t.check(staff is MagesStaff, "Generator.create_item('mages_staff') yields a MagesStaff")
	t.check(staff.item_id == "mages_staff", "staff item_id is mages_staff")
	t.check(staff.default_action == "ZAP", "staff defaults to zap like SPD")
	t.check(staff.unique, "staff is unique like SPD")
	t.check(not staff.bones, "staff is excluded from bones like SPD")
	t.check(staff.value() == 0, "staff has zero sale value like SPD")
	t.check(staff.get_damage_range() == [1, 6], "staff uses SPD's reduced tier-1 melee max")
	var wand: Variant = staff.get_imbued_wand()
	t.check(wand is Wand, "staff imbued with a Wand by default")
	t.check(wand != null and wand.item_id == "wand_of_magic_missile",
		"default imbued wand is Wand of Magic Missile")
	t.check(wand != null and wand.is_identified(), "default imbued wand is identified")
	t.check(wand != null and not wand.cursed, "default imbued wand is uncursed")
	t.check(wand != null and wand.charges_max == 3,
		"default imbued Magic Missile has the staff's extra max charge")
	t.check(wand != null and wand.charges == wand.charges_max,
		"default imbued wand starts fully charged")

func _check_zap_route(t: Object) -> void:
	var hero := Hero.new()
	hero.pos = 0
	var staff := Generator.create_item("mages_staff") as MagesStaff
	hero.belongings.equip_weapon(staff)
	var wand: Wand = staff.get_imbued_wand()
	var before: int = wand.charges
	t.check(before > 0, "imbued wand starts with charges")
	# Equipped staff (not in backpack) should still be an accepted zap source.
	hero._do_zap_wand(staff, 50)
	t.check(wand.charges == before - 1, "zapping the staff spends an imbued-wand charge")

func _check_staff_round_trip(t: Object) -> void:
	var staff := Generator.create_item("mages_staff") as MagesStaff
	var wand: Wand = staff.get_imbued_wand()
	wand.charges = 1
	wand.level = 2
	wand._update_max_charges()
	var data: Dictionary = staff.serialize()
	var restored := Generator.create_item("mages_staff") as MagesStaff
	restored.deserialize(data)
	var rwand: Variant = restored.get_imbued_wand()
	t.check(rwand != null, "restored staff still has an imbued wand")
	t.check(rwand.item_id == "wand_of_magic_missile", "restored wand id persisted")
	t.check(rwand.charges == 1, "restored wand charges persisted")
	t.check(rwand.level == 2, "restored wand level persisted")

func _check_belongings_round_trip(t: Object) -> void:
	var hero := Hero.new()
	var staff := Generator.create_item("mages_staff") as MagesStaff
	staff.get_imbued_wand().charges = 1
	hero.belongings.equip_weapon(staff)
	var data: Dictionary = hero.belongings.serialize()
	var hero2 := Hero.new()
	hero2.belongings.deserialize(data)
	var w2: Variant = hero2.belongings.weapon
	t.check(w2 is MagesStaff, "equipped staff round-trips through belongings")
	t.check(w2.get_imbued_wand() != null
		and w2.get_imbued_wand().item_id == "wand_of_magic_missile",
		"belongings round-trip preserves imbued wand id")
	t.check(w2.get_imbued_wand().charges == 1,
		"belongings round-trip preserves imbued wand charges")

func _check_mage_starting_kit(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.give_starting_items()
	var weapon: Variant = hero.belongings.weapon
	t.check(weapon is MagesStaff, "Mage starts with a Mage's Staff")
	t.check(weapon != null and weapon.get_imbued_wand() != null
		and weapon.get_imbued_wand().item_id == "wand_of_magic_missile",
		"Mage's starting staff holds the Wand of Magic Missile")
