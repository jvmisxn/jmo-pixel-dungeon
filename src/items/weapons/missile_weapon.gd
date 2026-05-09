class_name MissileWeapon
extends Weapon
## Thrown/ranged weapons that are stackable and break after a number of uses.
## Created via the static factory method create(weapon_id).

# --- Properties ---
var base_uses: int = 10
var uses_left: int = 10
var sticky: bool = false  # embeds in enemy on hit
var returns: bool = false  # boomerang-type weapons return to thrower
var special_effect: String = ""  # e.g. "slow" for bolas

func _init() -> void:
	super._init()
	stackable = true
	default_action = "throw"

# ---------------------------------------------------------------------------
# Stacking
# ---------------------------------------------------------------------------

func is_stackable() -> bool:
	return true

func can_stack_with(other: Variant) -> bool:
	if not super.can_stack_with(other):
		return false
	# Only stack if same upgrade level and cursed state
	if other.get("level") != level:
		return false
	return true

# ---------------------------------------------------------------------------
# Durability
# ---------------------------------------------------------------------------

## Called after each throw/use. Returns true if the weapon broke.
func use_once() -> bool:
	uses_left -= 1
	if uses_left <= 0:
		return true  # weapon broke
	return false

## Whether this missile weapon is spent (no uses remaining).
func is_broken() -> bool:
	return uses_left <= 0

## Reset durability (e.g. on repair or new stack).
func reset_uses() -> void:
	uses_left = base_uses

# ---------------------------------------------------------------------------
# Throw Behavior
# ---------------------------------------------------------------------------

## Whether this weapon returns to the thrower after hitting.
func does_return() -> bool:
	return returns

## Whether this weapon has a special on-hit effect.
func has_special_effect() -> bool:
	return not special_effect.is_empty()

## Apply special on-hit effect to the target.
func apply_special_effect(target: Variant) -> void:
	if target == null:
		return
	match special_effect:
		"slow":
			if target.has_method("add_buff"):
				var script: GDScript = load("res://src/actors/buffs/cripple.gd") as GDScript
				if script:
					var cripple: Variant = script.new()
					if cripple.has_method("set_duration"):
						cripple.set_duration(3)
					target.add_buff(cripple)
				if MessageLog:
					MessageLog.add("The bolas entangle the enemy!")
		"poison":
			if target.has_method("add_buff"):
				target.add_buff(Poison.create(4.0))
				if MessageLog:
					MessageLog.add("The dart poisons its target!")
		"paralysis":
			if target.has_method("add_buff"):
				target.add_buff(Paralysis.new())
				if MessageLog:
					MessageLog.add("The dart leaves its target paralyzed!")

# ---------------------------------------------------------------------------
# Speed
# ---------------------------------------------------------------------------

## Missile weapons are generally faster to use than melee.
func speed_factor(hero: Char) -> float:
	var base: float = super.speed_factor(hero)
	return base * 0.5  # thrown weapons are quick

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## All valid missile weapon IDs.
static var ALL_IDS: Array[String] = [
	"dart", "curare_dart", "paralytic_dart",
	"throwing_knife", "throwing_club", "throwing_stone",
	"shuriken", "kunai", "bolas",
	"javelin", "tomahawk", "boomerang",
	"trident", "heavy_boomerang",
	"force_cudgel",
]

## Create a fully configured missile weapon by ID.
static func create(weapon_id: String) -> MissileWeapon:
	var w: MissileWeapon = MissileWeapon.new()
	w.item_id = weapon_id

	match weapon_id:
		# ===== TIER 1 =====
		"dart":
			w.item_name = "Dart"
			w.description = "A light throwing dart. Cheap, accurate, and easy to carry in bundles."
			w.tier = 1
			w.base_uses = 8
			w.icon_color = Color(0.7, 0.7, 0.65)
		"curare_dart":
			w.item_name = "Curare Dart"
			w.description = "A dart tipped with curare. It deals little damage but poisons on hit."
			w.tier = 1
			w.base_uses = 6
			w.special_effect = "poison"
			w.icon_color = Color(0.45, 0.8, 0.35)
		"paralytic_dart":
			w.item_name = "Paralytic Dart"
			w.description = "A dart coated with a numbing agent that can briefly paralyze its victim."
			w.tier = 1
			w.base_uses = 4
			w.special_effect = "paralysis"
			w.icon_color = Color(0.9, 0.85, 0.35)
		"throwing_knife":
			w.item_name = "Throwing Knife"
			w.description = "A small balanced knife designed for throwing. Cheap and disposable."
			w.tier = 1
			w.base_uses = 10
			w.icon_color = Color(0.6, 0.6, 0.65)
		"throwing_club":
			w.item_name = "Throwing Club"
			w.description = "A weighted wooden club that can be hurled short distances."
			w.tier = 1
			w.base_uses = 10
			w.icon_color = Color(0.5, 0.35, 0.15)
		"throwing_stone":
			w.item_name = "Throwing Stone"
			w.description = "A smooth, heavy stone. Primitive but always available."
			w.tier = 1
			w.base_uses = 10
			w.icon_color = Color(0.5, 0.5, 0.5)

		# ===== TIER 2 =====
		"shuriken":
			w.item_name = "Shuriken"
			w.description = "A razor-sharp throwing star. Cuts deep but wears down quickly."
			w.tier = 2
			w.base_uses = 5
			w.icon_color = Color(0.7, 0.7, 0.75)
		"kunai":
			w.item_name = "Kunai"
			w.description = "A pointed throwing blade favored by assassins."
			w.tier = 2
			w.base_uses = 5
			w.icon_color = Color(0.35, 0.35, 0.4)
		"bolas":
			w.item_name = "Bolas"
			w.description = "Weighted balls connected by cord. Entangles enemies on hit."
			w.tier = 2
			w.base_uses = 5
			w.special_effect = "slow"
			w.icon_color = Color(0.55, 0.45, 0.3)

		# ===== TIER 3 =====
		"javelin":
			w.item_name = "Javelin"
			w.description = "A long throwing spear. Excellent range and penetration."
			w.tier = 3
			w.base_uses = 5
			w.icon_color = Color(0.6, 0.55, 0.35)
		"tomahawk":
			w.item_name = "Tomahawk"
			w.description = "A throwing axe that tumbles through the air with lethal force."
			w.tier = 3
			w.base_uses = 5
			w.icon_color = Color(0.45, 0.35, 0.2)
		"boomerang":
			w.item_name = "Boomerang"
			w.description = "A curved throwing weapon that returns to the wielder after striking."
			w.tier = 3
			w.base_uses = 5
			w.returns = true
			w.icon_color = Color(0.55, 0.5, 0.3)

		# ===== TIER 4 =====
		"trident":
			w.item_name = "Trident"
			w.description = "A heavy three-pronged spear. Powerful at range."
			w.tier = 4
			w.base_uses = 5
			w.icon_color = Color(0.4, 0.6, 0.7)
		"heavy_boomerang":
			w.item_name = "Heavy Boomerang"
			w.description = "A reinforced boomerang made of dense metal. Hits hard and returns."
			w.tier = 4
			w.base_uses = 5
			w.returns = true
			w.icon_color = Color(0.5, 0.45, 0.35)

		# ===== TIER 5 =====
		"force_cudgel":
			w.item_name = "Force Cudgel"
			w.description = "A massive thrown club imbued with kinetic energy. Devastating impact."
			w.tier = 5
			w.base_uses = 5
			w.icon_color = Color(0.6, 0.3, 0.6)
		_:
			push_warning("MissileWeapon.create: unknown id '%s'" % weapon_id)
			w.item_name = weapon_id.capitalize()
			w.tier = 1
			w.base_uses = 10

	w.uses_left = w.base_uses
	w.str_requirement = w.get_str_requirement()
	return w

# ---------------------------------------------------------------------------
# Damage Override
# ---------------------------------------------------------------------------

## Missile weapons use a slightly different damage formula:
## They deal less base damage than melee weapons of the same tier.
func get_damage_range() -> Array[int]:
	# Use parent formula but scale down slightly for balance
	var base: Array[int] = super.get_damage_range()
	# Missile weapons keep the parent formula; specific values are set by tier
	return base

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	# Missile weapons are worth less per unit since they're consumable
	return maxi(1, int(super.value() * 0.3)) * quantity

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	var display: String = super.get_display_name()
	if quantity > 1:
		display += " x%d" % quantity
	return display

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["base_uses"] = base_uses
	data["uses_left"] = uses_left
	data["sticky"] = sticky
	data["returns"] = returns
	data["special_effect"] = special_effect
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	base_uses = data.get("base_uses", 10)
	uses_left = data.get("uses_left", base_uses)
	sticky = data.get("sticky", false)
	returns = data.get("returns", false)
	special_effect = data.get("special_effect", "")
