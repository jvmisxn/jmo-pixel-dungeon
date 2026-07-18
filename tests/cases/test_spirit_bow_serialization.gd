extends RefCounted
## Regression for audit:S13 — SpiritBow.deserialize() used to be a no-op `pass`,
## silently discarding the saved payload so the Huntress's bow lost its upgrade
## level / augment / enchantment / curse+id flags on every load. The bow carries
## no state of its own beyond the shared Weapon/Item base, so deserialize() must
## chain super.deserialize(data). These checks pin the save->create->load path
## (mirroring how Belongings rebuilds an equipped item) end to end.

func run(t: Object) -> void:
	_check_direct_round_trip(t)
	_check_augment_and_enchant_round_trip(t)
	_check_curse_and_id_flags_round_trip(t)
	_check_belongings_round_trip(t)
	_check_huntress_starting_kit_round_trip(t)

## The core regression: an upgraded bow's level must survive
## serialize -> Generator.create_item('spirit_bow') -> deserialize.
func _check_direct_round_trip(t: Object) -> void:
	var bow := Generator.create_item("spirit_bow") as SpiritBow
	t.check(bow != null, "Generator.create_item('spirit_bow') yields a SpiritBow")
	bow.level = 4
	bow.level_known = true
	var expected_max: int = bow.get_damage_range_for_level(1)[1]

	var data: Dictionary = bow.serialize()
	t.check(data.get("is_spirit_bow", false), "serialize marks the payload is_spirit_bow")

	var restored := Generator.create_item("spirit_bow") as SpiritBow
	restored.deserialize(data)
	t.check(restored.level == 4, "restored bow preserves upgrade level (was lost when deserialize was a no-op)")
	t.check(restored.level_known, "restored bow preserves level_known")
	t.check(restored.get_damage_range_for_level(1)[1] == expected_max,
		"restored bow reproduces the upgraded damage range")

## Augment and enchantment live on the Weapon base and must round-trip too.
func _check_augment_and_enchant_round_trip(t: Object) -> void:
	var bow := Generator.create_item("spirit_bow") as SpiritBow
	bow.apply_augment(Weapon.Augment.DAMAGE)
	bow.enchant(WeaponEnchantment.create("blazing"))

	var restored := Generator.create_item("spirit_bow") as SpiritBow
	restored.deserialize(bow.serialize())
	t.check(restored.augment == Weapon.Augment.DAMAGE, "restored bow preserves its augment")
	t.check(restored.enchantment != null, "restored bow keeps its enchantment")
	t.check(restored.enchantment != null and restored.enchantment.enchant_id == "blazing",
		"restored bow preserves the enchantment id")

## Curse and identification flags must persist (the bow self-IDs on equip, but a
## saved-then-loaded bow should not silently reset to un-IDed/uncursed).
func _check_curse_and_id_flags_round_trip(t: Object) -> void:
	var bow := Generator.create_item("spirit_bow") as SpiritBow
	bow.cursed = true
	bow.cursed_known = true
	bow.identified = true

	var restored := Generator.create_item("spirit_bow") as SpiritBow
	restored.deserialize(bow.serialize())
	t.check(restored.cursed, "restored bow preserves cursed flag")
	t.check(restored.cursed_known, "restored bow preserves cursed_known flag")
	t.check(restored.identified, "restored bow preserves identified flag")

## The equipped spirit_bow slot must survive a full Belongings round-trip, which
## is the actual load path (Generator.create_item + per-item deserialize).
func _check_belongings_round_trip(t: Object) -> void:
	var hero := Hero.new()
	var bow := Generator.create_item("spirit_bow") as SpiritBow
	bow.level = 3
	bow.apply_augment(Weapon.Augment.SPEED)
	hero.belongings.equip_spirit_bow(bow)

	var data: Dictionary = hero.belongings.serialize()
	var hero2 := Hero.new()
	hero2.belongings.deserialize(data)
	var restored: Variant = hero2.belongings.get_equipped_spirit_bow()
	t.check(restored is SpiritBow, "equipped spirit bow round-trips through belongings")
	t.check(restored != null and restored.level == 3,
		"belongings round-trip preserves the bow's upgrade level")
	t.check(restored != null and restored.augment == Weapon.Augment.SPEED,
		"belongings round-trip preserves the bow's augment")

## End-to-end via the Huntress starting kit: upgrade the granted bow, save the
## whole belongings, reload, and confirm the level survives.
func _check_huntress_starting_kit_round_trip(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.give_starting_items()
	var bow: Variant = hero.belongings.get_equipped_spirit_bow()
	t.check(bow is SpiritBow, "Huntress starts with an equipped Spirit Bow")
	bow.level = 5

	var data: Dictionary = hero.belongings.serialize()
	var hero2 := Hero.new()
	hero2.belongings.deserialize(data)
	var restored: Variant = hero2.belongings.get_equipped_spirit_bow()
	t.check(restored is SpiritBow and restored.level == 5,
		"Huntress's upgraded Spirit Bow survives a save/load cycle")
