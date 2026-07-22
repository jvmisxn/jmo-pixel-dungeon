class_name Sorrowmoss
extends Plant
## Applies Poison to the character that steps on it, matching upstream
## `Sorrowmoss.activate()`:
##   Buff.affect(ch, Poison.class).set( 5 + Math.round(2*Dungeon.scalingDepth()/3f) );
## A Warden hero additionally gains a short Toxic Imbue boon
## (`ToxicImbue.DURATION * 0.3`), turning the plant into an offensive gas cloud.
##
## Divergences: `scalingDepth()` is plain `level.depth` (this port has no
## challenge modifiers), and upstream's `HazardAssistTracker` mob hint and poison
## splash particles are not modelled (same omission as the sibling plants).

## SPD poison base duration term.
const BASE_POISON: float = 5.0
## Warden's Toxic Imbue lasts 30% of the full imbue duration.
const WARDEN_IMBUE_DURATION: float = ToxicImbue.BASE_DURATION * 0.3

func _init() -> void:
	plant_id = "Sorrowmoss"
	plant_name = "Sorrowmoss"

## SPD: `5 + Math.round(2 * scalingDepth / 3f)`.
static func poison_amount(depth: int) -> float:
	return BASE_POISON + roundi(2.0 * float(depth) / 3.0)

func _do_effect(char: Variant, level: Variant) -> void:
	if char == null:
		return

	# Warden gains an offensive toxic-gas boon (SPD: ToxicImbue for a fraction of
	# its duration). The imbue's Poison immunity means the Warden takes no self
	# poison from the burst below.
	if char is Hero and char.hero_subclass == ConstantsData.HeroSubclass.WARDEN:
		if char.has_method("add_buff"):
			var imbue: ToxicImbue = ToxicImbue.new()
			imbue.set_duration(WARDEN_IMBUE_DURATION)
			char.add_buff(imbue)
		if MessageLog:
			MessageLog.add_positive("The sorrowmoss wreathes you in toxic gas!")

	var depth: int = 1
	if level and level.get("depth") != null:
		depth = level.depth

	if char.has_method("add_buff"):
		# Poison.set() semantics: take the longer of current vs new duration.
		# `add_buff` already merges same-id buffs by max time_left.
		var poison: Poison = Poison.create(poison_amount(depth))
		char.add_buff(poison)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_negative("Toxic spores cloud around you!")
		else:
			MessageLog.add("Toxic spores surround the %s!" % str(char.get("name")))
