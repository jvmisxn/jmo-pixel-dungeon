class_name HerbalArmorBuff
extends Buff
## SPD Earthroot.Armor parity. While the character holds still, each incoming
## hit is reduced by up to `blocking()` damage drawn from a pool sized to the
## character's max HP. The buff detaches the moment the character moves or the
## pool runs dry. Unlike the old port behavior there is NO flat armor bonus and
## NO fixed timer — this mirrors upstream `Earthroot.Armor`:
##   blocking() = (scalingDepth + 5) / 2
##   absorb(dmg): block = min(dmg, blocking()); pool -= block (detach if depleted)
##   level(v)  : pool = max(pool, v)   (applied with ch.HT)
##   act()     : detach when the owner has moved off its anchored cell

## Remaining absorb pool. Sized to the owner's max HP when applied.
var pool: int = 0

func _init() -> void:
	buff_id = "HerbalArmor"
	buff_name = "Herbal Armor"
	is_debuff = false
	buff_type = BuffType.POSITIVE
	# No timed expiry in SPD: the armor lasts until the owner moves or the pool
	# depletes, so keep it permanent-until-detached rather than a 20-turn clock.
	duration = -1.0
	time_left = -1.0
	icon_color = Color(0.4, 0.3, 0.1)

## SPD Earthroot.Armor.level(int): only grows the pool, never shrinks it.
func apply_pool(value: int) -> void:
	pool = maxi(pool, maxi(0, value))

## SPD Earthroot.Armor.blocking(): (scalingDepth + 5) / 2, integer division.
## This port has no challenge modifiers, so scalingDepth is the current depth.
func _blocking() -> int:
	var depth: int = 1
	if GameManager != null and GameManager.get("depth") != null:
		depth = maxi(1, int(GameManager.depth))
	@warning_ignore("integer_division")
	var block: int = (depth + 5) / 2
	return maxi(1, block)

## Pre-hit absorption hook (called from `Char.take_damage`). Returns the damage
## remaining after the block. Mirrors SPD's `Armor.absorb(int)`.
func absorb_damage(dmg: int) -> int:
	if dmg <= 0:
		return dmg
	var block: int = mini(dmg, _blocking())
	if pool <= block:
		# Last of the pool is spent absorbing this hit, then the roots crumble.
		if target:
			target.remove_buff(self)
		if MessageLog:
			MessageLog.add("The herbal armor crumbles away.")
		return dmg - block
	pool -= block
	return dmg - block

## Earthroot armor only protects while the owner holds still — any move detaches
## it (SPD `Armor.act()` detaches once `target.pos != pos`).
func on_move(_old_pos: int, _new_pos: int) -> void:
	if target:
		target.remove_buff(self)

## Re-applying keeps the larger pool, matching SPD's `level()` semantics.
func merge(other: Node) -> void:
	if other is HerbalArmorBuff:
		pool = maxi(pool, (other as HerbalArmorBuff).pool)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["pool"] = pool
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	# Accept the legacy `absorb_remaining` key so pre-parity saves still load.
	pool = int(data.get("pool", data.get("absorb_remaining", 0)))

func icon_text() -> String:
	return str(pool) if pool > 0 else ""

## SPD iconFadePercent: (HT - level) / HT — the icon empties as the pool drains.
func icon_fade_percent() -> float:
	if target == null:
		return 0.0
	var ht: int = int(target.get("ht")) if target.get("ht") != null else 0
	if ht <= 0:
		return 0.0
	return clampf(float(ht - pool) / float(ht), 0.0, 1.0)

func description() -> String:
	return "Roots absorb up to %d damage per hit while you hold still (%d absorb left)." % [_blocking(), pool]
