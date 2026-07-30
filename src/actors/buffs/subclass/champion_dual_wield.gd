class_name ChampionDualWield
extends Buff
## LEGACY MIGRATION SHIM. The old Champion passive alternated damage between a
## primary weapon and a secondary weapon stored inside this buff. Upstream has
## no such passive: the Champion keeps a stowed second weapon in
## Belongings.secondWep, always attacks with the primary, and swaps/uses
## abilities from either weapon. This class only survives so old saves that
## still carry the buff can migrate their stored off-hand weapon into
## Belongings.second_wep, then the buff removes itself.

## Off-hand weapon carried by the legacy buff (restored from old saves).
var secondary_weapon: Variant = null

func _init() -> void:
	buff_id = "ChampionDualWield"
	buff_name = "Dual Wield (legacy)"
	duration = -1.0
	show_in_ui = false

func on_attach() -> void:
	_migrate_secondary()
	if target != null and target.has_method("remove_buff"):
		target.call_deferred("remove_buff", self)

## Move the buff-held off-hand weapon into the real second_wep slot
## (or the backpack if that slot is already taken).
func _migrate_secondary() -> void:
	if secondary_weapon == null or target == null:
		return
	var belongings: Variant = target.get("belongings")
	if belongings == null:
		secondary_weapon = null
		return
	if belongings.second_wep == null:
		belongings.equip_second_wep(secondary_weapon)
	else:
		belongings.add_item(secondary_weapon)
	secondary_weapon = null

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
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
