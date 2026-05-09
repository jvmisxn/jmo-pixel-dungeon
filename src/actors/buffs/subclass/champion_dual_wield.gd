class_name ChampionDualWield
extends Buff
## Champion (Duelist) subclass passive. Enables dual-wielding melee weapons.
## Alternates attacks between primary and secondary weapon.

## The secondary weapon equipped in the ring slot.
var secondary_weapon: Variant = null
## Which weapon attacks next: true = primary, false = secondary.
var primary_next: bool = true

func _init() -> void:
	buff_id = "ChampionDualWield"
	buff_name = "Dual Wield"
	duration = -1.0
	icon_color = Color(0.9, 0.6, 0.2)

## Equip a secondary weapon. Returns true if successful.
func equip_secondary(weapon: Variant) -> bool:
	if weapon == null:
		return false
	secondary_weapon = weapon
	if MessageLog:
		var wname: String = weapon.get("item_name") if weapon.get("item_name") else "weapon"
		MessageLog.add("You wield the %s in your off-hand." % wname)
	return true

func unequip_secondary() -> Variant:
	var old: Variant = secondary_weapon
	secondary_weapon = null
	return old

func on_damage_dealt(_amount: int, _target: Node) -> void:
	# Alternate weapons
	primary_next = not primary_next

## Get damage range for the current attacking weapon.
func get_current_weapon_damage() -> Array[int]:
	if primary_next or secondary_weapon == null:
		return []  # Use primary (normal path)
	# Use secondary weapon damage
	if secondary_weapon.has_method("get_damage_range"):
		return secondary_weapon.get_damage_range()
	return []

func modify_damage(dmg: int) -> int:
	# If secondary weapon is active and has damage, use its range instead
	if not primary_next and secondary_weapon != null:
		var sec_range: Array[int] = get_current_weapon_damage()
		if sec_range.size() >= 2:
			return randi_range(sec_range[0], sec_range[1])
	return dmg

func modify_armor(armor: int) -> int:
	# Both weapons contribute to defense (secondary adds 25% of its tier as armor)
	if secondary_weapon and secondary_weapon.get("tier"):
		armor += secondary_weapon.tier
	return armor

func description() -> String:
	if secondary_weapon:
		var wname: String = secondary_weapon.get("item_name") if secondary_weapon.get("item_name") else "?"
		var which: String = "primary" if primary_next else "secondary"
		return "Dual Wield (%s next, off-hand: %s)" % [which, wname]
	return "Dual Wield (no off-hand penalty when using two weapons)."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["primary_next"] = primary_next
	if secondary_weapon != null and secondary_weapon.has_method("serialize"):
		data["secondary_weapon"] = secondary_weapon.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	primary_next = bool(data.get("primary_next", primary_next))
	secondary_weapon = null
	var weapon_data: Variant = data.get("secondary_weapon", null)
	if not (weapon_data is Dictionary):
		return
	var item_data: Dictionary = weapon_data as Dictionary
	var item_id: String = str(item_data.get("item_id", ""))
	if item_id == "":
		return
	var restored_weapon: Variant = Generator.create_item(item_id)
	if restored_weapon != null and restored_weapon.has_method("deserialize"):
		restored_weapon.deserialize(item_data)
		secondary_weapon = restored_weapon
