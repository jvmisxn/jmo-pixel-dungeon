class_name SoulMark
extends Buff
## Warlock soul mark (upstream SoulMark + Mob.defenseProc processing).
## While a mob is marked, physical damage dealt to it restores the Warlock:
## - Hero-dealt physical damage: heal ceil(40% of damage dealt).
## - Other characters' physical damage: scaled by Soul Siphon points
##   (13%/27%/40% effectiveness; zero without the talent).
## - Soul Eater points grant satiety per point of restoration (pts/3 turns).
## Restoration is capped at the damage the mob can actually absorb
## (hp + shielding), mirroring upstream `min(damage, HP+shielding())`.
## Wand zaps do NOT trigger restoration, matching upstream (defenseProc only
## runs for melee/thrown attacks).

const DURATION: float = 10.0

func _init() -> void:
	buff_id = "SoulMark"
	buff_name = "Soul Marked"
	buff_type = BuffType.NEGATIVE
	duration = DURATION
	time_left = DURATION
	icon_color = Color(0.5, 0.2, 1.0)

## Upstream Mob.defenseProc soul-mark block. Called from the marked mob's
## defense_proc with the pre-armor damage and the attacker. Returns the heal
## actually credited to the warlock (for tests).
func process_restoration(damage: int, attacker: Variant) -> int:
	if target == null:
		return 0
	var hero: Node = GameManager.hero if GameManager else null
	if hero == null or not hero.is_alive:
		return 0
	if hero.get("hero_subclass") != ConstantsData.HeroSubclass.WARLOCK:
		return 0
	var absorbable: int = target.hp
	if target.has_method("total_shielding"):
		absorbable += target.total_shielding()
	var restoration: int = mini(damage, absorbable)
	# Physical damage that doesn't come from the hero is less effective
	# (upstream: 0.4 * SOUL_SIPHON points / 3).
	if attacker != hero:
		var siphon: int = 0
		if hero.has_method("get_talent_level"):
			siphon = hero.get_talent_level("warlock_soul_siphon")
		restoration = roundi(restoration * 0.4 * float(siphon) / 3.0)
	if restoration <= 0:
		return 0
	# Soul Eater satiety (restoration * points / 3).
	var eater: int = 0
	if hero.has_method("get_talent_level"):
		eater = hero.get_talent_level("warlock_soul_eater")
	if eater > 0:
		var hunger_buff: Node = hero.get_buff("Hunger")
		if hunger_buff and hunger_buff.has_method("satisfy"):
			hunger_buff.satisfy(restoration * float(eater) / 3.0)
	var heal_amount: int = 0
	if hero.hp < hero.hp_max:
		heal_amount = ceili(restoration * 0.4)
		hero.heal(heal_amount)
	return heal_amount

## Upstream SoulMark.prolong: refresh the mark to at least [turns].
func prolong(turns: float) -> void:
	time_left = maxf(time_left, turns)
	duration = maxf(duration, turns)

func description() -> String:
	return ("The warlock has tapped into the soul of this creature, allowing"
		+ " him to heal as it takes physical damage.\n\nTurns of soul mark"
		+ " remaining: %d." % int(ceil(time_left)))
