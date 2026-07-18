class_name MagesStaff
extends MeleeWeapon
## The Mage's signature weapon: a tier-1 melee staff that holds an imbued Wand.
## The imbued wand can be zapped through the staff, letting the Mage cast spells
## while wielding it as a weapon. Mirrors SPD's MagesStaff, which starts imbued
## with the Wand of Magic Missile.

## The wand imbued into this staff. Never null after configure(); defaults to
## the Wand of Magic Missile for a freshly generated staff.
var imbued_wand: Wand = null

func _init() -> void:
	super._init()
	item_id = "mages_staff"
	item_name = "Mage's Staff"
	description = "This gnarled staff is the Mage's signature weapon. A wand " \
		+ "can be imbued into it, letting its magic be cast while the staff " \
		+ "is wielded as a melee weapon."
	tier = 1
	default_action = "ZAP"
	unique = true
	bones = false
	icon_color = Color(0.55, 0.4, 0.7)  # arcane violet

## Configure the staff with a default imbued wand (Wand of Magic Missile).
## Called by the generator branch after construction.
func configure_default() -> void:
	if imbued_wand == null:
		imbue_wand(Wand.create("wand_of_magic_missile"))

## Imbue a wand into the staff, replacing any existing one.
func imbue_wand(wand: Wand) -> void:
	imbued_wand = wand
	_sync_imbued_wand()

func _sync_imbued_wand() -> void:
	if imbued_wand == null:
		return
	imbued_wand.identify()
	imbued_wand.cursed = false
	imbued_wand.charges_max = mini(imbued_wand.charges_max + 1, 10)
	imbued_wand.charges = imbued_wand.charges_max

## Return the wand imbued into this staff (or null if none).
func get_imbued_wand() -> Variant:
	return imbued_wand

## Zap the imbued wand at a target position. Routed by the hero's zap path.
func zap(hero: Char, target_pos: int) -> void:
	if imbued_wand == null:
		return
	imbued_wand.zap(hero, target_pos)

func get_damage_range() -> Array[int]:
	var lvl: int = buffed_lvl()
	var base_min: int = tier + lvl
	var base_max: int = roundi(3.0 * float(tier + 1)) + lvl * (tier + 1)
	var dmg_multi: float = _augment_damage_multiplier()
	var final_min: int = maxi(1, roundi(float(base_min) * dmg_multi))
	var final_max: int = maxi(final_min, roundi(float(base_max) * dmg_multi))
	return [final_min, final_max] as Array[int]

func value() -> int:
	return 0

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	if imbued_wand != null and imbued_wand.has_method("serialize"):
		data["imbued_wand"] = imbued_wand.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	imbued_wand = null
	var wand_data: Variant = data.get("imbued_wand", null)
	if wand_data is Dictionary:
		var wand_id: String = (wand_data as Dictionary).get("item_id", "")
		if wand_id != "":
			var wand: Wand = Wand.create(wand_id)
			if wand != null:
				if wand.has_method("deserialize"):
					wand.deserialize(wand_data)
				imbued_wand = wand
