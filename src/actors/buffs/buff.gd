class_name Buff
extends Node
## Base class for all buffs and debuffs applied to characters.
## Buffs modify stats, deal periodic damage, or grant special abilities.
## Matches original SPD Buff.java structure.

## Buff type determines UI treatment and some gameplay interactions.
enum BuffType { POSITIVE, NEGATIVE, NEUTRAL }

## Unique identifier for this buff type.
var buff_id: String = "Buff"
## Display name shown in the UI.
var buff_name: String = "Buff"
## Buff type (POSITIVE/NEGATIVE/NEUTRAL). Replaces the old is_debuff bool.
var buff_type: BuffType = BuffType.NEUTRAL
## Whether this is a debuff (negative effect). Derived from buff_type.
var is_debuff: bool:
	get: return buff_type == BuffType.NEGATIVE
	set(value): buff_type = BuffType.NEGATIVE if value else BuffType.NEUTRAL
## The character this buff is attached to (untyped to avoid Char↔Buff circular dependency).
var target: Node = null
## Duration in turns (-1 = permanent until explicitly removed).
var duration: float = -1.0
## Time remaining.
var time_left: float = -1.0
## Icon color for UI display.
var icon_color: Color = Color.WHITE
## Whether the buff announces its name when first applied (for hero messages).
var announced: bool = false
## Whether this buff persists through revive effects.
var revive_persists: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Called when the buff is first attached to a character.
func attach(buff_owner: Node) -> void:
	target = buff_owner
	if duration > 0 and time_left < 0.0:
		time_left = duration
	on_attach()

## Called when the buff is removed from a character.
func detach() -> void:
	on_detach()
	target = null

## Override for attach behavior.
func on_attach() -> void:
	pass

## Override for detach behavior.
func on_detach() -> void:
	pass

# ---------------------------------------------------------------------------
# Turn Processing
# ---------------------------------------------------------------------------

## Called each turn the buff is active.
func act() -> void:
	if duration > 0:
		time_left -= 1.0
	on_turn()

## Override for per-turn effects (poison damage, regeneration, etc.).
func on_turn() -> void:
	pass

## Returns true if this buff has expired.
func is_expired() -> bool:
	if duration < 0:
		return false  # permanent
	return time_left <= 0.0

# ---------------------------------------------------------------------------
# Duration Management
# ---------------------------------------------------------------------------

func get_duration() -> float:
	return duration

func set_duration(value: float) -> void:
	duration = value
	time_left = value

func get_time_left() -> float:
	return time_left

## Postpone expiration (set time_left to max of current and new value).
func postpone(new_duration: float) -> void:
	time_left = maxf(time_left, new_duration)

## Merge with another buff of the same type (extend duration).
func merge(other: Node) -> void:
	if other is Buff:
		var other_buff: Buff = other as Buff
		var other_dur: float = other_buff.duration
		if other_dur > 0 and duration > 0:
			time_left = maxf(time_left, other_buff.time_left)
		elif other_dur > 0:
			duration = other_dur
			time_left = other_buff.time_left

# ---------------------------------------------------------------------------
# Event Hooks
# ---------------------------------------------------------------------------

## Called when the owner takes damage.
func on_damage_taken(_amount: int, _source: Variant) -> void:
	pass

## Called when the owner deals damage.
func on_damage_dealt(_amount: int, _target: Node) -> void:
	pass

## Called when the owner moves.
func on_move(_old_pos: int, _new_pos: int) -> void:
	pass

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

## Display text for duration on buff icon (e.g., turns remaining).
func icon_text() -> String:
	if time_left > 0:
		return str(int(time_left))
	return ""

## Fade percent for icon (0-1), used when buff is about to expire.
func icon_fade_percent() -> float:
	if duration <= 0:
		return 0.0
	return clampf(1.0 - time_left / duration, 0.0, 1.0)

## Description text for buff details.
func description() -> String:
	return ""

# ---------------------------------------------------------------------------
# Stat Modifiers (overridden by specific buffs)
# ---------------------------------------------------------------------------

## Modify accuracy.
func modify_accuracy(acc: int) -> int:
	return acc

## Modify evasion.
func modify_evasion(eva: int) -> int:
	return eva

## Modify speed.
func modify_speed(speed: float) -> float:
	return speed

## Modify damage.
func modify_damage(dmg: int) -> int:
	return dmg

## Modify armor.
func modify_armor(armor: int) -> int:
	return armor

## Evasion modifier (used by some buffs).
func evasion_modifier(eva: int) -> int:
	return modify_evasion(eva)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"_script_path": get_script().resource_path,
		"buff_id": buff_id,
		"buff_name": buff_name,
		"buff_type": buff_type,
		"duration": duration,
		"time_left": time_left,
	}

func deserialize(data: Dictionary) -> void:
	buff_id = data.get("buff_id", buff_id)
	buff_name = data.get("buff_name", buff_name)
	buff_type = data.get("buff_type", buff_type)
	duration = data.get("duration", duration)
	time_left = data.get("time_left", time_left)

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Display-friendly turns remaining.
func disp_turns(turns: float) -> String:
	if turns <= 0:
		return ""
	var t: int = int(turns)
	if t == 1:
		return "1 turn"
	return "%d turns" % t
