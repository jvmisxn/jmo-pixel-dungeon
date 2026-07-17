class_name Potion
extends Item
## Base class for all potions. Potions are stackable consumables that can be
## drunk for a direct effect or thrown/shattered at a position for an area effect.

# --- Potion-Specific Properties ---
## Whether the player has identified this potion color as this potion type.
var known: bool = false
## Display label for unidentified appearance in this run.
var appearance_name: String = ""
## Visual color for unidentified display (randomized per run via generator).
var potion_color: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	category = ConstantsData.ItemCategory.POTION
	stackable = true
	default_action = "DRINK"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Time cost for drinking a potion (matches original TIME_TO_DRINK = 1f).
const TIME_TO_DRINK: float = 1.0

## Primary action: drink the potion and consume one from the stack.
func execute(hero: Char) -> void:
	if hero == null:
		return
	# Spend a turn to drink (original: hero.spend(TIME_TO_DRINK))
	if hero.has_method("spend"):
		hero.spend(TIME_TO_DRINK)
	drink(hero)
	identify()
	_consume(hero)

## Virtual — override in each potion type for the drinking effect.
func drink(_hero: Char) -> void:
	pass

## Thrown potion shatters at a position, causing an area effect.
## Virtual — override for potions with shatter effects.
func shatter(_pos: int, _lvl: Variant) -> void:
	if MessageLog:
		MessageLog.add("The potion shatters!")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Consume one potion from the stack. Removes from inventory if exhausted.
func _consume(hero: Char) -> void:
	quantity -= 1
	if MessageLog:
		MessageLog.add_info("You drink the %s." % item_name)
	if EventBus:
		EventBus.item_used.emit(item_name)
	if GameManager:
		GameManager.record_stat("potions_used")
	if quantity <= 0 and hero != null:
		if hero.belongings and hero.belongings.has_method("remove_item"):
			hero.belongings.remove_item(self)

## Override duplicate_item to preserve potion-specific properties.
func duplicate_item() -> Item:
	var copy: Potion = Potion.create(item_id)
	if copy == null:
		copy = Potion.new()
	_copy_base_properties(copy)
	copy.known = known
	copy.appearance_name = appearance_name
	copy.potion_color = potion_color
	return copy

## Potions are not upgradeable.
func is_upgradeable() -> bool:
	return false

## SPD Potion.value() = 30 * quantity.
func value() -> int:
	return 30 * quantity

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

## If not identified and not known, show the color name instead.
func get_display_name() -> String:
	if identified or known:
		return super.get_display_name()
	var color_label: String = appearance_name if not appearance_name.is_empty() else _color_label(potion_color)
	var display: String = "%s Potion" % color_label
	if stackable and quantity > 1:
		display = "%s (%d)" % [display, quantity]
	return display

## Human-readable color label for unidentified potions.
static func _color_label(c: Color) -> String:
	# Approximate named colors for display
	if c.r > 0.8 and c.g < 0.3 and c.b < 0.3:
		return "Crimson"
	if c.r < 0.3 and c.g > 0.7 and c.b < 0.3:
		return "Emerald"
	if c.r < 0.3 and c.g < 0.3 and c.b > 0.7:
		return "Sapphire"
	if c.r > 0.8 and c.g > 0.8 and c.b < 0.3:
		return "Golden"
	if c.r > 0.5 and c.g < 0.3 and c.b > 0.5:
		return "Violet"
	if c.r > 0.8 and c.g > 0.4 and c.b < 0.2:
		return "Amber"
	if c.r < 0.3 and c.g > 0.7 and c.b > 0.7:
		return "Turquoise"
	if c.r > 0.7 and c.g > 0.7 and c.b > 0.7:
		return "Silver"
	if c.r < 0.2 and c.g < 0.2 and c.b < 0.2:
		return "Onyx"
	if c.r > 0.6 and c.g > 0.3 and c.b > 0.3:
		return "Rose"
	if c.r > 0.3 and c.g > 0.6 and c.b > 0.3:
		return "Jade"
	if c.r > 0.5 and c.g > 0.5 and c.b > 0.0:
		return "Bistre"
	if c.r > 0.3 and c.g > 0.3 and c.b > 0.6:
		return "Indigo"
	return "Murky"

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["known"] = known
	data["appearance_name"] = appearance_name
	data["potion_color"] = [potion_color.r, potion_color.g, potion_color.b, potion_color.a]
	data["potion_type"] = item_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	known = data.get("known", false)
	appearance_name = data.get("appearance_name", "")
	var pc: Variant = data.get("potion_color", [1.0, 1.0, 1.0, 1.0])
	if pc is Array and pc.size() >= 4:
		potion_color = Color(pc[0], pc[1], pc[2], pc[3])

# ===========================================================================
# Factory
# ===========================================================================

## Create a configured Potion instance by type ID.
static func create(potion_id: String) -> Potion:
	match potion_id:
		"healing":
			return _create_healing()
		"strength":
			return _create_strength()
		"mind_vision":
			return _create_mind_vision()
		"invisibility":
			return _create_invisibility()
		"toxic_gas":
			return _create_toxic_gas()
		"liquid_flame":
			return _create_liquid_flame()
		"frost":
			return _create_frost()
		"levitation":
			return _create_levitation()
		"paralytic_gas":
			return _create_paralytic_gas()
		"purity":
			return _create_purity()
		"experience":
			return _create_experience()
		"haste":
			return _create_haste()
		"divine_inspiration":
			return _create_divine_inspiration()
		"mastery":
			return _create_mastery()
	push_warning("Potion.create(): unknown potion_id '%s'" % potion_id)
	return null

## Return all valid potion IDs.
static func all_ids() -> Array[String]:
	return [
		"healing", "strength", "mind_vision", "invisibility",
		"toxic_gas", "liquid_flame", "frost", "levitation",
		"paralytic_gas", "purity", "experience", "haste",
		"divine_inspiration", "mastery",
	]

# ===========================================================================
# Potion Definitions
# ===========================================================================

# --- Healing ---

static func _create_healing() -> Potion:
	var p: PotionHealing = PotionHealing.new()
	return p

# --- Strength ---

static func _create_strength() -> Potion:
	var p: PotionStrength = PotionStrength.new()
	return p

# --- Mind Vision ---

static func _create_mind_vision() -> Potion:
	var p: PotionMindVision = PotionMindVision.new()
	return p

# --- Invisibility ---

static func _create_invisibility() -> Potion:
	var p: PotionInvisibility = PotionInvisibility.new()
	return p

# --- Toxic Gas ---

static func _create_toxic_gas() -> Potion:
	var p: PotionToxicGas = PotionToxicGas.new()
	return p

# --- Liquid Flame ---

static func _create_liquid_flame() -> Potion:
	var p: PotionLiquidFlame = PotionLiquidFlame.new()
	return p

# --- Frost ---

static func _create_frost() -> Potion:
	var p: PotionFrost = PotionFrost.new()
	return p

# --- Levitation ---

static func _create_levitation() -> Potion:
	var p: PotionLevitation = PotionLevitation.new()
	return p

# --- Paralytic Gas ---

static func _create_paralytic_gas() -> Potion:
	var p: PotionParalyticGas = PotionParalyticGas.new()
	return p

# --- Purity ---

static func _create_purity() -> Potion:
	var p: PotionPurity = PotionPurity.new()
	return p

# --- Experience ---

static func _create_experience() -> Potion:
	var p: PotionExperience = PotionExperience.new()
	return p

# --- Haste ---

static func _create_haste() -> Potion:
	var p: PotionHaste = PotionHaste.new()
	return p

# --- Divine Inspiration ---

static func _create_divine_inspiration() -> Potion:
	var p: PotionDivineInspiration = PotionDivineInspiration.new()
	return p

# --- Mastery ---

static func _create_mastery() -> Potion:
	var p: PotionMastery = PotionMastery.new()
	return p


# ############################################################################
# POTION SUBCLASSES — each inner class provides drink() and shatter() overrides
# ############################################################################

# ---------------------------------------------------------------------------
# Potion of Healing
# ---------------------------------------------------------------------------
class PotionHealing extends Potion:
	func _init() -> void:
		super._init()
		item_id = "healing"
		item_name = "Potion of Healing"
		description = "A smooth, crimson liquid that restores the drinker to full health."
		icon_color = Color(0.9, 0.15, 0.15)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		var missing: int = hero.hp_max - hero.hp
		if missing > 0:
			hero.heal(missing)
		# Also remove bleeding and poison
		if hero.has_method("remove_buff_by_id"):
			hero.remove_buff_by_id("Bleeding")
			hero.remove_buff_by_id("Poison")
		if MessageLog:
			MessageLog.add_positive("Your wounds heal completely!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# Heal all characters adjacent to shatter position
		if lvl == null:
			return
		if lvl.has_method("find_char_at"):
			var target: Variant = lvl.find_char_at(spos)
			if target and target.has_method("heal"):
				var missing: int = target.hp_max - target.hp
				if missing > 0:
					target.heal(missing)
		if MessageLog:
			MessageLog.add_positive("A healing mist fills the area.")


# ---------------------------------------------------------------------------
# Potion of Strength
# ---------------------------------------------------------------------------
class PotionStrength extends Potion:
	func _init() -> void:
		super._init()
		item_id = "strength"
		item_name = "Potion of Strength"
		description = "A thick, golden liquid that permanently increases strength by 1."
		icon_color = Color(0.9, 0.7, 0.1)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		hero.str_val += 1
		if MessageLog:
			MessageLog.add_positive("Newfound strength surges through your body!")
		if EventBus:
			EventBus.hero_stats_changed.emit()
		if GameManager:
			GameManager.record_stat("potions_of_strength")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# No area effect — strength potion is wasted when shattered
		if MessageLog:
			MessageLog.add_warning("The potion of strength shatters uselessly.")


# ---------------------------------------------------------------------------
# Potion of Mind Vision
# ---------------------------------------------------------------------------
class PotionMindVision extends Potion:
	func _init() -> void:
		super._init()
		item_id = "mind_vision"
		item_name = "Potion of Mind Vision"
		description = "A shimmering, violet draught that reveals the minds of all creatures nearby."
		icon_color = Color(0.7, 0.3, 0.9)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		var buff: MindVision = MindVision.new()
		buff.set_duration(20.0)
		hero.add_buff(buff)
		if MessageLog:
			MessageLog.add_positive("You can sense the minds of all creatures on this floor!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# Shattered mind vision has no meaningful area effect
		if MessageLog:
			MessageLog.add("The potion's contents dissipate harmlessly.")


# ---------------------------------------------------------------------------
# Potion of Invisibility
# ---------------------------------------------------------------------------
class PotionInvisibility extends Potion:
	func _init() -> void:
		super._init()
		item_id = "invisibility"
		item_name = "Potion of Invisibility"
		description = "A clear, faintly luminescent liquid that renders the drinker invisible."
		icon_color = Color(0.6, 0.6, 1.0, 0.6)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		var buff: Invisibility = Invisibility.new()
		buff.set_duration(20.0)
		hero.add_buff(buff)
		if MessageLog:
			MessageLog.add_positive("You fade from view!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# Smoke effect — grants brief invisibility to char at position
		if lvl == null:
			return
		if lvl.has_method("find_char_at"):
			var target: Variant = lvl.find_char_at(spos)
			if target and target.has_method("add_buff"):
				var buff: Invisibility = Invisibility.new()
				buff.set_duration(5.0)
				target.add_buff(buff)
		if MessageLog:
			MessageLog.add("A cloud of smoke erupts!")


# ---------------------------------------------------------------------------
# Potion of Toxic Gas
# ---------------------------------------------------------------------------
class PotionToxicGas extends Potion:
	func _init() -> void:
		super._init()
		item_id = "toxic_gas"
		item_name = "Potion of Toxic Gas"
		description = "A sickly green liquid that releases a cloud of poisonous gas."
		icon_color = Color(0.3, 0.7, 0.1)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Drinking toxic gas poisons the hero
		var poison_buff: Poison = Poison.create(5.0)
		hero.add_buff(poison_buff)
		if MessageLog:
			MessageLog.add_negative("That tasted terrible! You feel sick...")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		_apply_gas_to_area(spos, lvl)

	func _apply_gas_to_area(spos: int, lvl: Variant) -> void:
		if lvl == null:
			return
		# Poison all characters in a 3x3 area around shatter position
		var positions: Array[int] = [spos]
		for offset: int in ConstantsData.DIRS_8:
			var adj: int = spos + offset
			if ConstantsData.is_valid_pos(adj):
				positions.append(adj)
		if lvl.has_method("find_char_at"):
			for p: int in positions:
				var target: Variant = lvl.find_char_at(p)
				if target and target.has_method("add_buff"):
					var poison_buff: Poison = Poison.create(5.0)
					target.add_buff(poison_buff)
		if MessageLog:
			MessageLog.add_warning("A cloud of toxic gas fills the area!")


# ---------------------------------------------------------------------------
# Potion of Liquid Flame
# ---------------------------------------------------------------------------
class PotionLiquidFlame extends Potion:
	func _init() -> void:
		super._init()
		item_id = "liquid_flame"
		item_name = "Potion of Liquid Flame"
		description = "An unstable, orange liquid that bursts into flames on contact with air."
		icon_color = Color(1.0, 0.5, 0.0)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Drinking liquid flame sets the hero on fire
		var burn: Burning = Burning.new()
		hero.add_buff(burn)
		if MessageLog:
			MessageLog.add_negative("The liquid fire burns your insides!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		_apply_fire_to_area(spos, lvl)

	func _apply_fire_to_area(spos: int, lvl: Variant) -> void:
		if lvl == null:
			return
		# Set fire to all characters in a 3x3 area
		var positions: Array[int] = [spos]
		for offset: int in ConstantsData.DIRS_8:
			var adj: int = spos + offset
			if ConstantsData.is_valid_pos(adj):
				positions.append(adj)
		if lvl.has_method("find_char_at"):
			for p: int in positions:
				var target: Variant = lvl.find_char_at(p)
				if target and target.has_method("add_buff"):
					var burn: Burning = Burning.new()
					target.add_buff(burn)
		# Set terrain on fire (high grass -> embers)
		if lvl.has_method("get_terrain") and lvl.has_method("set_terrain"):
			for p: int in positions:
				if ConstantsData.is_valid_pos(p):
					var terrain: int = lvl.get_terrain(p)
					if terrain == ConstantsData.Terrain.HIGH_GRASS or terrain == ConstantsData.Terrain.GRASS:
						lvl.set_terrain(p, ConstantsData.Terrain.EMBERS)
					elif terrain == ConstantsData.Terrain.BARRICADE:
						lvl.set_terrain(p, ConstantsData.Terrain.EMBERS)
		if MessageLog:
			MessageLog.add_warning("Flames erupt across the area!")


# ---------------------------------------------------------------------------
# Potion of Frost
# ---------------------------------------------------------------------------
class PotionFrost extends Potion:
	const FROST_DAMAGE: int = 2

	func _init() -> void:
		super._init()
		item_id = "frost"
		item_name = "Potion of Frost"
		description = "A frigid, pale blue liquid that freezes everything around it."
		icon_color = Color(0.5, 0.8, 1.0)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Drinking frost potion extinguishes fire and chills
		if hero.has_method("remove_buff_by_id"):
			hero.remove_buff_by_id("Burning")
		if MessageLog:
			MessageLog.add_positive("A wave of cold extinguishes the flames!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		_apply_frost_to_area(spos, lvl)

	func _apply_frost_to_area(spos: int, lvl: Variant) -> void:
		if lvl == null:
			return
		var positions: Array[int] = [spos]
		for offset: int in ConstantsData.DIRS_8:
			var adj: int = spos + offset
			if ConstantsData.is_valid_pos(adj):
				positions.append(adj)
		if lvl.has_method("find_char_at"):
			for p: int in positions:
				var target: Variant = lvl.find_char_at(p)
				if target == null:
					continue
				# Extinguish burning
				if target.has_method("remove_buff_by_id"):
					target.remove_buff_by_id("Burning")
				# Deal frost damage
				if target.has_method("take_damage"):
					target.take_damage(FROST_DAMAGE, null)
		# Freeze water tiles
		if lvl.has_method("get_terrain") and lvl.has_method("set_terrain"):
			for p: int in positions:
				if ConstantsData.is_valid_pos(p):
					var terrain: int = lvl.get_terrain(p)
					if terrain == ConstantsData.Terrain.WATER:
						lvl.set_terrain(p, ConstantsData.Terrain.EMPTY)
		if MessageLog:
			MessageLog.add_info("Everything in the area freezes!")


# ---------------------------------------------------------------------------
# Potion of Levitation
# ---------------------------------------------------------------------------
class PotionLevitation extends Potion:
	func _init() -> void:
		super._init()
		item_id = "levitation"
		item_name = "Potion of Levitation"
		description = "A fizzy, pale liquid that lets the drinker float above the ground."
		icon_color = Color(0.8, 0.8, 1.0)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		var buff: Levitation = Levitation.new()
		buff.set_duration(20.0)
		hero.add_buff(buff)
		if MessageLog:
			MessageLog.add_positive("You float into the air!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# Shattered levitation grants brief float to char at position
		if lvl == null:
			return
		if lvl.has_method("find_char_at"):
			var target: Variant = lvl.find_char_at(spos)
			if target and target.has_method("add_buff"):
				var buff: Levitation = Levitation.new()
				buff.set_duration(5.0)
				target.add_buff(buff)


# ---------------------------------------------------------------------------
# Potion of Paralytic Gas
# ---------------------------------------------------------------------------
class PotionParalyticGas extends Potion:
	func _init() -> void:
		super._init()
		item_id = "paralytic_gas"
		item_name = "Potion of Paralytic Gas"
		description = "A thick, yellow liquid that releases a cloud of paralyzing gas."
		icon_color = Color(1.0, 1.0, 0.3)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Drinking paralyzes the hero
		var buff: Paralysis = Paralysis.new()
		buff.set_duration(5.0)
		hero.add_buff(buff)
		if MessageLog:
			MessageLog.add_negative("You can't move!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		_apply_paralysis_to_area(spos, lvl)

	func _apply_paralysis_to_area(spos: int, lvl: Variant) -> void:
		if lvl == null:
			return
		var positions: Array[int] = [spos]
		for offset: int in ConstantsData.DIRS_8:
			var adj: int = spos + offset
			if ConstantsData.is_valid_pos(adj):
				positions.append(adj)
		if lvl.has_method("find_char_at"):
			for p: int in positions:
				var target: Variant = lvl.find_char_at(p)
				if target and target.has_method("add_buff"):
					var buff: Paralysis = Paralysis.new()
					buff.set_duration(5.0)
					target.add_buff(buff)
		if MessageLog:
			MessageLog.add_warning("A cloud of paralytic gas fills the area!")


# ---------------------------------------------------------------------------
# Potion of Purity
# ---------------------------------------------------------------------------
class PotionPurity extends Potion:
	func _init() -> void:
		super._init()
		item_id = "purity"
		item_name = "Potion of Purity"
		description = "A crystal-clear liquid that cleanses the body of all impurities."
		icon_color = Color(0.9, 0.95, 1.0)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Remove all debuffs
		if hero.has_method("get_buffs"):
			var buffs_list: Array = hero.get_buffs()
			for b: Variant in buffs_list:
				if b.get("is_debuff") == true:
					if hero.has_method("remove_buff"):
						hero.remove_buff(b)
		if MessageLog:
			MessageLog.add_positive("You feel purified! All ailments are cleansed.")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# Area cleanse — remove debuffs from chars in a 3x3 area
		if lvl == null:
			return
		var positions: Array[int] = [spos]
		for offset: int in ConstantsData.DIRS_8:
			var adj: int = spos + offset
			if ConstantsData.is_valid_pos(adj):
				positions.append(adj)
		if lvl.has_method("find_char_at"):
			for p: int in positions:
				var target: Variant = lvl.find_char_at(p)
				if target == null:
					continue
				if target.has_method("get_buffs"):
					var buffs_list: Array = target.get_buffs()
					for b: Variant in buffs_list:
						if b.get("is_debuff") == true:
							if target.has_method("remove_buff"):
								target.remove_buff(b)
		if MessageLog:
			MessageLog.add_positive("A purifying mist cleanses the area!")


# ---------------------------------------------------------------------------
# Potion of Experience
# ---------------------------------------------------------------------------
class PotionExperience extends Potion:
	func _init() -> void:
		super._init()
		item_id = "experience"
		item_name = "Potion of Experience"
		description = "A sparkling, gold liquid that grants the drinker a surge of experience."
		icon_color = Color(1.0, 0.85, 0.0)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Grant XP equal to the amount needed for the next level
		var xp_needed: int = hero.xp_to_next - hero.xp
		if xp_needed <= 0:
			xp_needed = ConstantsData.xp_for_level(hero.hero_level)
		if hero.has_method("earn_xp"):
			hero.earn_xp(xp_needed)
		if MessageLog:
			MessageLog.add_positive("A rush of knowledge floods through you!")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		if MessageLog:
			MessageLog.add("The potion of experience shatters uselessly.")


# ---------------------------------------------------------------------------
# Potion of Haste
# ---------------------------------------------------------------------------
class PotionHaste extends Potion:
	func _init() -> void:
		super._init()
		item_id = "haste"
		item_name = "Potion of Haste"
		description = "A fizzy, cyan liquid that doubles the drinker's speed."
		icon_color = Color(0.3, 1.0, 1.0)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		var buff: Haste = Haste.new()
		buff.set_duration(20.0)
		hero.add_buff(buff)
		if MessageLog:
			MessageLog.add_positive("You feel a surge of energy! Everything seems to slow down.")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		# Grant brief haste to char at shatter position
		if lvl == null:
			return
		if lvl.has_method("find_char_at"):
			var target: Variant = lvl.find_char_at(spos)
			if target and target.has_method("add_buff"):
				var buff: Haste = Haste.new()
				buff.set_duration(5.0)
				target.add_buff(buff)


# ---------------------------------------------------------------------------
# Potion of Divine Inspiration
# ---------------------------------------------------------------------------
class PotionDivineInspiration extends Potion:
	func _init() -> void:
		super._init()
		item_id = "divine_inspiration"
		item_name = "Potion of Divine Inspiration"
		description = "A radiant, white liquid that grants insight into an item's upgrade potential."
		icon_color = Color(1.0, 1.0, 0.8)

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Pick a random unidentified item from backpack and identify it,
		# or if all identified, upgrade a random item's knowledge.
		if hero.belongings == null:
			return
		var unidentified: Array[Item] = []
		for item: Item in hero.belongings.backpack:
			if item != null and item.has_method("is_identified"):
				if not item.is_identified():
					unidentified.append(item)
		if unidentified.size() > 0:
			var chosen: Item = unidentified[randi() % unidentified.size()]
			if chosen.has_method("identify"):
				chosen.identify()
			if MessageLog:
				MessageLog.add_positive("Divine insight reveals the nature of %s!" % chosen.get_display_name())
		else:
			# Grant a random upgrade to a random upgradeable item
			var upgradeable: Array[Item] = []
			for item: Item in hero.belongings.backpack:
				if item != null and item.has_method("is_upgradeable") and item.is_upgradeable():
					upgradeable.append(item)
			if upgradeable.size() > 0:
				var chosen: Item = upgradeable[randi() % upgradeable.size()]
				if chosen.has_method("upgrade"):
					chosen.upgrade()
				if MessageLog:
					MessageLog.add_positive("Divine power enhances your %s!" % chosen.get_display_name())
			else:
				if MessageLog:
					MessageLog.add("The divine light fades without effect.")

	func shatter(spos: int, lvl: Variant) -> void:
		super.shatter(spos, lvl)
		if MessageLog:
			MessageLog.add("The potion of divine inspiration shatters uselessly.")


# ---------------------------------------------------------------------------
# Potion of Mastery
# ---------------------------------------------------------------------------
class PotionMastery extends Potion:
	func _init() -> void:
		super._init()
		item_id = "mastery"
		item_name = "Potion of Mastery"
		description = "An ancient, multi-hued elixir that unlocks hidden potential within the drinker."
		icon_color = Color(0.8, 0.4, 0.9)
		unique = true

	func drink(hero: Char) -> void:
		if hero == null:
			return
		# Allow the hero to choose a subclass (if none chosen yet)
		if hero.hero_subclass != ConstantsData.HeroSubclass.NONE:
			if MessageLog:
				MessageLog.add_warning("You have already chosen your specialization.")
			return
		# Get available subclasses for this hero class
		var subclasses: Array = ConstantsData.subclasses_for(hero.hero_class)
		if subclasses.size() == 0:
			if MessageLog:
				MessageLog.add_warning("No specializations available.")
			return
		# Auto-select the first subclass for now (UI will present choice later)
		var chosen_subclass: int = subclasses[0]
		hero.hero_subclass = chosen_subclass
		if MessageLog:
			MessageLog.add_positive("You have mastered a new skill!")
