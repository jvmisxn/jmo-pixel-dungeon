class_name MonkMob
extends Mob
## Dwarf Monk (upstream Monk.java). Unarmed fanatic with a 0.5x attack
## delay that periodically gains Focus while hunting: the next physical
## attack against it is parried, then focus goes on a 6-7 turn cooldown.
## Moving reduces the cooldown faster, so kiting a monk builds its focus.

const FOCUS_COOLDOWN_MIN: float = 6.0
const FOCUS_COOLDOWN_MAX: float = 7.0

## Turns until the monk may focus again. <= 0 means ready.
var focus_cooldown: float = 0.0

func _init() -> void:
	super._init()
	mob_id = "monk"
	mob_name = "Dwarf Monk"
	description = "These monks are fanatics, who have devoted themselves to protecting their king through physical might. So great is their devotion that they have totally surrendered their minds to their king, and now roam the dwarven city like mindless zombies.\n\nMonks rely solely on the art of hand-to-hand combat, and are able to use their unarmed fists both for offense and defense. When they become focused, monks will parry the next physical attack used against them, even if it was otherwise guaranteed to hit. Monks build focus more quickly while on the move, and more slowly when in direct combat."
	# Upstream: HP 70, attackSkill 30, defenseSkill 30, damage 12-25,
	# drRoll super + NormalIntRange(0, 2).
	setup(70, 30, 30, 12, 25, 2)
	xp_value = 11
	max_level = 21
	_properties = ["UNDEAD"]
	loot_table = [{"item_id": "ration", "chance": 0.083}]

## Upstream Monk.attackDelay: super * 0.5 — two attacks per turn.
func attack_delay() -> float:
	return super.attack_delay() * 0.5

## Upstream Monk.act: after acting, regain Focus when hunting and off
## cooldown.
func act() -> void:
	super.act()
	if is_alive and state == AIState.HUNTING and focus_cooldown <= 0.0 \
			and not has_buff("MonkFocus"):
		add_buff(MonkFocus.new())

## Upstream Monk.spend: every spent turn burns focus cooldown by the time
## spent.
func spend_turn(speed_factor: float = 1.0) -> void:
	focus_cooldown -= speed_factor
	super.spend_turn(speed_factor)

## Upstream Monk.move: travelling reduces the cooldown by an extra 0.67
## (1.66 more for seniors), so monks focus notably faster when kited.
func on_move(old_pos: int, new_pos: int) -> void:
	super.on_move(old_pos, new_pos)
	focus_cooldown -= _travel_focus_bonus()

func _travel_focus_bonus() -> float:
	return 0.67

## Called by MonkFocus when a parry consumes the focus. Upstream
## Monk.defenseVerb: focusCooldown = Random.NormalFloat(6, 7).
func on_focus_parried() -> void:
	focus_cooldown = (randf_range(FOCUS_COOLDOWN_MIN, FOCUS_COOLDOWN_MAX)
		+ randf_range(FOCUS_COOLDOWN_MIN, FOCUS_COOLDOWN_MAX)) / 2.0

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["focus_cooldown"] = focus_cooldown
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	focus_cooldown = float(data.get("focus_cooldown", focus_cooldown))
