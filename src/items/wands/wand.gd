class_name Wand
extends Item
## Base class for all wands. Wands have charges, can be zapped at target
## positions using Ballistica for trajectory, and recharge over time.

# --- Wand Properties ---
## Maximum charges this wand can hold.
var charges_max: int = 2
## Current charges available.
var charges: int = 2
## Accumulated fractional recharge progress toward next charge.
var _recharge_progress: float = 0.0
## Original recharge constants for scaling formula.
## turnsToCharge = BASE_CHARGE_DELAY + SCALING_CHARGE_ADDITION * NORMAL_SCALE^missingCharges
const BASE_CHARGE_DELAY: float = 10.0
const SCALING_CHARGE_ADDITION: float = 40.0
const NORMAL_SCALE_FACTOR: float = 0.875
## Whether the wand produces a cursed (harmful to user) effect when zapped.
var cursed_effect: bool = false
## Use-based identification tracking. Wands identify through repeated zaps.
## Mirrors SPD: USES_TO_ID uses required, but only USES_TO_ID/2 are available
## up front; the rest of the pool refills as the hero earns XP (see
## on_hero_gain_exp), so a wand can't be spam-identified in one fight yet still
## identifies through continued play.
const USES_TO_ID: float = 10.0
var _uses_left_to_id: float = USES_TO_ID
var _available_uses_to_id: float = USES_TO_ID / 2.0

func _init() -> void:
	category = ConstantsData.ItemCategory.WAND
	default_action = "ZAP"
	stackable = false

func is_equippable() -> bool:
	return true

# ---------------------------------------------------------------------------
# Charges
# ---------------------------------------------------------------------------

## Recalculate max charges based on level. Base is 2 + level.
func _update_max_charges() -> void:
	charges_max = 2 + level

## Spend one charge. Returns true if a charge was available to spend.
func spend_charge() -> bool:
	if charges <= 0:
		return false
	charges -= 1
	return true

## Recharge the wand over time. Called once per hero turn.
## Uses the original's scaling formula: turnsToCharge increases as the wand gets fuller.
## turnsToCharge = BASE_CHARGE_DELAY + SCALING_CHARGE_ADDITION * NORMAL_SCALE^missingCharges
func recharge(turns: int = 1, hero: Char = null) -> void:
	if charges >= charges_max:
		return
	var missing_charges: int = maxi(0, charges_max - charges)
	var turns_to_charge: float = BASE_CHARGE_DELAY + SCALING_CHARGE_ADDITION * pow(NORMAL_SCALE_FACTOR, missing_charges)
	var charge_per_turn: float = 1.0 / turns_to_charge
	# Ring of Energy bonus multiplier
	if hero != null and hero.has_method("get_buff"):
		var energy_buff: Variant = hero.get_buff("RingOfEnergy")
		if energy_buff != null and energy_buff.get("ring") != null:
			var ring: Variant = energy_buff.ring
			if ring.has_method("bonus"):
				var b: int = ring.bonus()
				charge_per_turn *= pow(1.2, maxf(0.0, float(b)))
		var recharging_buff: Variant = hero.get_buff("Recharging")
		if recharging_buff != null and recharging_buff.has_method("recharge_rate"):
			charge_per_turn *= float(recharging_buff.recharge_rate())
		var battlemage_buff: Variant = hero.get_buff("BattemagePower")
		if battlemage_buff != null and battlemage_buff.has_method("wand_recharge_multiplier"):
			charge_per_turn *= float(battlemage_buff.wand_recharge_multiplier())
	_recharge_progress += charge_per_turn * float(turns)
	while _recharge_progress >= 1.0 and charges < charges_max:
		_recharge_progress -= 1.0
		charges += 1
	if charges >= charges_max:
		_recharge_progress = 0.0

# ---------------------------------------------------------------------------
# Zap
# ---------------------------------------------------------------------------

## Fire the wand at a target position. Uses Ballistica for pathing.
func zap(hero: Char, target_pos: int) -> void:
	if hero == null:
		return
	if charges <= 0:
		if MessageLog:
			MessageLog.add_warning("The %s has no charges left!" % item_name)
		return
	# Cursed wands may backfire
	if cursed and not cursed_known:
		cursed_known = true
	if cursed_effect or (cursed and randf() < 0.35):
		_cursed_zap(hero)
		spend_charge()
		_use_for_identification()
		return
	# Build trajectory via Ballistica
	var path: Array[int] = _build_zap_path(hero, target_pos)
	if path.is_empty():
		if MessageLog:
			MessageLog.add_warning("There is nothing to target there.")
		return
	spend_charge()
	on_zap(hero, path)
	_use_for_identification()
	if MessageLog:
		MessageLog.add("You zap the %s." % item_name)
	if EventBus:
		EventBus.item_used.emit(get_display_name())

func _use_for_identification() -> void:
	if identified or is_identified():
		return
	if _available_uses_to_id <= 0.0:
		return
	_available_uses_to_id -= 1.0
	_uses_left_to_id -= 1.0
	if _uses_left_to_id <= 0.0:
		identify()
		if MessageLog:
			MessageLog.add_positive("You have identified the %s." % item_name)

## Regenerate the use-based-ID pool as the hero earns XP. Mirrors SPD
## Wand.onHeroGainExp: availableUsesToID refills toward USES_TO_ID/2 by
## level_percent * USES_TO_ID/2 (capped at the half-pool). [level_percent] is the
## fraction of the current level's XP requirement just earned. Without this the
## pool empties after USES_TO_ID/2 zaps and the wand can never identify by use.
func on_hero_gain_exp(level_percent: float) -> void:
	if identified or is_identified():
		return
	if _available_uses_to_id <= USES_TO_ID / 2.0:
		_available_uses_to_id = minf(USES_TO_ID / 2.0,
			_available_uses_to_id + level_percent * USES_TO_ID / 2.0)

## Build the zap trajectory using Ballistica. Returns the subpath.
func _build_zap_path(hero: Char, target_pos: int) -> Array[int]:
	if hero == null:
		return [] as Array[int]
	var hero_pos: int = hero.pos if hero.get("pos") != null else 0
	var lvl: Variant = hero.get("level")
	if lvl == null or lvl.get("passable") == null:
		# Fallback: direct line with no obstacles
		return Ballistica.cast_line(hero_pos, target_pos,
			_make_open_passable(), Ballistica.MAGIC_BOLT)
	var passable_arr: Array[bool] = lvl.passable
	return Ballistica.cast_line(hero_pos, target_pos, passable_arr,
		Ballistica.MAGIC_BOLT | Ballistica.IGNORE_SOFT_SOLID, [], ConstantsData.WIDTH, lvl.map if lvl.get("map") != null else [])

## Generate a fully-open passable array for fallback.
func _make_open_passable() -> Array[bool]:
	var p: Array[bool] = []
	p.resize(ConstantsData.LENGTH)
	p.fill(true)
	return p

## Virtual: subclass override for the actual zap effect.
## [path] is the list of cell positions from source toward target.
func on_zap(_hero: Char, _path: Array[int]) -> void:
	pass

## Cursed wap backfire — random negative effect on the caster.
func _cursed_zap(hero: Char) -> void:
	if hero == null:
		return
	if MessageLog:
		MessageLog.add_negative("The %s backfires!" % item_name)
	# Cursed wands deal damage to the user
	var dmg: int = randi_range(level + 1, (level + 1) * 3)
	if hero.has_method("take_damage"):
		hero.take_damage(dmg, self)

# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## Virtual: returns [min, max] damage for the wand bolt at given level.
## Override in each wand subclass.
func get_damage(lvl: int) -> Array[int]:
	return [1 + lvl, 2 + lvl * 2] as Array[int]

## Roll damage for a zap using get_damage().
func roll_zap_damage() -> int:
	var dmg_range: Array[int] = get_damage(level)
	return randi_range(dmg_range[0], dmg_range[1])

# ---------------------------------------------------------------------------
# Equip / Unequip
# ---------------------------------------------------------------------------

func on_equip(hero: Char) -> void:
	super.on_equip(hero)
	# Mage class gets a bonus charge when equipping a wand
	if hero != null and hero.get("hero_class") == ConstantsData.HeroClass.MAGE:
		charges_max += 1
		charges += 1

func on_unequip(hero: Char) -> void:
	# Remove mage bonus charge
	if hero != null and hero.get("hero_class") == ConstantsData.HeroClass.MAGE:
		charges_max = maxi(1, charges_max - 1)
		charges = mini(charges, charges_max)
	super.on_unequip(hero)

# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

func upgrade() -> Item:
	# Original Wand.upgrade(): 33% chance to remove curse (Random.Int(3) == 0),
	# NOT unconditional uncurse like weapons/armor.
	var was_cursed: bool = cursed
	super.upgrade()  # This sets cursed = false unconditionally
	if was_cursed and randi() % 3 != 0:
		cursed = true  # Restore curse — the 33% roll failed
	_update_max_charges()
	# Original: curCharges = min(curCharges + 1, maxCharges) — adds 1 charge, NOT full recharge
	charges = mini(charges + 1, charges_max)
	return self

func is_upgradeable() -> bool:
	return true

## Apply random upgrade and curse chances matching original Wand.random().
## +0: 66.67% (2/3), +1: 26.67% (4/15), +2: 6.67% (1/15). 30% cursed.
func random() -> Wand:
	var n: int = 0
	if randi() % 3 == 0:
		n += 1
		if randi() % 5 == 0:
			n += 1
	level = n
	_update_max_charges()
	charges = charges_max
	if randf() < 0.3:
		cursed = true
	return self

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------


## Gain charges (from battlemage passive, etc.).
func gain_charge(amount: int = 1) -> void:
	charges = mini(charges + amount, charges_max)

## On-hit effect triggered by battlemage staff melee. Override in subclasses.
func on_hit_effect(target: Variant) -> void:
	# Base implementation: deal minor zap damage
	if target != null and target.has_method("take_damage"):
		var dmg: int = maxi(1, int(float(roll_zap_damage()) / 3.0))
		target.take_damage(dmg, null)

## Get stats text for the item detail window.
func get_stats_text() -> String:
	var dmg: Array[int] = get_damage(level)
	return "Damage: %d-%d  Charges: %d/%d" % [dmg[0], dmg[1], charges, charges_max]

func get_display_name() -> String:
	var base: String = super.get_display_name()
	if identified:
		base += " [%d/%d]" % [charges, charges_max]
	return base

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	return 75 * (level + 1)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["charges_max"] = charges_max
	data["charges"] = charges
	data["_recharge_progress"] = _recharge_progress
	data["cursed_effect"] = cursed_effect
	data["_uses_left_to_id"] = _uses_left_to_id
	data["_available_uses_to_id"] = _available_uses_to_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	charges_max = data.get("charges_max", 2)
	charges = data.get("charges", 2)
	_recharge_progress = data.get("_recharge_progress", 0.0)
	cursed_effect = data.get("cursed_effect", false)
	_uses_left_to_id = data.get("_uses_left_to_id", 10.0)
	_available_uses_to_id = data.get("_available_uses_to_id", 5.0)

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a wand by ID string. Returns null for unknown IDs.
static func create(wand_id: String) -> Wand:
	var wand: Wand = null
	match wand_id:
		"wand_of_magic_missile":
			wand = WandOfMagicMissile.new()
		"wand_of_fire_bolt":
			wand = WandOfFireBolt.new()
		"wand_of_frost":
			wand = WandOfFrost.new()
		"wand_of_lightning":
			wand = WandOfLightning.new()
		"wand_of_disintegration":
			wand = WandOfDisintegration.new()
		"wand_of_corrosion":
			wand = WandOfCorrosion.new()
		"wand_of_living_earth":
			wand = WandOfLivingEarth.new()
		"wand_of_blast_wave":
			wand = WandOfBlastWave.new()
		"wand_of_prismatic_light":
			wand = WandOfPrismaticLight.new()
		"wand_of_warding":
			wand = WandOfWarding.new()
		"wand_of_transfusion":
			wand = WandOfTransfusion.new()
		"wand_of_corruption":
			wand = WandOfCorruption.new()
		"wand_of_regrowth":
			wand = WandOfRegrowth.new()
	return wand

# ===========================================================================
# WAND SUBCLASSES
# ===========================================================================

# ---------------------------------------------------------------------------
# Wand of Magic Missile — pure damage, the starter wand
# ---------------------------------------------------------------------------

class WandOfMagicMissile extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_magic_missile"
		item_name = "Wand of Magic Missile"
		description = "This wand fires a bolt of pure magical energy. " \
			+ "While lacking any special effect, it deals reliable damage " \
			+ "and is the simplest wand to master."
		icon_color = Color(0.9, 0.9, 1.0)

	func get_damage(lvl: int) -> Array[int]:
		# 2-8 base, +2 per level on both ends
		return [2 + 2 * lvl, 8 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var dmg: int = roll_zap_damage()
		_hit_char_at(hero, target_pos, dmg)

	func _hit_char_at(hero: Char, pos: int, dmg: int) -> void:
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		var target_char: Variant = lvl.find_char_at(pos)
		if target_char != null and target_char.has_method("take_damage"):
			target_char.take_damage(dmg, hero)
			if MessageLog:
				MessageLog.add("The magic missile hits for %d damage." % dmg)
		else:
			if MessageLog:
				MessageLog.add("The magic missile dissipates harmlessly.")

# ---------------------------------------------------------------------------
# Wand of Fire Bolt — fire damage + burning debuff
# ---------------------------------------------------------------------------

class WandOfFireBolt extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_fire_bolt"
		item_name = "Wand of Fire Bolt"
		description = "This wand unleashes a searing bolt of flame that " \
			+ "deals fire damage on impact and sets the target ablaze. " \
			+ "Burning targets take additional damage over several turns."
		icon_color = Color(1.0, 0.4, 0.0)

	func get_damage(lvl: int) -> Array[int]:
		# 1-8 base, +2 per level on max
		return [1 + lvl, 8 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var dmg: int = roll_zap_damage()
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		var target_char: Variant = lvl.find_char_at(target_pos)
		if target_char != null and target_char.has_method("take_damage"):
			target_char.take_damage(dmg, hero)
			# Apply burning
			if target_char.has_method("add_buff"):
				var burn: Burning = Burning.new()
				target_char.add_buff(burn)
			if MessageLog:
				MessageLog.add("The fire bolt sears for %d damage!" % dmg)
			# Set terrain on fire (high grass -> embers)
			if lvl.has_method("get_terrain") and lvl.has_method("set_terrain"):
				if lvl.get_terrain(target_pos) == ConstantsData.Terrain.HIGH_GRASS:
					lvl.set_terrain(target_pos, ConstantsData.Terrain.EMBERS)

# ---------------------------------------------------------------------------
# Wand of Frost — cold damage + chill/freeze, area effect
# ---------------------------------------------------------------------------

class WandOfFrost extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_frost"
		item_name = "Wand of Frost"
		description = "This wand fires a freezing bolt that chills targets " \
			+ "on impact, slowing their movement and attack speed. " \
			+ "Already-chilled targets may be frozen solid."
		icon_color = Color(0.5, 0.8, 1.0)

	func get_damage(lvl: int) -> Array[int]:
		return [2 + lvl, 8 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var dmg: int = roll_zap_damage()
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		# Hit the primary target
		var target_char: Variant = lvl.find_char_at(target_pos)
		if target_char != null and target_char.has_method("take_damage"):
			target_char.take_damage(dmg, hero)
			# Apply chill (use Cripple as cold-slow approximation)
			if target_char.has_method("add_buff"):
				# Capture the chilled state BEFORE applying this hit's Cripple —
				# SPD only freezes a target that was already chilled (Frost.freeze).
				var was_chilled: bool = target_char.has_method("has_buff") \
						and target_char.has_buff("Cripple")
				var chill: Cripple = Cripple.new()
				chill.set_duration(5.0 + float(level) * 2.0)
				target_char.add_buff(chill)
				# If it was already crippled before this bolt, freeze (paralyze).
				if was_chilled:
					var freeze: Paralysis = Paralysis.new()
					freeze.set_duration(3.0 + float(level))
					target_char.add_buff(freeze)
			if MessageLog:
				MessageLog.add("The frost bolt freezes for %d damage!" % dmg)
		# Freeze water tiles in area (adjacent cells)
		for dir: int in ConstantsData.DIRS_8:
			var adj: int = target_pos + dir
			if not ConstantsData.is_valid_pos(adj):
				continue
			if lvl.has_method("get_terrain") and lvl.has_method("set_terrain"):
				if lvl.get_terrain(adj) == ConstantsData.Terrain.WATER:
					# Frozen water becomes empty (ice)
					lvl.set_terrain(adj, ConstantsData.Terrain.EMPTY)

# ---------------------------------------------------------------------------
# Wand of Lightning — chain lightning between targets
# ---------------------------------------------------------------------------

class WandOfLightning extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_lightning"
		item_name = "Wand of Lightning"
		description = "This wand discharges a powerful bolt of lightning " \
			+ "that arcs between nearby targets. Each chain deals slightly " \
			+ "less damage, but a crowd of enemies is in for a shocking time."
		icon_color = Color(1.0, 1.0, 0.5)

	func get_damage(lvl: int) -> Array[int]:
		return [3 + lvl, 10 + 3 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return

		# Chain lightning: hit primary, then arc to nearby chars
		var hit_positions: Array[int] = []
		var current_pos: int = target_pos
		var max_arcs: int = 3 + level
		var damage_multi: float = 1.0

		for _arc: int in range(max_arcs):
			if not ConstantsData.is_valid_pos(current_pos):
				break
			if current_pos in hit_positions:
				break
			hit_positions.append(current_pos)

			var target_char: Variant = lvl.find_char_at(current_pos)
			if target_char != null and target_char.has_method("take_damage"):
				var dmg: int = int(float(roll_zap_damage()) * damage_multi)
				target_char.take_damage(dmg, hero)
				if MessageLog:
					MessageLog.add("Lightning arcs for %d damage!" % dmg)

			# Find next closest char to arc to
			damage_multi *= 0.7  # Each arc deals 30% less
			var next_pos: int = _find_nearest_char(lvl, current_pos, hit_positions)
			if next_pos < 0:
				break
			current_pos = next_pos

		# Lightning also hits the caster if standing in water
		if hero != null and hero.get("pos") != null:
			var hero_pos: int = hero.pos
			if lvl.has_method("get_terrain") and lvl.get_terrain(hero_pos) == ConstantsData.Terrain.WATER:
				if hero_pos not in hit_positions:
					var self_dmg: int = int(float(roll_zap_damage()) * 0.5)
					hero.take_damage(self_dmg, self)
					if MessageLog:
						MessageLog.add_warning("The lightning shocks you too!")

	func _find_nearest_char(lvl: Variant, from_pos: int, exclude: Array[int]) -> int:
		# Search in a 4-cell radius for another character
		var best_pos: int = -1
		var best_dist: float = 999.0
		for dy: int in range(-4, 5):
			for dx: int in range(-4, 5):
				if dx == 0 and dy == 0:
					continue
				var x: int = ConstantsData.pos_to_x(from_pos) + dx
				var y: int = ConstantsData.pos_to_y(from_pos) + dy
				if x < 0 or x >= ConstantsData.WIDTH or y < 0 or y >= ConstantsData.HEIGHT:
					continue
				var check_pos: int = ConstantsData.xy_to_pos(x, y)
				if check_pos in exclude:
					continue
				if lvl.has_method("find_char_at"):
					var ch: Variant = lvl.find_char_at(check_pos)
					if ch != null:
						var d: float = Ballistica.distance(from_pos, check_pos)
						if d < best_dist:
							best_dist = d
							best_pos = check_pos
		return best_pos

# ---------------------------------------------------------------------------
# Wand of Disintegration — beam through walls, ignores armor
# ---------------------------------------------------------------------------

class WandOfDisintegration extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_disintegration"
		item_name = "Wand of Disintegration"
		description = "This wand fires a beam of destructive energy that " \
			+ "passes through everything in its path, ignoring walls and " \
			+ "armor. All characters along the beam take full damage."
		icon_color = Color(0.6, 0.0, 0.6)

	func get_damage(lvl: int) -> Array[int]:
		return [2 + lvl, 8 + 3 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		# Disintegration is a beam — cast through walls (ignore solid stops)
		var hero_pos: int = hero.pos if hero.get("pos") != null else 0
		var target_pos: int = path[path.size() - 1]
		# Build a full beam path that ignores walls
		var beam_path: Array[int] = Ballistica.cast_line(
			hero_pos, target_pos, _make_open_passable(), Ballistica.STOP_TARGET)
		# Damage every character along the entire beam
		var base_dmg: int = roll_zap_damage()
		# Damage increases with beam length (2% per cell)
		var distance_bonus: float = 1.0 + 0.02 * float(beam_path.size())
		var total_dmg: int = int(float(base_dmg) * distance_bonus)
		var hit_any: bool = false
		for cell_pos: int in beam_path:
			var target_char: Variant = lvl.find_char_at(cell_pos)
			if target_char != null and target_char.has_method("take_damage"):
				# Disintegration ignores physical armor, but still routes through
				# the shared magical damage pipeline for shielding and resistances.
				target_char.take_damage(total_dmg, hero)
				hit_any = true
				if MessageLog:
					MessageLog.add("The disintegration beam hits for %d damage!" % total_dmg)
			# Destroy barricades and bookshelves in the path
			if lvl.has_method("get_terrain") and lvl.has_method("set_terrain"):
				var terrain: int = lvl.get_terrain(cell_pos)
				if terrain == ConstantsData.Terrain.BARRICADE \
						or terrain == ConstantsData.Terrain.BOOKSHELF:
					lvl.set_terrain(cell_pos, ConstantsData.Terrain.EMBERS)
		if not hit_any and MessageLog:
			MessageLog.add("The beam cuts through the air.")

# ---------------------------------------------------------------------------
# Wand of Corrosion — acid blob, armor-ignoring DoT
# ---------------------------------------------------------------------------

class WandOfCorrosion extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_corrosion"
		item_name = "Wand of Corrosion"
		description = "This wand launches a blob of caustic acid that " \
			+ "spreads corrosive gas on impact. The gas ignores armor and " \
			+ "deals damage over time to anything caught in the cloud."
		icon_color = Color(0.6, 0.8, 0.0)

	func get_damage(lvl: int) -> Array[int]:
		# Corrosion does DoT, so per-tick damage is lower
		return [1 + lvl, 3 + lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null:
			return
		# Apply corrosion (Poison buff) to target and adjacent cells
		var affected: Array[int] = [target_pos]
		for dir: int in ConstantsData.DIRS_4:
			var adj: int = target_pos + dir
			if ConstantsData.is_valid_pos(adj):
				affected.append(adj)
		for cell_pos: int in affected:
			if not lvl.has_method("find_char_at"):
				continue
			var target_char: Variant = lvl.find_char_at(cell_pos)
			if target_char != null and target_char.has_method("add_buff"):
				var acid: Poison = Poison.new()
				acid.set_duration(4.0 + float(level) * 2.0)
				target_char.add_buff(acid)
				if MessageLog and cell_pos == target_pos:
					MessageLog.add("Caustic acid splashes on the target!")
		# Also warn caster if they are in the cloud
		if hero != null and hero.get("pos") != null:
			if hero.pos in affected:
				if MessageLog:
					MessageLog.add_warning("Careful! You're in the corrosion cloud!")

# ---------------------------------------------------------------------------
# Wand of Living Earth — summon rock guardian / grant shielding
# ---------------------------------------------------------------------------

class WandOfLivingEarth extends Wand:
	## Tracks accumulated earth armor for the rock guardian.
	var _guardian_shield: int = 0

	func _init() -> void:
		super._init()
		item_id = "wand_of_living_earth"
		item_name = "Wand of Living Earth"
		description = "This wand draws power from the earth itself, " \
			+ "striking the target with a rocky projectile and granting " \
			+ "the caster a temporary rock shield. Accumulating enough " \
			+ "earth energy will summon a guardian of living stone."
		icon_color = Color(0.55, 0.35, 0.15)

	func get_damage(lvl: int) -> Array[int]:
		return [2 + lvl, 6 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var dmg: int = roll_zap_damage()
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl != null and lvl.has_method("find_char_at"):
			var target_char: Variant = lvl.find_char_at(target_pos)
			if target_char != null and target_char.has_method("take_damage"):
				target_char.take_damage(dmg, hero)
				if MessageLog:
					MessageLog.add("Rocks slam into the target for %d damage!" % dmg)
		# Grant shielding to the caster
		var shield_amount: int = dmg
		_guardian_shield += shield_amount
		var max_shield: int = 8 + level * 4
		if hero != null and hero.get("shielding") != null:
			hero.shielding += mini(shield_amount, max_shield - hero.shielding)
			hero.shielding = mini(hero.shielding, max_shield)
			if MessageLog:
				MessageLog.add_positive("Earth armor surrounds you! (+%d shield)" % shield_amount)

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["_guardian_shield"] = _guardian_shield
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		_guardian_shield = data.get("_guardian_shield", 0)

# ---------------------------------------------------------------------------
# Wand of Blast Wave — knockback + damage
# ---------------------------------------------------------------------------

class WandOfBlastWave extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_blast_wave"
		item_name = "Wand of Blast Wave"
		description = "This wand releases a concussive blast that deals " \
			+ "moderate damage and violently knocks targets backward. " \
			+ "Targets slammed into walls take bonus impact damage."
		icon_color = Color(0.9, 0.7, 0.3)

	func get_damage(lvl: int) -> Array[int]:
		return [1 + lvl, 5 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var dmg: int = roll_zap_damage()
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		var hero_pos: int = hero.pos if hero.get("pos") != null else 0
		var target_char: Variant = lvl.find_char_at(target_pos)
		if target_char != null and target_char.has_method("take_damage"):
			target_char.take_damage(dmg, hero)
			if MessageLog:
				MessageLog.add("The blast wave hits for %d damage!" % dmg)
			# Knockback: push target away from caster
			var knockback: int = 2 + level
			_apply_knockback(lvl, target_char, hero_pos, target_pos, knockback)
		else:
			if MessageLog:
				MessageLog.add("The blast wave echoes off the walls.")

	func _apply_knockback(lvl: Variant, target_char: Variant,
			from_pos: int, char_pos: int, distance: int) -> void:
		if target_char == null or not target_char.has_method("move_to"):
			return
		# Determine knockback direction (away from caster)
		var fx: int = ConstantsData.pos_to_x(from_pos)
		var fy: int = ConstantsData.pos_to_y(from_pos)
		var tx: int = ConstantsData.pos_to_x(char_pos)
		var ty: int = ConstantsData.pos_to_y(char_pos)
		var dx: int = signi(tx - fx)
		var dy: int = signi(ty - fy)
		if dx == 0 and dy == 0:
			return
		var current_pos: int = char_pos
		for _step: int in range(distance):
			var nx: int = ConstantsData.pos_to_x(current_pos) + dx
			var ny: int = ConstantsData.pos_to_y(current_pos) + dy
			if nx < 0 or nx >= ConstantsData.WIDTH or ny < 0 or ny >= ConstantsData.HEIGHT:
				# Slammed into edge — bonus damage
				_wall_slam(target_char)
				break
			var next_pos: int = ConstantsData.xy_to_pos(nx, ny)
			if lvl.has_method("is_passable") and not lvl.is_passable(next_pos):
				_wall_slam(target_char)
				break
			if lvl.has_method("find_char_at") and lvl.find_char_at(next_pos) != null:
				break  # Blocked by another character
			target_char.move_to(next_pos)
			current_pos = next_pos

	func _wall_slam(target_char: Variant) -> void:
		if target_char == null or not target_char.has_method("take_damage"):
			return
		var slam_dmg: int = randi_range(level + 2, (level + 2) * 2)
		target_char.take_damage(slam_dmg, self)
		# Paralyze briefly from impact
		if target_char.has_method("add_buff"):
			var stun: Paralysis = Paralysis.new()
			stun.set_duration(2.0)
			target_char.add_buff(stun)
		if MessageLog:
			MessageLog.add("Slammed into a wall for %d bonus damage!" % slam_dmg)

# ---------------------------------------------------------------------------
# Wand of Prismatic Light — blind + damage, bonus vs undead/demonic
# ---------------------------------------------------------------------------

class WandOfPrismaticLight extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_prismatic_light"
		item_name = "Wand of Prismatic Light"
		description = "This wand projects a dazzling beam of prismatic light " \
			+ "that damages and blinds targets. Undead and demonic creatures " \
			+ "are especially vulnerable to its radiant energy."
		icon_color = Color(1.0, 1.0, 1.0)

	func get_damage(lvl: int) -> Array[int]:
		return [2 + lvl, 8 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		# Beam: hit every character along the path
		for cell_pos: int in path:
			var target_char: Variant = lvl.find_char_at(cell_pos)
			if target_char == null or not target_char.has_method("take_damage"):
				continue
			var dmg: int = roll_zap_damage()
			# Bonus damage vs undead/demonic mobs
			if target_char.has_method("get") and target_char.get("mob_type") != null:
				var mob_type: Variant = target_char.mob_type
				if mob_type is String:
					var type_str: String = mob_type as String
					if type_str == "undead" or type_str == "demonic":
						dmg = int(float(dmg) * 1.5)
						if MessageLog:
							MessageLog.add_positive("The light sears the %s!" \
								% (target_char.name if target_char.get("name") else "creature"))
			target_char.take_damage(dmg, hero)
			# Apply blindness
			if target_char.has_method("add_buff"):
				var blind: Blindness = Blindness.new()
				blind.set_duration(3.0 + float(level) * 2.0)
				target_char.add_buff(blind)
			if MessageLog:
				MessageLog.add("Prismatic light flashes for %d damage!" % dmg)
		# Illuminate the area (reveal hidden traps/doors)
		var end_pos: int = path[path.size() - 1]
		for dir: int in ConstantsData.DIRS_8:
			var adj: int = end_pos + dir
			if not ConstantsData.is_valid_pos(adj):
				continue
			if lvl.has_method("get_terrain") and lvl.has_method("set_terrain"):
				var terrain: int = lvl.get_terrain(adj)
				if terrain == ConstantsData.Terrain.SECRET_DOOR:
					lvl.set_terrain(adj, ConstantsData.Terrain.DOOR)
					if MessageLog:
						MessageLog.add_positive("The light reveals a hidden door!")
				elif terrain == ConstantsData.Terrain.SECRET_TRAP:
					lvl.set_terrain(adj, ConstantsData.Terrain.TRAP)
					if MessageLog:
						MessageLog.add_positive("The light reveals a hidden trap!")

# ---------------------------------------------------------------------------
# Wand of Warding — place magical sentries
# ---------------------------------------------------------------------------

class WandOfWarding extends Wand:
	## Track placed sentry positions for this wand.
	var _sentry_positions: Array[int] = []
	const MAX_SENTRIES: int = 3

	func _init() -> void:
		super._init()
		item_id = "wand_of_warding"
		item_name = "Wand of Warding"
		description = "This wand conjures a magical ward sentry at the " \
			+ "target location. Sentries zap enemies that come within " \
			+ "range. Upgrading the wand creates stronger sentries."
		icon_color = Color(0.4, 0.6, 0.4)

	func get_damage(lvl: int) -> Array[int]:
		# Sentry damage per zap
		return [2 + lvl, 5 + 2 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null:
			return
		# Check if target position already has a sentry — upgrade it
		if target_pos in _sentry_positions:
			if MessageLog:
				MessageLog.add_positive("The ward is reinforced!")
			return
		# Check if a character occupies the target
		if lvl.has_method("find_char_at") and lvl.find_char_at(target_pos) != null:
			if MessageLog:
				MessageLog.add_warning("Can't place a ward there — something is in the way.")
			return
		# Check passability
		if lvl.has_method("is_passable") and not lvl.is_passable(target_pos):
			if MessageLog:
				MessageLog.add_warning("Can't place a ward on solid terrain.")
			return
		# Remove oldest sentry (and its actor) if at capacity.
		var cap: int = MAX_SENTRIES + level
		while _sentry_positions.size() >= cap:
			var oldest: int = _sentry_positions.pop_front()
			_despawn_sentry_at(lvl, oldest)
		# Spawn a real sentry actor that zaps enemies each turn.
		var dmg_range: Array[int] = get_damage(level)
		WardSentry.spawn_at(target_pos, lvl, hero, level, dmg_range[0], dmg_range[1])
		_sentry_positions.append(target_pos)
		if MessageLog:
			MessageLog.add_positive("A magical ward sentry appears! " \
				+ "(%d/%d active)" % [_sentry_positions.size(), cap])

	## Remove the sentry actor occupying [cell], if any, so the wand's tracked
	## positions stay in sync with the live actors when it hits its cap.
	func _despawn_sentry_at(lvl: Variant, cell: int) -> void:
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		var occupant: Variant = lvl.find_char_at(cell)
		if occupant is WardSentry:
			(occupant as WardSentry)._on_death(null)

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["_sentry_positions"] = _sentry_positions
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		var sp: Variant = data.get("_sentry_positions", [])
		_sentry_positions.clear()
		if sp is Array:
			for p: Variant in sp:
				if p is int:
					_sentry_positions.append(p as int)

# ---------------------------------------------------------------------------
# Wand of Transfusion — heal ally or drain enemy, lifesteal
# ---------------------------------------------------------------------------

class WandOfTransfusion extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_transfusion"
		item_name = "Wand of Transfusion"
		description = "This wand transfers life force between the caster " \
			+ "and the target. When aimed at an enemy, it drains their " \
			+ "health and heals the caster. Aimed at an ally, it transfers " \
			+ "the caster's health to heal them instead."
		icon_color = Color(0.9, 0.1, 0.1)

	func get_damage(lvl: int) -> Array[int]:
		# Drain/heal amount
		return [3 + 2 * lvl, 8 + 3 * lvl] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		var target_char: Variant = lvl.find_char_at(target_pos)
		if target_char == null:
			if MessageLog:
				MessageLog.add("The transfusion bolt fizzles.")
			return
		var amount: int = roll_zap_damage()
		# Check if target is hostile (mobs) or friendly
		var is_enemy: bool = true
		if target_char.get("is_hero") == true:
			is_enemy = false  # Another hero (multiplayer ally)
		if is_enemy:
			# Drain enemy: deal damage and heal caster
			if target_char.has_method("take_damage"):
				var actual: int = target_char.take_damage(amount, hero)
				if hero.has_method("heal"):
					hero.heal(actual)
				if MessageLog:
					MessageLog.add("You drain %d life force!" % actual)
				# Apply charm to make enemy briefly confused
				if target_char.has_method("add_buff"):
					var c: Charm = Charm.new()
					c.set_duration(2.0 + float(level))
					target_char.add_buff(c)
		else:
			# Heal ally: transfer caster HP to ally
			var transfer: int = mini(amount, hero.hp - 1)
			if transfer <= 0:
				if MessageLog:
					MessageLog.add_warning("You don't have enough health to transfer!")
				return
			if hero.has_method("take_damage"):
				hero.take_damage(transfer, self)
			if target_char.has_method("heal"):
				target_char.heal(transfer)
			if MessageLog:
				MessageLog.add_positive("You transfer %d health to your ally!" % transfer)

# ---------------------------------------------------------------------------
# Wand of Corruption — convert enemy to ally
# ---------------------------------------------------------------------------

class WandOfCorruption extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_corruption"
		item_name = "Wand of Corruption"
		description = "This wand attempts to bend the mind of an enemy, " \
			+ "turning them into an ally. Weaker enemies are easier to " \
			+ "corrupt, while powerful foes may only be briefly confused. " \
			+ "Already-debuffed enemies are much easier to corrupt."
		icon_color = Color(0.3, 0.0, 0.3)

	func get_damage(_lvl: int) -> Array[int]:
		# Corruption doesn't deal direct damage
		return [0, 0] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null or not lvl.has_method("find_char_at"):
			return
		var target_char: Variant = lvl.find_char_at(target_pos)
		if target_char == null or target_char.get("is_hero") == true:
			if MessageLog:
				MessageLog.add("The corruption bolt has no valid target.")
			return
		if not target_char.has_method("take_damage"):
			return
		# Bosses and already-corrupted allies cannot be corrupted (SPD parity).
		if target_char.has_method("is_boss") and target_char.is_boss():
			if MessageLog:
				MessageLog.add("The %s is too powerful to corrupt!" \
					% (target_char.name if target_char.get("name") else "enemy"))
			return
		if target_char.get("is_ally") == true or target_char.has_buff("Corruption"):
			if MessageLog:
				MessageLog.add("The %s is already on your side." \
					% (target_char.name if target_char.get("name") else "enemy"))
			return
		# Corruption chance based on enemy HP ratio and wand level
		var hp_ratio: float = float(target_char.hp) / float(maxi(1, target_char.hp_max))
		var corrupt_power: float = float(level + 1) * 10.0
		# Debuffed enemies are easier to corrupt
		var debuff_count: int = 0
		if target_char.has_method("get_buffs"):
			for b: Node in target_char.get_buffs():
				if b.get("is_debuff") == true:
					debuff_count += 1
		corrupt_power += float(debuff_count) * 15.0
		var resist: float = float(target_char.hp_max) * hp_ratio
		if corrupt_power >= resist:
			# Full corruption — convert to a real ally via CorruptionBuff, which
			# flips the mob's alignment through the Mob ally mechanism.
			if target_char.has_method("add_buff"):
				target_char.add_buff(CorruptionBuff.new())
		else:
			# Partial corruption — apply terror and weakness
			if target_char.has_method("add_buff"):
				var terror: Terror = Terror.new()
				terror.set_duration(5.0 + float(level) * 2.0)
				target_char.add_buff(terror)
				var weak: Weakness = Weakness.new()
				weak.set_duration(5.0 + float(level) * 2.0)
				target_char.add_buff(weak)
			if MessageLog:
				MessageLog.add("The corruption weakens the enemy's resolve.")

# ---------------------------------------------------------------------------
# Wand of Regrowth — grow grass and plants
# ---------------------------------------------------------------------------

class WandOfRegrowth extends Wand:
	func _init() -> void:
		super._init()
		item_id = "wand_of_regrowth"
		item_name = "Wand of Regrowth"
		description = "This wand channels the primal force of nature, " \
			+ "causing lush vegetation to spring up wherever it strikes. " \
			+ "Higher-level blasts can create dense foliage across a " \
			+ "wide area, blocking sight and slowing movement."
		icon_color = Color(0.2, 0.8, 0.2)

	func get_damage(_lvl: int) -> Array[int]:
		# Regrowth doesn't deal damage
		return [0, 0] as Array[int]

	func on_zap(hero: Char, path: Array[int]) -> void:
		if path.is_empty():
			return
		var target_pos: int = path[path.size() - 1]
		var lvl: Variant = hero.get("level") if hero != null else null
		if lvl == null:
			return
		# Grow grass at target and surrounding cells
		@warning_ignore("integer_division")
		var radius: int = 1 + level / 3
		var cells_grown: int = 0
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var x: int = ConstantsData.pos_to_x(target_pos) + dx
				var y: int = ConstantsData.pos_to_y(target_pos) + dy
				if x < 0 or x >= ConstantsData.WIDTH or y < 0 or y >= ConstantsData.HEIGHT:
					continue
				var cell_pos: int = ConstantsData.xy_to_pos(x, y)
				# Only grow on empty/grass/embers/furrowed tiles
				if not lvl.has_method("get_terrain") or not lvl.has_method("set_terrain"):
					continue
				var terrain: int = lvl.get_terrain(cell_pos)
				var can_grow: bool = false
				match terrain:
					ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.EMBERS, \
					ConstantsData.Terrain.FURROWED_GRASS:
						can_grow = true
					ConstantsData.Terrain.GRASS:
						can_grow = true
				if can_grow:
					# Higher-level zaps produce high grass
					if level >= 3 or (dx == 0 and dy == 0):
						lvl.set_terrain(cell_pos, ConstantsData.Terrain.HIGH_GRASS)
					else:
						lvl.set_terrain(cell_pos, ConstantsData.Terrain.GRASS)
					cells_grown += 1
		if MessageLog:
			if cells_grown > 0:
				MessageLog.add_positive("Lush vegetation springs to life! (%d cells)" % cells_grown)
			else:
				MessageLog.add("The regrowth bolt fizzles on barren ground.")
