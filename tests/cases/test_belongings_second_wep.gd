extends RefCounted
## Champion off-hand weapon slot (upstream Belongings.secondWep +
## KindOfWeapon.equipSecondary/doUnequip): equip_second_wep fills the slot
## independently of the primary weapon and returns the displaced weapon,
## unequip("second_wep") empties only the off-hand, uncurse_equipped covers
## the slot, and the slot serializes round-trip while old saves without the
## key read as empty.

func run(t: Object) -> void:
	_test_equip_and_swap(t)
	_test_unequip_second_only(t)
	_test_uncurse_covers_second_wep(t)
	_test_serialize_round_trip(t)
	_test_old_save_reads_empty(t)

func _test_equip_and_swap(t: Object) -> void:
	var belongings := Belongings.new()
	var sword: Item = Generator.create_item("sword")
	var dagger: Item = Generator.create_item("dagger")
	belongings.equip_weapon(sword)
	var displaced: Item = belongings.equip_second_wep(dagger)
	t.check(displaced == null, "Equipping an empty off-hand displaces nothing")
	t.check(belongings.second_wep == dagger, "Off-hand slot holds the dagger")
	t.check(belongings.weapon == sword, "Primary weapon is untouched")
	var mace: Item = Generator.create_item("mace")
	displaced = belongings.equip_second_wep(mace)
	t.check(displaced == dagger, "Equipping over the off-hand returns the old weapon")
	t.check(belongings.second_wep == mace, "Off-hand slot now holds the mace")

func _test_unequip_second_only(t: Object) -> void:
	var belongings := Belongings.new()
	var sword: Item = Generator.create_item("sword")
	var dagger: Item = Generator.create_item("dagger")
	belongings.equip_weapon(sword)
	belongings.equip_second_wep(dagger)
	var removed: Item = belongings.unequip("second_wep")
	t.check(removed == dagger, "unequip('second_wep') returns the off-hand weapon")
	t.check(belongings.second_wep == null, "Off-hand slot is empty after unequip")
	t.check(belongings.weapon == sword, "Primary weapon survives off-hand unequip")

func _test_uncurse_covers_second_wep(t: Object) -> void:
	var belongings := Belongings.new()
	var dagger: Item = Generator.create_item("dagger")
	dagger.cursed = true
	dagger.cursed_known = false
	belongings.equip_second_wep(dagger)
	var lifted: int = belongings.uncurse_equipped()
	t.check(lifted == 1, "uncurse_equipped lifts a cursed off-hand weapon")
	t.check(not dagger.cursed and dagger.cursed_known, "Off-hand curse is removed and known")

func _test_serialize_round_trip(t: Object) -> void:
	var belongings := Belongings.new()
	var sword: Item = Generator.create_item("sword")
	var dagger: Item = Generator.create_item("dagger")
	dagger.level = 2
	belongings.equip_weapon(sword)
	belongings.equip_second_wep(dagger)
	var data: Dictionary = belongings.serialize()
	t.check(data.has("second_wep"), "Serialized belongings carry the off-hand slot")
	var restored := Belongings.new()
	restored.deserialize(data)
	t.check(restored.second_wep != null, "Off-hand weapon restores on load")
	t.check(restored.second_wep != null and restored.second_wep.item_id == "dagger",
		"Restored off-hand weapon keeps its item id")
	t.check(restored.second_wep != null and restored.second_wep.level == 2,
		"Restored off-hand weapon keeps its upgrade level")
	t.check(restored.weapon != null and restored.weapon.item_id == "sword",
		"Primary weapon still restores alongside the off-hand")

func _test_old_save_reads_empty(t: Object) -> void:
	var belongings := Belongings.new()
	var sword: Item = Generator.create_item("sword")
	belongings.equip_weapon(sword)
	var data: Dictionary = belongings.serialize()
	data.erase("second_wep")
	var restored := Belongings.new()
	restored.deserialize(data)
	t.check(restored.second_wep == null, "Saves without the key read as an empty off-hand")
	t.check(restored.weapon != null, "Old-save primary weapon still restores")
