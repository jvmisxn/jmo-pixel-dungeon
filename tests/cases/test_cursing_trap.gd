extends RefCounted
## CursingTrap should curse equipped gear instead of always falling back to Hex.

func run(t: Object) -> void:
	_check_curses_unenchanted_weapon(t)
	_check_preserves_existing_weapon_enchantment(t)
	_check_can_curse_armor(t)
	_check_skips_mages_staff(t)
	_check_hex_fallback_without_equipment(t)

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	return hero

func _activate_on(hero: Hero) -> void:
	var trap := CursingTrap.new()
	trap.set_pos(ConstantsData.xy_to_pos(10, 10))
	trap.activate(hero, _make_level())

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 7
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _check_curses_unenchanted_weapon(t: Object) -> void:
	seed(0xC012)
	var hero: Hero = _make_hero()
	var weapon: Weapon = MeleeWeapon.create("worn_shortsword")
	hero.belongings.equip_weapon(weapon)

	_activate_on(hero)

	t.check(weapon.cursed, "cursing trap curses an equipped weapon")
	t.check(weapon.cursed_known, "cursing trap reveals the equipped weapon curse")
	t.check(weapon.enchantment != null, "cursing trap adds a curse enchantment to bare weapons")
	t.check(
		weapon.enchantment != null and weapon.enchantment.is_curse,
		"cursing trap weapon enchantment is a curse"
	)
	t.check(hero.get_buff("Hex") == null, "cursing trap does not Hex when it cursed equipment")
	hero.free()

func _check_preserves_existing_weapon_enchantment(t: Object) -> void:
	seed(0xC013)
	var hero: Hero = _make_hero()
	var weapon: Weapon = MeleeWeapon.create("worn_shortsword")
	var blazing: WeaponEnchantment = WeaponEnchantment.create("blazing")
	weapon.enchant(blazing)
	hero.belongings.equip_weapon(weapon)

	_activate_on(hero)

	t.check(weapon.cursed, "cursing trap can curse an already-enchanted weapon")
	t.check(weapon.enchantment == blazing, "cursing trap preserves existing weapon enchantments")
	hero.free()

func _check_can_curse_armor(t: Object) -> void:
	seed(0xC014)
	var hero: Hero = _make_hero()
	var armor: Armor = Armor.create("cloth_armor")
	hero.belongings.equip_armor(armor)

	_activate_on(hero)

	t.check(armor.cursed, "cursing trap curses equipped armor")
	t.check(armor.cursed_known, "cursing trap reveals the equipped armor curse")
	t.check(hero.get_buff("Hex") == null, "cursing trap does not Hex after cursing armor")
	hero.free()

func _check_skips_mages_staff(t: Object) -> void:
	seed(0xC015)
	var hero: Hero = _make_hero()
	var staff: MagesStaff = Generator.create_item("mages_staff") as MagesStaff
	var armor: Armor = Armor.create("cloth_armor")
	hero.belongings.equip_weapon(staff)
	hero.belongings.equip_armor(armor)

	_activate_on(hero)

	t.check(not staff.cursed, "cursing trap does not curse the Mage's Staff")
	t.check(staff.enchantment == null, "cursing trap does not add a curse enchantment to the Mage's Staff")
	t.check(armor.cursed, "cursing trap still curses armor when Mage's Staff is equipped")
	hero.free()

func _check_hex_fallback_without_equipment(t: Object) -> void:
	var hero: Hero = _make_hero()

	_activate_on(hero)

	t.check(hero.get_buff("Hex") != null, "cursing trap still Hexes targets with no curseable gear")
	hero.free()
