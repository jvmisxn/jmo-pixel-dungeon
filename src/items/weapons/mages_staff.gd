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

## Player-facing IMBUE flow (upstream MagesStaff.imbueWand): replace the
## current wand with a new one selected from the backpack. Level sync rule:
## target = max(staff, wand) true level, +1 extra when the wand overrides a
## staff that already has upgrades. Old staff charges carry into the new wand
## (capped at its max). Mage Wand Preservation: while the hero's
## WandPreservationCounter is 0, the replaced wand is returned to the backpack
## at +0 instead of being consumed (dropped if the pack is full).
## Upstream spends no time for this action.
func imbue_new_wand(hero: Char, new_wand: Wand) -> void:
	if new_wand == null:
		return
	var old_staff_charges: int = imbued_wand.charges if imbued_wand != null else 0
	var old_wand: Wand = imbued_wand
	if hero != null and old_wand != null and hero.has_method("get_talent_level") \
			and hero.get_talent_level("mage_wand_preservation") > 0:
		var counter: Variant = hero.get_buff("WandPreservationCounter")
		if counter == null:
			counter = WandPreservationCounter.new()
			hero.add_buff(counter)
		if counter.count == 0:
			counter.count += 1
			old_wand.level = 0
			var belongings: Variant = hero.get("belongings")
			var collected: bool = belongings != null and belongings.add_item(old_wand)
			if not collected:
				var dungeon_level: Variant = hero.get("level")
				if dungeon_level != null and dungeon_level.has_method("drop_item"):
					dungeon_level.drop_item(int(hero.pos), old_wand)
			if MessageLog:
				MessageLog.add_positive("Your talent preserves the %s at +0!"
					% old_wand.get_display_name())
	# Sync levels: max of the two, preserving one staff upgrade on override.
	var new_wand_level: int = new_wand.true_level()
	var target_level: int = maxi(true_level(), new_wand_level)
	if new_wand_level >= true_level() and true_level() > 0:
		target_level += 1
	level = target_level
	var pre_imbue_charges: int = new_wand.charges
	imbue_wand(new_wand)
	# _sync fully recharges; upstream instead carries the old staff's charges.
	imbued_wand.charges = mini(imbued_wand.charges_max,
		pre_imbue_charges + old_staff_charges)
	identify()
	if MessageLog:
		MessageLog.add_positive("You imbue your staff with the %s."
			% new_wand.get_display_name())

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
## A successful zap (one that spent a charge, including cursed backfires)
## primes Empowered Strike for 10 turns, mirroring upstream Wand.wandUsed's
## staff-wand branch. Buff merge gives Buff.prolong semantics.
func zap(hero: Char, target_pos: int) -> void:
	if imbued_wand == null:
		return
	var charges_before: int = imbued_wand.charges
	imbued_wand.zap(hero, target_pos)
	if imbued_wand.charges >= charges_before:
		return
	if hero != null and hero.has_method("get_talent_level") \
			and hero.get_talent_level("battlemage_empowered_strikes") > 0:
		hero.add_buff(EmpoweredStrikeTracker.new())
	_apply_excess_charge(hero, charges_before)

## Upstream Wand.wandUsed staff-wand branch (Talent.EXCESS_CHARGE): zapping the
## staff while its wand is at full charges grants Barrier shielding equal to
## round(wand buffed level * 0.67 * points). Mirrors upstream setShield
## semantics: an existing barrier is only raised to the value, never lowered
## and never stacked.
func _apply_excess_charge(hero: Char, charges_before: int) -> void:
	if hero == null or not hero.has_method("get_talent_level"):
		return
	var points: int = hero.get_talent_level("battlemage_excess_charge")
	if points <= 0:
		return
	if charges_before < imbued_wand.charges_max:
		return
	var shield: int = roundi(float(imbued_wand.buffed_lvl()) * 0.67 * float(points))
	if shield <= 0:
		return
	var barrier: Barrier = hero.add_buff(Barrier.new()) as Barrier
	if barrier != null and barrier.get_shielding() < shield:
		barrier.set_shield(shield)
	if MessageLog:
		MessageLog.add_positive("Excess charge shields you for %d." % shield)

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
