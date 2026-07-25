class_name WarriorShield
extends Buff
## Warrior broken-seal shield. Original: BrokenSeal.WarriorShield (SPD 3.1+):
## a hit that leaves the Warrior at or below half HP triggers the seal's full
## shield (3 + 2*armor tier + Iron Will points), then a 150-turn cooldown.
## The shield fades 5 turns after combat ends, refunding up to half of the
## cooldown in proportion to shield remaining. The buff never detaches at
## zero shield while the seal is worn or the cooldown is running.

const COOLDOWN_START: int = 150
const FADE_TURNS: float = 5.0

var shield_amount: int = 0
var cooldown: int = 0
var turns_since_enemies: float = 0.0
var initial_shield: int = 0

func _init() -> void:
	buff_id = "WarriorShield"
	buff_name = "Seal Shield"
	buff_type = BuffType.POSITIVE
	duration = -1  # Managed by seal presence and cooldown, not time.
	icon_color = Color(0.75, 0.75, 0.8)

func get_shielding() -> int:
	return shield_amount

## Original: detachesAtZero = false — an emptied shield leaves the buff in
## place so the cooldown keeps ticking.
func absorb_damage(dmg: int) -> int:
	var absorbed: int = mini(shield_amount, dmg)
	shield_amount -= absorbed
	return dmg - absorbed

## Original: BrokenSeal.maxShield(armTier, armLvl) = 3 + 2*tier + Iron Will.
## The armor reference is resolved dynamically instead of via setArmor(), so
## equip/unequip needs no relink bookkeeping (equivalent for a single hero).
func max_shield() -> int:
	if target == null:
		return 0
	var belongings: Variant = target.get("belongings")
	if belongings == null or belongings.armor == null:
		return 0
	var armor: Variant = belongings.armor
	if not (armor is Armor and (armor as Armor).has_seal()):
		return 0
	var iron_will: int = 0
	if target.has_method("get_talent_level"):
		iron_will = target.get_talent_level("warrior_iron_will")
	return 3 + 2 * (armor as Armor).tier + iron_will

func is_cooling_down() -> bool:
	return cooldown > 0

func activate() -> void:
	shield_amount += max_shield()
	cooldown = maxi(0, cooldown + COOLDOWN_START)
	turns_since_enemies = 0.0
	initial_shield = max_shield()

func on_turn() -> void:
	if cooldown > 0 and _regen_on():
		cooldown -= 1

	if shield_amount > 0:
		if _visible_enemy_count() == 0 and (target == null or target.get_buff("Combo") == null):
			turns_since_enemies += 1.0
			if turns_since_enemies >= FADE_TURNS:
				if cooldown > 0 and initial_shield > 0:
					# Max 50% cooldown refund, scaled by shield left.
					var percent_left: float = float(shield_amount) / float(initial_shield)
					cooldown = maxi(0, cooldown - int(COOLDOWN_START * (percent_left / 2.0)))
				shield_amount = 0
		else:
			turns_since_enemies = 0.0

	if shield_amount <= 0 and max_shield() <= 0 and cooldown == 0 and target != null:
		target.remove_buff(self)

## Original gates the cooldown tick on Regeneration.regenOn(); mirror the
## port's boss-floor lock check from regeneration.gd.
func _regen_on() -> bool:
	if GameManager == null:
		return true
	var depth: int = GameManager.depth
	if depth % 5 == 0 and depth > 0:
		var level: Variant = GameManager.current_level
		if level != null and level.has_method("is_locked") and level.is_locked():
			return false
	return true

## Original: Dungeon.hero.visibleEnemies() — count living hostile mobs the
## hero can currently see.
func _visible_enemy_count() -> int:
	if target == null or GameManager == null or GameManager.current_level == null:
		return 0
	var mobs: Variant = GameManager.current_level.get("mobs")
	if mobs == null or not (mobs is Array):
		return 0
	var count: int = 0
	for mob: Variant in mobs:
		if mob == null or not (mob is Object) or not bool(mob.get("is_alive")):
			continue
		if bool(mob.get("is_ally")) or mob is NPC:
			continue
		if target.has_method("can_see") and target.can_see(int(mob.pos)):
			count += 1
	return count

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["shield_amount"] = shield_amount
	data["cooldown"] = cooldown
	data["turns_since_enemies"] = turns_since_enemies
	data["initial_shield"] = initial_shield
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	shield_amount = int(data.get("shield_amount", 0))
	cooldown = int(data.get("cooldown", 0))
	turns_since_enemies = float(data.get("turns_since_enemies", 0.0))
	initial_shield = int(data.get("initial_shield", shield_amount))
