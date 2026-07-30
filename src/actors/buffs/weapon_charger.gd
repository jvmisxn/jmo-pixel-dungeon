class_name WeaponCharger
extends Buff
## Duelist weapon-ability charge pool. Original: MeleeWeapon.Charger.
## Charges fuel melee weapon abilities (to be ported on top of this buff).
## Passive gain runs 60 down to 45 turns per charge (40-30 as Champion),
## and the Weapon Recharging talent adds 1 per 15/10 turns while a
## Recharging buff is active. Hidden from the buff bar like upstream
## (Charger has no BuffIndicator icon; it surfaces through the UI later
## via the ability/action indicator, not the status bar).
##
## Port adaptations: upstream's Brawler's Stance 50% slowdown is skipped
## (Ring of Force stance is not ported), and upstream's ArtifactRecharge
## over-time buff does not exist here (artifact recharge spells apply
## charge instantly), so only the Recharging buff satisfies the talent gate.

var charges: int = 2
var partial_charge: float = 0.0

func _init() -> void:
	buff_id = "WeaponCharger"
	buff_name = "Weapon Charger"
	buff_type = BuffType.POSITIVE
	duration = -1  # Permanent class buff
	revive_persists = true  # Upstream: duelist keeps weapon charge on ankh revive
	show_in_ui = false

func on_turn() -> void:
	if target == null or not target.is_alive:
		return
	# Champion swap stand-in for the upstream ActionIndicator: the charger
	# surfaces as a tappable buff icon only while the hero is a Champion
	# (upstream Charger.act sets ActionIndicator for CHAMPION only).
	show_in_ui = _subclass() == ConstantsData.HeroSubclass.CHAMPION
	var cap: int = charge_cap()
	if charges < cap:
		if _regen_on():
			# 60 to 45 turns per charge (upstream: 1/(60-1.5*(cap-charges)))
			var charge_to_gain: float = 1.0 / (60.0 - 1.5 * float(cap - charges))
			# 40 to 30 turns per charge for Champion
			if _subclass() == ConstantsData.HeroSubclass.CHAMPION:
				charge_to_gain *= 1.5
			partial_charge += charge_to_gain
		# Weapon Recharging talent: 1 charge per 15/10 turns while Recharging
		var points: int = _recharging_points()
		if points > 0 and target.has_method("has_buff") and target.has_buff("Recharging"):
			partial_charge += 1.0 / (20.0 - 5.0 * float(points))
		if partial_charge >= 1.0:
			charges += 1
			partial_charge -= 1.0
	else:
		partial_charge = 0.0

## Maximum stored charges: caps at hero level 19 with 8 (10 for Champion).
func charge_cap() -> int:
	var lvl: int = target.hero_level if target != null and "hero_level" in target else 1
	if _subclass() == ConstantsData.HeroSubclass.CHAMPION:
		return mini(10, 4 + (lvl - 1) / 3)
	return mini(8, 2 + (lvl - 1) / 3)

## External charge gain (talents, items). Upstream Charger.gainCharge.
func gain_charge(amount: float) -> void:
	var cap: int = charge_cap()
	if charges >= cap:
		return
	partial_charge += amount
	while partial_charge >= 1.0:
		charges += 1
		partial_charge -= 1.0
	if charges >= cap:
		partial_charge = 0.0
		charges = cap

func _subclass() -> int:
	if target != null and "hero_subclass" in target:
		return target.hero_subclass
	return ConstantsData.HeroSubclass.NONE

func _recharging_points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level("duelist_weapon_recharging")
	return 0

## Passive gain pauses where natural regen pauses: locked boss floors.
## Mirrors Regeneration._regen_on (upstream Regeneration.regenOn()).
func _regen_on() -> bool:
	if GameManager == null:
		return true
	var depth: int = GameManager.depth
	if depth % 5 == 0 and depth > 0:
		var level: Variant = GameManager.current_level
		if level != null and level.has_method("is_locked") and level.is_locked():
			return false
	return true

func description() -> String:
	return "Weapon ability charge: %d/%d." % [charges, charge_cap()]

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["charges"] = charges
	data["partial_charge"] = partial_charge
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	charges = int(data.get("charges", charges))
	partial_charge = float(data.get("partial_charge", partial_charge))
	show_in_ui = _subclass() == ConstantsData.HeroSubclass.CHAMPION
