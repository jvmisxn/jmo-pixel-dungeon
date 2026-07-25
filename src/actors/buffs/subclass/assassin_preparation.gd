class_name AssassinPreparation
extends Buff
## Assassin subclass passive (upstream Preparation parity). Attaches while the
## Assassin is invisible (see Invisibility.on_attach) and builds one turn of
## preparation per invisible turn. A prepared attack replaces the base damage
## roll with the best of N rolls plus a staged bonus, and can outright execute
## enemies under a KO threshold. Detaches as soon as invisibility ends.
## Port adaptation: the upstream blink-attack ActionIndicator (and with it
## Assassin's Reach) is not implemented yet.

## Upstream Preparation.AttackLevel: turns required, base damage bonus, rolls.
const TURNS_REQ: Array[int] = [1, 3, 5, 9]
const BASE_DMG_BONUS: Array[float] = [0.10, 0.20, 0.35, 0.50]
const DAMAGE_ROLLS: Array[int] = [1, 1, 2, 3]
## KO thresholds: 1st index is prep level ordinal, 2nd is Enhanced Lethality
## talent points (0-3). Bosses/minibosses use threshold / 5.
const KO_THRESHOLDS: Array = [
	[0.03, 0.04, 0.05, 0.06],
	[0.10, 0.13, 0.17, 0.20],
	[0.20, 0.27, 0.33, 0.40],
	[0.50, 0.67, 0.83, 1.00],
]

var turns_invis: int = 0

func _init() -> void:
	buff_id = "AssassinPreparation"
	buff_name = "Preparation"
	buff_type = BuffType.POSITIVE
	duration = -1.0
	icon_color = Color(0.2, 0.2, 0.5)

func on_turn() -> void:
	if target == null:
		return
	# Upstream act(): builds only while invisible, detaches the moment
	# invisibility ends.
	if target.invisible > 0:
		turns_invis += 1
	else:
		target.remove_buff(self)

## 0-based attack level ordinal for table lookups (upstream AttackLevel.getLvl).
func level_ordinal() -> int:
	for i in range(TURNS_REQ.size() - 1, 0, -1):
		if turns_invis >= TURNS_REQ[i]:
			return i
	return 0

## 1-based attack level (upstream attackLevel()).
func attack_level() -> int:
	return level_ordinal() + 1

func _lethality_points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return clampi(target.get_talent_level("assassin_enhanced_lethality"), 0, 3)
	return 0

## Prepared damage roll: best of N base rolls, then the staged bonus
## (upstream AttackLevel.damageRoll). `roll` is the attacker's base roll.
func prep_damage_roll(roll: Callable) -> int:
	var lvl: int = level_ordinal()
	var dmg: int = int(roll.call())
	for i in range(1, DAMAGE_ROLLS[lvl]):
		dmg = maxi(dmg, int(roll.call()))
	return roundi(dmg * (1.0 + BASE_DMG_BONUS[lvl]))

## Whether a prepared strike executes this defender outright
## (upstream Preparation.canKO).
func can_ko(defender: Node) -> bool:
	if defender == null or defender.get("hp_max") == null or defender.hp_max <= 0:
		return false
	if defender.has_method("is_invulnerable") and defender.is_invulnerable(target):
		return false
	var threshold: float = KO_THRESHOLDS[level_ordinal()][_lethality_points()]
	if defender.has_method("is_boss") and defender.is_boss():
		threshold /= 5.0
	return float(defender.hp) / float(defender.hp_max) < threshold

func description() -> String:
	var lvl: int = level_ordinal()
	var desc: String = "You are preparing an attack from the shadows.\n\n" \
		+ "Your next attack deals %d%% bonus damage and can instantly kill enemies below %d%% of their max health (%d%% for bosses)." \
		% [int(BASE_DMG_BONUS[lvl] * 100), int(KO_THRESHOLDS[lvl][_lethality_points()] * 100), int(KO_THRESHOLDS[lvl][_lethality_points()] * 20)]
	if DAMAGE_ROLLS[lvl] > 1:
		desc += " Bonus damage is more likely to roll high."
	desc += "\n\nTurns of invisibility: %d." % turns_invis
	if lvl < TURNS_REQ.size() - 1:
		desc += "\nNext level at %d turns." % TURNS_REQ[lvl + 1]
	return desc

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["turns_invis"] = turns_invis
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	turns_invis = int(data.get("turns_invis", 0))
