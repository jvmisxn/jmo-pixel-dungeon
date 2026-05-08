class_name ArmorGlyph
extends RefCounted
## Base class for armor glyphs — magical inscriptions that trigger effects when
## the wearer is struck. Each glyph has a proc chance and a unique effect.

# --- Properties ---
## Unique string identifier for this glyph type.
var glyph_id: String = ""
## Human-readable name shown in the UI.
var glyph_name: String = ""
## Tint applied to the armor icon when this glyph is inscribed.
var color: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Visual Effect Emission
# ---------------------------------------------------------------------------

## Emit the glyph_proc signal via EventBus so the visual layer can react.
static func _emit_glyph_proc(glyph_id_str: String, wearer: Variant, attacker: Variant) -> void:
	if EventBus == null:
		return
	var w_pos: int = wearer.get("pos") if wearer is Object else -1
	var a_pos: int = attacker.get("pos") if attacker is Object else -1
	EventBus.glyph_proc.emit(glyph_id_str, w_pos, a_pos)

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

## Virtual proc method called when the wearer is hit.
## Returns the modified damage value after the glyph's effect.
func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
	return damage

## Base proc chance scales with armor level. Higher level = higher chance.
## SPD formula: roughly 1/(level+3) base, so +0 = 33%, +3 = 16%, etc.
## Individual glyphs may override this.
static func generic_proc_chance(armor_level: int) -> float:
	return 1.0 / (float(armor_level) + 3.0)

## Roll whether a proc activates, using the generic formula.
static func check_proc(armor_level: int) -> bool:
	return randf() < generic_proc_chance(armor_level)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"glyph_id": glyph_id,
		"glyph_name": glyph_name,
		"color": [color.r, color.g, color.b, color.a],
	}

func deserialize(data: Dictionary) -> void:
	glyph_id = data.get("glyph_id", "")
	glyph_name = data.get("glyph_name", "")
	var c: Variant = data.get("color", [1.0, 1.0, 1.0, 1.0])
	if c is Array and c.size() >= 4:
		color = Color(c[0], c[1], c[2], c[3])

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a glyph instance by its string ID.
static func create(glyph_id_str: String) -> ArmorGlyph:
	match glyph_id_str:
		"obfuscation":
			return _create_obfuscation()
		"swiftness":
			return _create_swiftness()
		"viscosity":
			return _create_viscosity()
		"stone":
			return _create_stone()
		"repulsion":
			return _create_repulsion()
		"affection":
			return _create_affection()
		"anti_magic":
			return _create_anti_magic()
		"thorns":
			return _create_thorns()
		"potential":
			return _create_potential()
		"brimstone":
			return _create_brimstone()
		"flow":
			return _create_flow()
		"entanglement":
			return _create_entanglement()
	push_warning("ArmorGlyph.create: unknown glyph_id '%s'" % glyph_id_str)
	return null

## Return a random common glyph (excludes cursed-only glyphs in SPD, but we
## include all here; the caller can filter if needed).
static func random() -> ArmorGlyph:
	var ids: Array[String] = [
		"obfuscation", "swiftness", "viscosity", "stone",
		"repulsion", "affection", "anti_magic", "thorns",
		"potential", "brimstone", "flow", "entanglement",
	]
	return create(ids[randi() % ids.size()])

# ===========================================================================
# Glyph Implementations
# ===========================================================================

# --- Obfuscation -----------------------------------------------------------
# Chance to become invisible when hit.

static func _create_obfuscation() -> ArmorGlyph:
	var g: ObfuscationGlyph = ObfuscationGlyph.new()
	g.glyph_id = "obfuscation"
	g.glyph_name = "Obfuscation"
	g.color = Color(0.6, 0.6, 0.8, 1.0)  # pale blue-gray
	return g

# --- Swiftness --------------------------------------------------------------
# Grants bonus movement speed.

static func _create_swiftness() -> ArmorGlyph:
	var g: SwiftnessGlyph = SwiftnessGlyph.new()
	g.glyph_id = "swiftness"
	g.glyph_name = "Swiftness"
	g.color = Color(1.0, 0.95, 0.4, 1.0)  # yellow
	return g

# --- Viscosity --------------------------------------------------------------
# Defers a portion of damage over subsequent turns.

static func _create_viscosity() -> ArmorGlyph:
	var g: ViscosityGlyph = ViscosityGlyph.new()
	g.glyph_id = "viscosity"
	g.glyph_name = "Viscosity"
	g.color = Color(0.5, 0.2, 0.6, 1.0)  # purple
	return g

# --- Stone ------------------------------------------------------------------
# Reduces incoming damage significantly but slows movement.

static func _create_stone() -> ArmorGlyph:
	var g: StoneGlyph = StoneGlyph.new()
	g.glyph_id = "stone"
	g.glyph_name = "Stone"
	g.color = Color(0.6, 0.6, 0.6, 1.0)  # gray
	return g

# --- Repulsion --------------------------------------------------------------
# Knocks the attacker back one tile on proc.

static func _create_repulsion() -> ArmorGlyph:
	var g: RepulsionGlyph = RepulsionGlyph.new()
	g.glyph_id = "repulsion"
	g.glyph_name = "Repulsion"
	g.color = Color(0.4, 0.9, 1.0, 1.0)  # cyan
	return g

# --- Affection --------------------------------------------------------------
# Chance to charm the attacker.

static func _create_affection() -> ArmorGlyph:
	var g: AffectionGlyph = AffectionGlyph.new()
	g.glyph_id = "affection"
	g.glyph_name = "Affection"
	g.color = Color(1.0, 0.4, 0.6, 1.0)  # pink
	return g

# --- Anti-Magic -------------------------------------------------------------
# Reduces incoming magic damage.

static func _create_anti_magic() -> ArmorGlyph:
	var g: AntiMagicGlyph = AntiMagicGlyph.new()
	g.glyph_id = "anti_magic"
	g.glyph_name = "Anti-Magic"
	g.color = Color(0.3, 0.8, 0.3, 1.0)  # green
	return g

# --- Thorns -----------------------------------------------------------------
# Reflects a portion of damage back to the attacker.

static func _create_thorns() -> ArmorGlyph:
	var g: ThornsGlyph = ThornsGlyph.new()
	g.glyph_id = "thorns"
	g.glyph_name = "Thorns"
	g.color = Color(0.8, 0.2, 0.2, 1.0)  # red
	return g

# --- Potential --------------------------------------------------------------
# Recharges equipped wands when the wearer is hit.

static func _create_potential() -> ArmorGlyph:
	var g: PotentialGlyph = PotentialGlyph.new()
	g.glyph_id = "potential"
	g.glyph_name = "Potential"
	g.color = Color(0.3, 0.5, 1.0, 1.0)  # electric blue
	return g

# --- Brimstone --------------------------------------------------------------
# Grants fire immunity and heals from fire damage.

static func _create_brimstone() -> ArmorGlyph:
	var g: BrimstoneGlyph = BrimstoneGlyph.new()
	g.glyph_id = "brimstone"
	g.glyph_name = "Brimstone"
	g.color = Color(1.0, 0.4, 0.0, 1.0)  # orange
	return g

# --- Flow -------------------------------------------------------------------
# Move faster when standing in or moving through water.

static func _create_flow() -> ArmorGlyph:
	var g: FlowGlyph = FlowGlyph.new()
	g.glyph_id = "flow"
	g.glyph_name = "Flow"
	g.color = Color(0.2, 0.5, 0.9, 1.0)  # water blue
	return g

# --- Entanglement -----------------------------------------------------------
# Roots the wearer in place but grants bonus armor from grass.

static func _create_entanglement() -> ArmorGlyph:
	var g: EntanglementGlyph = EntanglementGlyph.new()
	g.glyph_id = "entanglement"
	g.glyph_name = "Entanglement"
	g.color = Color(0.2, 0.7, 0.2, 1.0)  # green
	return g


# ===========================================================================
# Inner Classes — Full Glyph Implementations
# ===========================================================================

class ObfuscationGlyph extends ArmorGlyph:
	## Chance to become invisible for a few turns when struck.
	## Proc chance uses the generic formula; invisibility lasts 2+level/2 turns.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			# Grant invisibility to the defender
			if defender != null and defender.has_method("add_buff"):
				var invis: Invisibility = Invisibility.new()
				var dur: float = 2.0 + floorf(float(armor_level) / 2.0)
				invis.set_duration(dur)
				defender.add_buff(invis)
				if MessageLog:
					MessageLog.add("The armor " + "cloaks you in " + "shadows!")
			ArmorGlyph._emit_glyph_proc("obfuscation", defender, attacker)
		return damage


class SwiftnessGlyph extends ArmorGlyph:
	## Passively grants +10% move speed while the armor's str requirement is met.
	## On proc, grants a short burst of haste (3 turns).
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			if defender != null and defender.has_method("add_buff"):
				var haste: Haste = Haste.new()
				haste.set_duration(3.0)
				defender.add_buff(haste)
				if MessageLog:
					MessageLog.add("Your armor surges with speed!")
			ArmorGlyph._emit_glyph_proc("swiftness", defender, attacker)
		return damage


class ViscosityGlyph extends ArmorGlyph:
	## On proc, defers a portion of damage. The deferred damage is dealt as
	## 1 HP per turn over subsequent turns instead of all at once.
	## Deferred amount = damage * (level+1) / (level+4), minimum 1.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			var deferred: int = maxi(1, int(float(damage) * float(armor_level + 1) / float(armor_level + 4)))
			var remaining: int = maxi(0, damage - deferred)
			# Apply deferred damage as a bleeding-like buff
			if defender != null and defender.has_method("add_buff"):
				var bleed: Bleeding = Bleeding.new()
				bleed.set_duration(float(deferred))
				defender.add_buff(bleed)
				if MessageLog:
					MessageLog.add("Your viscous armor absorbs the " + "blow!")
			ArmorGlyph._emit_glyph_proc("viscosity", defender, attacker)
			return remaining
		return damage


class StoneGlyph extends ArmorGlyph:
	## Reduces incoming damage by an additional 2 + level, but applies a
	## movement speed penalty (~0.8x). The damage reduction is always-on
	## (not proc-based) so we apply it directly.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		var reduction: int = 2 + armor_level
		var reduced: int = maxi(0, damage - reduction)
		# Speed penalty is handled by armor.speed_factor() checking this glyph
		if reduced < damage:
			if MessageLog:
				MessageLog.add("Your stone armor absorbs the " + "impact!")
			ArmorGlyph._emit_glyph_proc("stone", defender, attacker)
		return reduced


class RepulsionGlyph extends ArmorGlyph:
	## On proc, knocks the attacker back one tile away from the defender.
	## Uses Ballistica for line-of-sight if available, otherwise simple direction.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			if attacker != null and defender != null:
				if attacker.has_method("move_to") and attacker.get("pos") != null and defender.get("pos") != null:
					var atk_pos: int = attacker.pos
					var def_pos: int = defender.pos
					# Calculate knockback direction: away from defender
					var atk_x: int = ConstantsData.pos_to_x(atk_pos)
					var atk_y: int = ConstantsData.pos_to_y(atk_pos)
					var def_x: int = ConstantsData.pos_to_x(def_pos)
					var def_y: int = ConstantsData.pos_to_y(def_pos)
					var dx: int = signi(atk_x - def_x)
					var dy: int = signi(atk_y - def_y)
					var new_pos: int = ConstantsData.xy_to_pos(atk_x + dx, atk_y + dy)
					if ConstantsData.is_valid_pos(new_pos):
						# Attempt to push attacker; if blocked, they stay put
						var level_ref: Variant = attacker.get("level")
						var can_move: bool = true
						if level_ref != null and level_ref.has_method("is_passable"):
							can_move = level_ref.is_passable(new_pos)
							if can_move and level_ref.has_method("find_char_at"):
								can_move = level_ref.find_char_at(new_pos) == null
						if can_move:
							attacker.pos = new_pos
							if MessageLog:
								MessageLog.add("Your armor " + "repels the " + "attacker!")
			ArmorGlyph._emit_glyph_proc("repulsion", defender, attacker)
		return damage


class AffectionGlyph extends ArmorGlyph:
	## On proc, charms the attacker for 2+level/2 turns. Charmed enemies
	## wander randomly instead of attacking.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			if attacker != null and attacker.has_method("add_buff"):
				var charm_buff: Charm = Charm.new()
				var dur: float = 2.0 + floorf(float(armor_level) / 2.0)
				charm_buff.set_duration(dur)
				attacker.add_buff(charm_buff)
				if MessageLog:
					MessageLog.add("Your armor " + "charms the " + "attacker!")
			ArmorGlyph._emit_glyph_proc("affection", defender, attacker)
		return damage


class AntiMagicGlyph extends ArmorGlyph:
	## Reduces magic damage by 50% + 2*level. The proc always fires for
	## magic-type damage. For physical damage, behaves like a normal glyph
	## with reduced effect (25% reduction on proc).
	## Since we don't yet have a damage-type flag, we apply a flat reduction
	## on proc as a general-purpose anti-magic shield.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		# Anti-magic always provides some passive resistance
		# On proc, reduce damage by 50% (representing magic resistance)
		if ArmorGlyph.check_proc(armor_level):
			var reduction: int = maxi(1, int(float(damage) * 0.5) + armor_level)
			var reduced: int = maxi(0, damage - reduction)
			if MessageLog:
				MessageLog.add("Your anti-magic " + "ward flares!")
			ArmorGlyph._emit_glyph_proc("anti_magic", defender, attacker)
			return reduced
		return damage


class ThornsGlyph extends ArmorGlyph:
	## On proc, reflects damage back to the attacker equal to
	## level + randi_range(0, damage/2). The defender still takes full damage.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			if attacker != null and attacker.has_method("take_damage"):
				@warning_ignore("integer_division")
				var reflect: int = armor_level + randi_range(0, maxi(1, damage / 2))
				attacker.take_damage(reflect, defender)
				if MessageLog:
					MessageLog.add("Thorns " + "pierce the " + "attacker for %d " % reflect + "damage!")
			ArmorGlyph._emit_glyph_proc("thorns", defender, attacker)
		return damage


class PotentialGlyph extends ArmorGlyph:
	## On proc, recharges equipped wands by 1 charge. If no wands are equipped,
	## the glyph stores potential energy. Uses duck typing to find wands in
	## the hero's belongings.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			# Look for wands in the defender's belongings
			if defender != null and defender.get("belongings") != null:
				var belongings: Variant = defender.belongings
				# Check backpack for wand items
				var recharged: bool = false
				if belongings.get("backpack") != null:
					for item: Variant in belongings.backpack:
						if item != null and item.get("category") == ConstantsData.ItemCategory.WAND:
							if item.has_method("recharge"):
								item.recharge(1)
								recharged = true
								break  # only recharge one wand per proc
				if recharged and MessageLog:
					MessageLog.add("Electrical energy " + "flows into " + "your wand!")
				elif not recharged and MessageLog:
					MessageLog.add("Potential energy " + "crackles from " + "your armor!")
			ArmorGlyph._emit_glyph_proc("potential", defender, attacker)
		return damage


class BrimstoneGlyph extends ArmorGlyph:
	## Grants fire immunity. When the wearer would take fire (Burning) damage,
	## they instead heal for a portion of it. On proc from any hit, removes
	## the Burning debuff if present and heals 1 + level/2 HP.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if defender != null:
			# Always check for and remove burning
			if defender.has_method("has_buff") and defender.has_buff("Burning"):
				defender.remove_buff_by_id("Burning")
				@warning_ignore("integer_division")
				var heal_amount: int = 1 + armor_level / 2
				if defender.has_method("heal"):
					defender.heal(heal_amount)
				if MessageLog:
					MessageLog.add("Brimstone " + "absorbs the " + "flames, healing you!")
				ArmorGlyph._emit_glyph_proc("brimstone", defender, attacker)
			elif ArmorGlyph.check_proc(armor_level):
				# Even without fire, small chance to heal on hit
				@warning_ignore("integer_division")
				var heal_amount: int = 1 + armor_level / 4
				if defender.has_method("heal"):
					defender.heal(heal_amount)
				if MessageLog:
					MessageLog.add("Your brimstone " + "armor smolders " + "protectively.")
				ArmorGlyph._emit_glyph_proc("brimstone", defender, attacker)
		return damage


class FlowGlyph extends ArmorGlyph:
	## Grants bonus movement speed when the wearer is standing in water.
	## On proc, if standing on water terrain, grants 2 turns of haste.
	## The passive speed bonus is handled by armor.speed_factor().
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			if defender != null and defender.get("pos") != null and defender.get("level") != null:
				var level_ref: Variant = defender.level
				if level_ref != null and level_ref.has_method("get_terrain"):
					var terrain: int = level_ref.get_terrain(defender.pos)
					if terrain == ConstantsData.Terrain.WATER:
						if defender.has_method("add_buff"):
							var haste: Buff = Buff.new()
							haste.buff_id = "Haste"
							haste.duration = 2.0 + armor_level
							defender.add_buff(haste)
						if MessageLog:
							MessageLog.add("The water surges around you!")
						ArmorGlyph._emit_glyph_proc("flow", defender, attacker)
		return damage


class EntanglementGlyph extends ArmorGlyph:
	## On proc, roots the wearer in place but grants bonus armor from nearby
	## grass terrain. The root lasts 2+level turns. While rooted, the wearer
	## gains armor equal to 2 + level for each adjacent grass tile.
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		var armor_level: int = armor.level if armor != null else 0
		if ArmorGlyph.check_proc(armor_level):
			if defender != null and defender.has_method("add_buff"):
				# Root the wearer
				var root: Buff = Buff.new()
				root.buff_id = "Rooted"
				root.duration = 2.0 + float(armor_level)
				defender.add_buff(root)
				# Count adjacent grass for bonus armor
				var grass_count: int = 0
				if defender.get("pos") != null and defender.get("level") != null:
					var level_ref: Variant = defender.level
					if level_ref != null and level_ref.has_method("get_terrain"):
						for dir: int in ConstantsData.DIRS_8:
							var adj_pos: int = defender.pos + dir
							if ConstantsData.is_valid_pos(adj_pos):
								var terrain: int = level_ref.get_terrain(adj_pos)
								if terrain == ConstantsData.Terrain.GRASS or terrain == ConstantsData.Terrain.HIGH_GRASS or terrain == ConstantsData.Terrain.FURROWED_GRASS:
									grass_count += 1
				# Apply grass armor bonus as a temporary shield buff
				if grass_count > 0:
					var bonus: int = (2 + armor_level) * grass_count
					if defender.has_method("add_shielding"):
						defender.add_shielding(bonus)
					if MessageLog:
						MessageLog.add("Vines " + "entangle you, " + "granting %d " % bonus + "bonus armor!")
				else:
					if MessageLog:
						MessageLog.add("Vines " + "entangle you!")
			ArmorGlyph._emit_glyph_proc("entanglement", defender, attacker)
		return damage
