class_name MonkEnergy
extends Buff
## Monk (Duelist) subclass energy pool. Original: MonkEnergy.
## Energy builds when enemies die (5 boss / 3 miniboss / 0.5 for weak
## swarm enemies / 1 otherwise) and fuels monk abilities. Ported so far:
## Flurry and Focus (Hero._do_monk_ability); Dash, Dragon Kick and
## Meditate still pending.
##
## Port adaptations: the mob roster has no MINIBOSS property yet, so the
## miniboss bonus checks `_properties` defensively; the half-energy list is
## keyed by mob_id (upstream: Ghoul/RipperDemon/YogDzewa.Larva/Wraith
## classes).

## Weak swarm-style enemies that only give half energy (upstream: Ghoul,
## RipperDemon, YogDzewa.Larva, Wraith).
const HALF_ENERGY_IDS: Array[String] = ["ghoul", "ripper", "larva", "wraith"]

var energy: float = 0.0

func _init() -> void:
	buff_id = "MonkEnergy"
	buff_name = "Monk Energy"
	buff_type = BuffType.POSITIVE
	duration = -1  # Permanent subclass buff
	revive_persists = true  # Upstream: revivePersists = true
	icon_color = Color(0.63, 0.53, 0.25)  # upstream indicator 0xA08840

## Maximum stored energy: 10 at base, 20 at hero level 30.
## Upstream: MonkEnergy.energyCap().
func energy_cap() -> int:
	var lvl: int = target.hero_level if target != null and "hero_level" in target else 1
	@warning_ignore("integer_division")
	return maxi(10, 5 + lvl / 2)

## Grant energy for a slain enemy. Upstream: MonkEnergy.gainEnergy(Mob).
## Returns the energy actually gained (0 when gated), for tests/logging.
func gain_energy(enemy: Node) -> float:
	if target == null or enemy == null:
		return 0.0
	# No energy where natural regen pauses (locked boss floors), to prevent
	# farming boss minions. Upstream: Regeneration.regenOn() gate.
	if not _regen_on():
		return 0.0

	var energy_gain: float = 1.0
	if enemy.has_method("is_boss") and enemy.is_boss():
		energy_gain = 5.0
	elif enemy.get("_properties") is Array and (enemy.get("_properties") as Array).has("MINIBOSS"):
		energy_gain = 3.0
	elif HALF_ENERGY_IDS.has(str(enemy.get("mob_id"))):
		energy_gain = 0.5

	energy_gain *= _unencumbered_spirit_multi()

	energy += energy_gain
	# Kills mid unarmed-ability don't cap yet; ability_used clamps after
	# spending (upstream: UnarmedAbilityTracker check in gainEnergy).
	if not (target.has_method("has_buff") and target.has_buff("UnarmedAbilityTracker")):
		energy = minf(energy, float(energy_cap()))
	return energy_gain

## Unencumbered Spirit talent: low-tier armor and weapon each add
## +50%/75%/100% energy gain at sufficient points. Upstream: gainEnergy's
## Talent.UNENCUMBERED_SPIRIT block (Brawler's Stance exception not ported).
func _unencumbered_spirit_multi() -> float:
	var points: int = 0
	if target != null and target.has_method("get_talent_level"):
		points = target.get_talent_level("monk_unencumbered_spirit")
	if points <= 0:
		return 1.0
	var multi: float = 1.0
	var belongings: Variant = target.get("belongings")
	if belongings != null:
		multi += _gear_bonus(belongings.get("armor"), points)
		multi += _gear_bonus(belongings.get("weapon"), points)
	return multi

func _gear_bonus(gear: Variant, points: int) -> float:
	if gear == null or not ("tier" in gear):
		return 0.0
	var tier: int = int(gear.get("tier"))
	if tier <= 1 and points >= 3:
		return 1.0
	elif tier <= 2 and points >= 2:
		return 0.75
	elif tier <= 3 and points >= 1:
		return 0.5
	return 0.0

## Spend energy on a monk ability. Upstream: MonkEnergy.abilityUsed
## (Combined Energy talent hook lands with the abilities themselves).
func ability_used(cost: float) -> void:
	energy = clampf(energy - cost, 0.0, float(energy_cap()))

## Whether abilities are empowered by the Monastic Vigor talent:
## 100%/80%/60% of cap at +1/+2/+3. Upstream: abilitiesEmpowered.
func abilities_empowered() -> bool:
	var points: int = 0
	if target != null and target.has_method("get_talent_level"):
		points = target.get_talent_level("monk_monastic_vigor")
	return energy / float(energy_cap()) >= 1.2 - 0.2 * float(points)

## Energy pauses where natural regen pauses: locked boss floors.
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
	return "Monk energy: %d/%d. Energy builds as enemies are defeated and fuels monk abilities." % [int(energy), energy_cap()]

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["energy"] = energy
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	energy = float(data.get("energy", energy))
