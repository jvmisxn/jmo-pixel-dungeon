class_name WeaponEnchantment
extends RefCounted
## Base enchantment class for weapons. Each enchantment modifies damage or applies
## special effects on hit. Use the factory method create() to instantiate by ID.

# --- Properties ---
var enchant_id: String = ""
var enchant_name: String = ""
var color: Color = Color.WHITE
var proc_chance: float = 0.2
## Whether this enchantment is a curse (negative effect).
var is_curse: bool = false

# ---------------------------------------------------------------------------
# Visual Effect Emission
# ---------------------------------------------------------------------------

## Emit the enchantment_proc signal via EventBus so the visual layer can react.
static func _emit_proc(ench_id: String, attacker: Variant, defender: Variant) -> void:
	if EventBus == null:
		return
	var a_pos: int = attacker.get("pos") if attacker is Object else -1
	var d_pos: int = defender.get("pos") if defender is Object else -1
	EventBus.enchantment_proc.emit(ench_id, a_pos, d_pos)

# ---------------------------------------------------------------------------
# Proc (Virtual)
# ---------------------------------------------------------------------------

## Called when the enchanted weapon hits. Returns modified damage.
## Dispatches to the correct proc implementation based on enchant_id.
func proc(weapon: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
	match enchant_id:
		"blazing":
			return _blazing_proc(weapon, attacker, defender, damage)
		"chilling":
			return _chilling_proc(weapon, attacker, defender, damage)
		"shocking":
			return _shocking_proc(weapon, attacker, defender, damage)
		"lucky":
			return _lucky_proc(weapon, attacker, defender, damage)
		"projecting":
			return _projecting_proc(weapon, attacker, defender, damage)
		"unstable":
			return _unstable_proc(weapon, attacker, defender, damage)
		"grim":
			return _grim_proc(weapon, attacker, defender, damage)
		"vampiric":
			return _vampiric_proc(weapon, attacker, defender, damage)
		"elastic":
			return _elastic_proc(weapon, attacker, defender, damage)
		"kinetic":
			return _kinetic_proc(weapon, attacker, defender, damage)
		"blocking":
			return _blocking_proc(weapon, attacker, defender, damage)
		"blooming":
			return _blooming_proc(weapon, attacker, defender, damage)
		"corrupting":
			return _corrupting_proc(weapon, attacker, defender, damage)
	# Curse enchantments and unknown IDs: no effect
	return damage

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## All known enchantment IDs.
static var ALL_IDS: Array[String] = [
	"blazing", "chilling", "shocking", "lucky", "projecting",
	"unstable", "grim", "vampiric", "elastic",
	"kinetic", "blocking", "blooming", "corrupting",
]

## Rarity tiers matching original SPD distribution.
## Common (50% total, ~12.5% each): Blazing, Chilling, Kinetic, Shocking
## Uncommon (40% total, ~6.7% each): Blocking, Blooming, Elastic, Lucky, Projecting, Unstable
## Rare (10% total, ~3.3% each): Corrupting, Grim, Vampiric
static var COMMON_IDS: Array[String] = ["blazing", "chilling", "kinetic", "shocking"]
static var UNCOMMON_IDS: Array[String] = ["blocking", "blooming", "elastic", "lucky", "projecting", "unstable"]
static var RARE_IDS: Array[String] = ["corrupting", "grim", "vampiric"]

## Curse enchantment IDs.
static var CURSE_IDS: Array[String] = [
	"annoying", "displacing", "dazzling", "explosive",
	"sacrificial", "wayward", "polarized", "friendly",
]

## Create an enchantment by ID, fully configured.
static func create(ench_id: String) -> WeaponEnchantment:
	var e: WeaponEnchantment = WeaponEnchantment.new()
	e.enchant_id = ench_id

	match ench_id:
		"blazing":
			e.enchant_name = "Blazing"
			e.color = Color(1.0, 0.45, 0.1)  # orange-red
		"chilling":
			e.enchant_name = "Chilling"
			e.color = Color(0.4, 0.75, 1.0)  # ice blue
		"shocking":
			e.enchant_name = "Shocking"
			e.color = Color(0.9, 0.9, 0.2)  # electric yellow
		"lucky":
			e.enchant_name = "Lucky"
			e.color = Color(0.2, 0.9, 0.3)  # green
		"projecting":
			e.enchant_name = "Projecting"
			e.color = Color(0.7, 0.4, 0.9)  # purple
		"unstable":
			e.enchant_name = "Unstable"
			e.color = Color(0.9, 0.2, 0.9)  # magenta
		"grim":
			e.enchant_name = "Grim"
			e.color = Color(0.15, 0.15, 0.15)  # near-black
		"vampiric":
			e.enchant_name = "Vampiric"
			e.color = Color(0.6, 0.0, 0.0)  # dark red
		"elastic":
			e.enchant_name = "Elastic"
			e.color = Color(0.6, 0.85, 0.6)  # pale green
		"kinetic":
			e.enchant_name = "Kinetic"
			e.color = Color(0.85, 0.75, 0.3)  # golden
		"blocking":
			e.enchant_name = "Blocking"
			e.color = Color(0.5, 0.55, 0.6)  # steel blue-gray
		"blooming":
			e.enchant_name = "Blooming"
			e.color = Color(0.3, 0.8, 0.3)  # grass green
		"corrupting":
			e.enchant_name = "Corrupting"
			e.color = Color(0.3, 0.0, 0.3)  # dark purple
		# --- Curse enchantments ---
		"annoying":
			e.enchant_name = "Annoying"
			e.color = Color(0.6, 0.6, 0.0)  # dull yellow
		"displacing":
			e.enchant_name = "Displacing"
			e.color = Color(0.4, 0.4, 0.7)  # lavender
		"dazzling":
			e.enchant_name = "Dazzling"
			e.color = Color(1.0, 1.0, 0.5)  # bright yellow
		"explosive":
			e.enchant_name = "Explosive"
			e.color = Color(0.9, 0.3, 0.1)  # fiery red
		"sacrificial":
			e.enchant_name = "Sacrificial"
			e.color = Color(0.5, 0.0, 0.0)  # blood red
		"wayward":
			e.enchant_name = "Wayward"
			e.color = Color(0.4, 0.6, 0.4)  # muted green
		"polarized":
			e.enchant_name = "Polarized"
			e.color = Color(0.8, 0.8, 0.9)  # pale blue
		"friendly":
			e.enchant_name = "Friendly"
			e.color = Color(0.9, 0.7, 0.8)  # pink
		_:
			push_warning("WeaponEnchantment.create: unknown id '%s'" % ench_id)
			e.enchant_name = ench_id.capitalize()

	# Mark curse enchantments
	if ench_id in CURSE_IDS:
		e.is_curse = true

	return e

## Create a random enchantment using SPD rarity weights, optionally excluding IDs.
## Distribution: Common 50%, Uncommon 40%, Rare 10%.
static func random(exclude: Array[String] = []) -> WeaponEnchantment:
	var roll: float = randf()
	var tier_pool: Array[String]
	if roll < 0.5:
		tier_pool = COMMON_IDS
	elif roll < 0.9:
		tier_pool = UNCOMMON_IDS
	else:
		tier_pool = RARE_IDS

	# Filter exclusions from the chosen tier
	var pool: Array[String] = []
	for eid: String in tier_pool:
		if eid not in exclude:
			pool.append(eid)
	# Fallback: if entire tier is excluded, pick from all non-excluded
	if pool.is_empty():
		for eid: String in ALL_IDS:
			if eid not in exclude:
				pool.append(eid)
	if pool.is_empty():
		pool = ALL_IDS.duplicate()
	return create(pool[randi() % pool.size()])

## Create a random curse enchantment, optionally excluding certain IDs.
static func random_curse(exclude: Array[String] = []) -> WeaponEnchantment:
	var pool: Array[String] = []
	for eid: String in CURSE_IDS:
		if eid not in exclude:
			pool.append(eid)
	if pool.is_empty():
		pool = CURSE_IDS.duplicate()
	return create(pool[randi() % pool.size()])

# ---------------------------------------------------------------------------
# Proc Implementations
# ---------------------------------------------------------------------------

## Overridden proc dispatches to the correct implementation based on enchant_id.
## This avoids needing separate script files for each enchantment while keeping
## the factory pattern clean.

func _blazing_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# 33% chance to ignite the defender, dealing bonus fire damage
	var bonus: int = 0
	if randf() < 0.33:
		bonus = maxi(1, int(damage * 0.25))
		if defender != null and defender.has_method("add_buff"):
			var burning: Variant = null
			# Try to create a Burning buff if the class exists
			if ClassDB.class_exists("Burning"):
				burning = ClassDB.instantiate("Burning")
			else:
				# Fallback: use script-based instantiation
				var script: GDScript = load("res://src/actors/buffs/burning.gd") as GDScript
				if script:
					burning = script.new()
			if burning != null:
				defender.add_buff(burning)
			if MessageLog:
				MessageLog.add("The weapon blazes with fire!")
		WeaponEnchantment._emit_proc("blazing", _attacker, defender)
	return damage + bonus

func _chilling_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# 33% chance to apply Cripple (slow) to defender
	if randf() < 0.33:
		if defender != null and defender.has_method("add_buff"):
			var script: GDScript = load("res://src/actors/buffs/cripple.gd") as GDScript
			if script:
				var cripple: Variant = script.new()
				if cripple.has_method("set_duration"):
					cripple.set_duration(5)
				defender.add_buff(cripple)
			if MessageLog:
				MessageLog.add("Frost radiates from the weapon!")
		WeaponEnchantment._emit_proc("chilling", _attacker, defender)
	return damage

func _shocking_proc(_weapon: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
	# Chain lightning: deal bonus damage to the defender and potentially nearby enemies.
	# For now, apply a flat bonus and flag the hit.
	var bonus: int = maxi(1, int(damage * 0.3))
	if defender != null and attacker != null:
		# In a full implementation this would find adjacent enemies and damage them too.
		if MessageLog:
			MessageLog.add("Lightning arcs from the weapon!")
	WeaponEnchantment._emit_proc("shocking", attacker, defender)
	return damage + bonus

func _lucky_proc(_weapon: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
	# 20% chance to critically strike for 2x damage
	if randf() < 0.20:
		if MessageLog:
			MessageLog.add("A lucky strike!")
		WeaponEnchantment._emit_proc("lucky", _attacker, _defender)
		return damage * 2
	return damage

func _projecting_proc(weapon: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
	# Projecting adds +1 reach (handled externally via reach property).
	# The proc itself simply returns unmodified damage; the reach bonus is
	# checked when validating attack range.
	if weapon != null and weapon.get("reach") != null:
		# Reach bonus is applied in MeleeWeapon.get_reach()
		pass
	return damage

func _unstable_proc(weapon: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
	# Pick a random OTHER enchantment and use its proc instead.
	var other_ids: Array[String] = []
	for eid: String in ALL_IDS:
		if eid != "unstable":
			other_ids.append(eid)
	var random_id: String = other_ids[randi() % other_ids.size()]
	var temp_ench: WeaponEnchantment = WeaponEnchantment.create(random_id)
	return temp_ench.proc(weapon, attacker, defender, damage)

func _grim_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# Chance to instantly kill enemies below 20% HP. Chance scales with how low they are.
	if defender == null:
		return damage
	var hp: int = defender.hp if defender.get("hp") != null else 999
	var ht: int = defender.ht if defender.get("ht") != null else 999
	var hp_ratio: float = float(hp) / float(maxi(1, ht))
	if hp_ratio < 0.2:
		var kill_chance: float = 0.5 * (1.0 - hp_ratio / 0.2)
		if randf() < kill_chance:
			if defender.has_method("die"):
				defender.die(_attacker)
				if MessageLog:
					MessageLog.add("The weapon reaps a soul!")
			WeaponEnchantment._emit_proc("grim", _attacker, defender)
			return 0
	return damage

func _vampiric_proc(_weapon: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
	# Heal the attacker for a portion of the damage dealt.
	var heal_amount: int = maxi(1, int(damage * 0.2))
	if _attacker != null and _attacker.has_method("heal"):
		_attacker.heal(heal_amount)
		if MessageLog:
			MessageLog.add("The weapon drains life force!")
	WeaponEnchantment._emit_proc("vampiric", _attacker, _defender)
	return damage

func _elastic_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# Knock the defender back 1-2 tiles.
	if defender != null and defender.has_method("move_to") and defender.get("pos") != null:
		if _attacker != null and _attacker.get("pos") != null:
			var atk_x: int = ConstantsData.pos_to_x(_attacker.pos)
			var atk_y: int = ConstantsData.pos_to_y(_attacker.pos)
			var def_x: int = ConstantsData.pos_to_x(defender.pos)
			var def_y: int = ConstantsData.pos_to_y(defender.pos)
			var dx: int = signi(def_x - atk_x)
			var dy: int = signi(def_y - atk_y)
			var new_x: int = def_x + dx
			var new_y: int = def_y + dy
			var new_pos: int = ConstantsData.xy_to_pos(new_x, new_y)
			if ConstantsData.is_valid_pos(new_pos):
				defender.move_to(new_pos)
				if MessageLog:
					MessageLog.add("The elastic force pushes the target back!")
	WeaponEnchantment._emit_proc("elastic", _attacker, defender)
	return damage

func _kinetic_proc(_weapon: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
	# Stores excess (overkill) damage and adds it to the next attack.
	# For now, 20% chance to deal 50% bonus damage (simplified kinetic energy storage).
	var bonus: int = 0
	if randf() < 0.20:
		bonus = maxi(1, int(damage * 0.5))
		if MessageLog:
			MessageLog.add("Kinetic energy surges through the weapon!")
		WeaponEnchantment._emit_proc("kinetic", _attacker, _defender)
	return damage + bonus

func _blocking_proc(_weapon: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
	# Grants a small shield (temporary armor) after hitting an enemy.
	# Shield amount = 2 + weapon level, lasts until next hit taken.
	if _attacker != null and _attacker.has_method("add_shielding"):
		var shield: int = 2
		if _weapon != null and _weapon.get("level") != null:
			shield += _weapon.level
		_attacker.add_shielding(shield)
		if MessageLog:
			MessageLog.add("Your weapon's blocking enchantment shields you!")
	WeaponEnchantment._emit_proc("blocking", _attacker, _defender)
	return damage

func _blooming_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# Plants grass on the defender's tile and adjacent tiles on proc.
	if defender != null and defender.get("pos") != null and defender.get("level") != null:
		var lvl: Variant = defender.level
		if lvl != null and lvl.has_method("set_terrain"):
			# Plant grass on defender's tile
			lvl.set_terrain(defender.pos, ConstantsData.Terrain.GRASS)
			if MessageLog:
				MessageLog.add("Grass sprouts from the impact!")
	WeaponEnchantment._emit_proc("blooming", _attacker, defender)
	return damage

func _corrupting_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# On kill, corrupt the enemy (handled at kill time). On hit, apply weakness.
	if defender != null and defender.has_method("add_buff"):
		if randf() < 0.25:
			var script: GDScript = load("res://src/actors/buffs/weakness.gd") as GDScript
			if script:
				var weak: Variant = script.new()
				if weak.has_method("set_duration"):
					weak.set_duration(5.0)
				defender.add_buff(weak)
			if MessageLog:
				MessageLog.add("Dark energy corrupts the target!")
	WeaponEnchantment._emit_proc("corrupting", _attacker, defender)
	return damage

func _annoying_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# Curse enchant: aggro all nearby enemies when proc fires.
	if MessageLog:
		MessageLog.add_negative("Your weapon emits an annoying screech!")
	WeaponEnchantment._emit_proc("annoying", _attacker, defender)
	return damage

func _sacrificial_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# Curse enchant: deal bonus damage but hurt the user too.
	var self_damage: int = maxi(1, int(damage * 0.15))
	if _attacker != null and _attacker.has_method("take_damage"):
		_attacker.take_damage(self_damage, null)
	if MessageLog:
		MessageLog.add_negative("Your cursed weapon bites into you!")
	WeaponEnchantment._emit_proc("sacrificial", _attacker, defender)
	return int(float(damage) * 1.3)

func _displacing_proc(_weapon: Variant, _attacker: Variant, defender: Variant, damage: int) -> int:
	# Curse enchant: teleport the defender to a random position on the level.
	if defender != null and defender.get("pos") != null and defender.get("level") != null:
		var lvl: Variant = defender.level
		if lvl != null and lvl.has_method("random_passable_cell"):
			var new_pos: int = lvl.random_passable_cell()
			if new_pos >= 0 and defender.has_method("move_to"):
				defender.move_to(new_pos)
				if MessageLog:
					MessageLog.add_negative("Your weapon teleports the enemy away!")
	WeaponEnchantment._emit_proc("displacing", _attacker, defender)
	return damage

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"enchant_id": enchant_id,
		"enchant_name": enchant_name,
		"is_curse": is_curse,
	}

func deserialize(data: Dictionary) -> void:
	enchant_id = data.get("enchant_id", "")
	enchant_name = data.get("enchant_name", "")
	is_curse = data.get("is_curse", false)
