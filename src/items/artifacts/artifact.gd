class_name Artifact
extends Item
## Base class for all artifacts. Artifacts are unique equippable items that level up
## through usage-based experience rather than upgrade scrolls. Each hero can only
## carry one of each artifact type per run.

# --- Artifact Properties ---
## Current charge amount, used for activated abilities.
var charge: int = 0
## Maximum charge capacity. Increases with artifact level.
var charge_max: int = 100
## How quickly charges regenerate per turn (fractional accumulation).
var charge_rate: float = 1.0
## Experience earned toward the next artifact level.
var exp_earned: int = 0
## Experience required to reach the next artifact level.
var exp_to_level: int = 10
## Whether this artifact's activated ability is currently active.
var activated: bool = false

## Internal fractional charge accumulator for sub-integer charge rates.
var _partial_charge: float = 0.0

func _init() -> void:
	category = ConstantsData.ItemCategory.ARTIFACT
	unique = true
	stackable = false
	default_action = "ACTIVATE"

func is_equippable() -> bool:
	return true

# ---------------------------------------------------------------------------
# Upgrade System Override
# ---------------------------------------------------------------------------

## Artifacts cannot be upgraded by scrolls; they level via experience.
func is_upgradeable() -> bool:
	return false

## Override base upgrade to prevent scroll-based upgrading.
func upgrade() -> Item:
	# Artifacts do not upgrade via scrolls — use gain_exp() instead.
	return self

# ---------------------------------------------------------------------------
# Experience & Leveling
# ---------------------------------------------------------------------------

## Add usage experience. Triggers level_up() when threshold is reached.
func gain_exp(amount: int) -> void:
	exp_earned += amount
	while exp_earned >= exp_to_level and level < 10:
		exp_earned -= exp_to_level
		level_up()
	# Cap exp at threshold if max level
	if level >= 10:
		exp_earned = mini(exp_earned, exp_to_level)

## Level up the artifact, increasing charge capacity and recalculating exp curve.
func level_up() -> void:
	level += 1
	charge_max += 5 + level * 2
	exp_to_level = 10 + level * 10
	if MessageLog:
		MessageLog.add(
			"%s grows stronger! (Level %d)" % [item_name, level],
			icon_color
		)
	if EventBus:
		EventBus.hero_stats_changed.emit()

# ---------------------------------------------------------------------------
# Turn & Passive Hooks (Virtual)
# ---------------------------------------------------------------------------

## Called each turn while equipped. Override for per-turn passive effects.
func on_turn(_hero: Char) -> void:
	pass

## Called to apply stat modifications while equipped. Override per artifact.
func passives(_hero: Char) -> void:
	pass

## Activated ability. Override per artifact. Returns true if activation succeeded.
func activate(_hero: Char) -> bool:
	return false

# ---------------------------------------------------------------------------
# Charge Helpers
# ---------------------------------------------------------------------------

## Recharge by the artifact's charge_rate. Call from on_turn().
func _recharge(rate_override: float = -1.0) -> void:
	var rate: float = rate_override if rate_override > 0.0 else charge_rate
	_partial_charge += rate
	var whole: int = int(_partial_charge)
	if whole > 0:
		charge = mini(charge + whole, charge_max)
		_partial_charge -= float(whole)

## Spend charges. Returns true if enough charges were available.
func _spend_charge(amount: int) -> bool:
	if charge < amount:
		return false
	charge -= amount
	return true

# ---------------------------------------------------------------------------
# Item Interface Overrides
# ---------------------------------------------------------------------------

func on_equip(hero: Char) -> void:
	passives(hero)
	if MessageLog:
		MessageLog.add("You equip the %s." % item_name, icon_color)
	if EventBus:
		EventBus.item_equipped.emit(item_name, "artifact")

func on_unequip(hero: Char) -> void:
	activated = false
	if MessageLog:
		MessageLog.add("You unequip the %s." % item_name, icon_color)
	if EventBus:
		EventBus.item_unequipped.emit(item_name, "artifact")
	# Subclasses can remove any lingering buffs in their override
	super.on_unequip(hero)

func execute(hero: Char) -> void:
	activate(hero)

func get_display_name() -> String:
	var display: String = item_name
	if level > 0:
		display += " +%d" % level
	if charge_max > 0:
		display += " (%d/%d)" % [charge, charge_max]
	if cursed and cursed_known:
		display = "cursed " + display
	return display

func value() -> int:
	return 100 + level * 50

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["charge"] = charge
	data["charge_max"] = charge_max
	data["charge_rate"] = charge_rate
	data["exp_earned"] = exp_earned
	data["exp_to_level"] = exp_to_level
	data["activated"] = activated
	data["_partial_charge"] = _partial_charge
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	charge = data.get("charge", 0)
	charge_max = data.get("charge_max", 100)
	charge_rate = data.get("charge_rate", 1.0)
	exp_earned = data.get("exp_earned", 0)
	exp_to_level = data.get("exp_to_level", 10)
	activated = data.get("activated", false)
	_partial_charge = data.get("_partial_charge", 0.0)

# ===========================================================================
# Factory
# ===========================================================================

## Create an artifact by its ID string. Returns null if ID is unknown.
static func create(artifact_id: String) -> Artifact:
	match artifact_id:
		"cape_of_thorns":
			return _create_cape_of_thorns()
		"chalice_of_blood":
			return _create_chalice_of_blood()
		"cloak_of_shadows":
			return _create_cloak_of_shadows()
		"dried_rose":
			return _create_dried_rose()
		"ethereal_chains":
			return _create_ethereal_chains()
		"horn_of_plenty":
			return _create_horn_of_plenty()
		"master_thieves_armband":
			return _create_master_thieves_armband()
		"sandals_of_nature":
			return _create_sandals_of_nature()
		"talisman_of_foresight":
			return _create_talisman_of_foresight()
		"timekeeper_hourglass":
			return _create_timekeeper_hourglass()
		"unstable_spellbook":
			return _create_unstable_spellbook()
		"alchemists_toolkit":
			return _create_alchemists_toolkit()
		_:
			push_warning("Artifact.create(): unknown artifact_id '%s'" % artifact_id)
			return null

## Return a list of all valid artifact IDs.
static func all_ids() -> Array[String]:
	return [
		"cape_of_thorns",
		"chalice_of_blood",
		"cloak_of_shadows",
		"dried_rose",
		"ethereal_chains",
		"horn_of_plenty",
		"master_thieves_armband",
		"sandals_of_nature",
		"talisman_of_foresight",
		"timekeeper_hourglass",
		"unstable_spellbook",
		"alchemists_toolkit",
	]

# ===========================================================================
# CAPE OF THORNS
# ===========================================================================

static func _create_cape_of_thorns() -> Artifact:
	var a: Artifact = CapeOfThorns.new()
	return a


# ===========================================================================
# CHALICE OF BLOOD
# ===========================================================================

static func _create_chalice_of_blood() -> Artifact:
	var a: Artifact = ChaliceOfBlood.new()
	return a


# ===========================================================================
# CLOAK OF SHADOWS
# ===========================================================================

static func _create_cloak_of_shadows() -> Artifact:
	var a: Artifact = CloakOfShadows.new()
	return a


# ===========================================================================
# DRIED ROSE
# ===========================================================================

static func _create_dried_rose() -> Artifact:
	var a: Artifact = DriedRose.new()
	return a


# ===========================================================================
# ETHEREAL CHAINS
# ===========================================================================

static func _create_ethereal_chains() -> Artifact:
	var a: Artifact = EtherealChains.new()
	return a


# ===========================================================================
# HORN OF PLENTY
# ===========================================================================

static func _create_horn_of_plenty() -> Artifact:
	var a: Artifact = HornOfPlenty.new()
	return a


# ===========================================================================
# MASTER THIEVES ARMBAND
# ===========================================================================

static func _create_master_thieves_armband() -> Artifact:
	var a: Artifact = MasterThievesArmband.new()
	return a


# ===========================================================================
# SANDALS OF NATURE
# ===========================================================================

static func _create_sandals_of_nature() -> Artifact:
	var a: Artifact = SandalsOfNature.new()
	return a


# ===========================================================================
# TALISMAN OF FORESIGHT
# ===========================================================================

static func _create_talisman_of_foresight() -> Artifact:
	var a: Artifact = TalismanOfForesight.new()
	return a


# ===========================================================================
# TIMEKEEPER HOURGLASS
# ===========================================================================

static func _create_timekeeper_hourglass() -> Artifact:
	var a: Artifact = TimekeeperHourglass.new()
	return a


# ===========================================================================
# UNSTABLE SPELLBOOK
# ===========================================================================

static func _create_unstable_spellbook() -> Artifact:
	var a: Artifact = UnstableSpellbook.new()
	return a


# ===========================================================================
# ALCHEMISTS TOOLKIT
# ===========================================================================

static func _create_alchemists_toolkit() -> Artifact:
	var a: Artifact = AlchemistsToolkit.new()
	return a


# ###########################################################################
# INNER CLASSES — Full implementations for each artifact
# ###########################################################################

# ===========================================================================
# CAPE OF THORNS
# ===========================================================================
class CapeOfThorns extends Artifact:
	## Absorbs damage when fully charged. Charges from taking hits.
	## Passive: when charged, next hit is reduced by 50%.

	## Tracks accumulated hits toward building a charge cycle.
	var hits_taken: int = 0
	## Turns remaining on the active damage-absorption shield.
	var shield_turns: int = 0

	func _init() -> void:
		super._init()
		item_id = "cape_of_thorns"
		item_name = "Cape of Thorns"
		description = "A ragged cape lined with razor-sharp thorns. When fully charged, " \
			+ "it absorbs a portion of incoming damage and retaliates against attackers."
		icon_color = Color(0.6, 0.2, 0.8)  # purple
		charge_max = 100
		charge_rate = 0.0  # charges from hits, not passively
		exp_to_level = 12

	func on_turn(_hero: Char) -> void:
		if shield_turns > 0:
			shield_turns -= 1
			if shield_turns <= 0:
				activated = false
				if MessageLog:
					MessageLog.add("The Cape of Thorns' protection fades.", icon_color)

	func passives(_hero: Char) -> void:
		# Passive detection is handled by the damage pipeline checking is_charged()
		pass

	## Called by the damage pipeline when the hero takes a hit.
	## Returns the modified (reduced) damage.
	func on_hero_damaged(damage: int, _source: Variant) -> int:
		# Gain charge from being hit
		@warning_ignore("integer_division")
		var charge_gain: int = maxi(1, damage / 4) + level
		charge = mini(charge + charge_gain, charge_max)
		gain_exp(1)

		# If shield is active, absorb 50% of damage
		if activated and shield_turns > 0:
			@warning_ignore("integer_division")
			var absorbed: int = damage / 2
			if MessageLog:
				MessageLog.add(
					"The Cape of Thorns absorbs %d damage!" % absorbed,
					icon_color
				)
			return damage - absorbed
		return damage

	func activate(_hero: Char) -> bool:
		if charge < charge_max:
			if MessageLog:
				MessageLog.add(
					"The cape is not fully charged yet. (%d/%d)" % [charge, charge_max],
					icon_color
				)
			return false
		charge = 0
		activated = true
		shield_turns = 4 + level
		if MessageLog:
			MessageLog.add(
				"The Cape of Thorns flares with protective energy! (%d turns)" % shield_turns,
				icon_color
			)
		return true

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["hits_taken"] = hits_taken
		data["shield_turns"] = shield_turns
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		hits_taken = data.get("hits_taken", 0)
		shield_turns = data.get("shield_turns", 0)


# ===========================================================================
# CHALICE OF BLOOD
# ===========================================================================
class ChaliceOfBlood extends Artifact:
	## Heals over time, powered by self-harm. Prick to level up (costs HP).
	## Higher level = faster regeneration.

	## Turns since last regen tick (accumulator).
	var regen_accumulator: float = 0.0

	func _init() -> void:
		super._init()
		item_id = "chalice_of_blood"
		item_name = "Chalice of Blood"
		description = "An ornate golden chalice stained with ancient blood. Pricking yourself " \
			+ "on its thorned rim will level it up at the cost of your own health. " \
			+ "Higher levels grant increasingly powerful passive regeneration."
		icon_color = Color(0.55, 0.05, 0.05)  # dark_red
		charge_max = 0  # Not charge-based — uses passive regen
		charge_rate = 0.0
		exp_to_level = 0  # Levels via prick, not exp
		default_action = "PRICK"

	func on_turn(hero: Char) -> void:
		if level <= 0:
			return
		# Regen rate scales with level: 1 HP every (40 - level*3) turns, min every 5 turns
		var regen_interval: float = maxf(5.0, 40.0 - float(level) * 3.0)
		regen_accumulator += 1.0
		if regen_accumulator >= regen_interval:
			regen_accumulator -= regen_interval
			var hero_hp: int = hero.get("hp") if hero.get("hp") != null else 0
			var hero_hp_max: int = hero.get("hp_max") if hero.get("hp_max") != null else 1
			if hero_hp < hero_hp_max:
				hero.hp = mini(hero_hp + 1, hero_hp_max)
				if EventBus:
					EventBus.hero_stats_changed.emit()

	func passives(_hero: Char) -> void:
		pass

	## Prick yourself to level the chalice. Costs increasing HP.
	func activate(hero: Char) -> bool:
		if level >= 10:
			if MessageLog:
				MessageLog.add("The Chalice of Blood is already at maximum power.", icon_color)
			return false

		var prick_cost: int = 5 + level * 3
		var hero_hp: int = hero.get("hp") if hero.get("hp") != null else 0

		if hero_hp <= prick_cost:
			if MessageLog:
				MessageLog.add(
					"You would not survive pricking yourself! (Need > %d HP)" % prick_cost,
					icon_color
				)
			return false

		hero.hp -= prick_cost
		level += 1
		charge_max = 0  # Still no charge system
		exp_to_level = 0

		if MessageLog:
			MessageLog.add(
				"You prick yourself on the chalice! (-%d HP, now level %d)" % [prick_cost, level],
				icon_color
			)
		if EventBus:
			EventBus.hero_damaged.emit(prick_cost, self)
			EventBus.hero_stats_changed.emit()
		return true

	func get_display_name() -> String:
		var display: String = item_name
		if level > 0:
			display += " +%d" % level
		if cursed and cursed_known:
			display = "cursed " + display
		return display

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["regen_accumulator"] = regen_accumulator
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		regen_accumulator = data.get("regen_accumulator", 0.0)


# ===========================================================================
# CLOAK OF SHADOWS
# ===========================================================================
class CloakOfShadows extends Artifact:
	## Rogue exclusive. Grants invisibility charges. Activate to go invisible.
	## Recharges over time.

	## Turns remaining on current invisibility.
	var invis_turns: int = 0

	func _init() -> void:
		super._init()
		item_id = "cloak_of_shadows"
		item_name = "Cloak of Shadows"
		description = "A cloak woven from pure shadow. Only a Rogue can harness its power. " \
			+ "Activate to become invisible for several turns. Charges replenish over time."
		icon_color = Color(0.25, 0.25, 0.25)  # dark_gray
		charge_max = 6 + level * 2
		charge_rate = 0.5
		exp_to_level = 15

	func on_equip(hero: Char) -> void:
		# Rogue-exclusive check
		var hero_class: int = hero.get("hero_class") if hero.get("hero_class") != null else -1
		if hero_class != ConstantsData.HeroClass.ROGUE:
			if MessageLog:
				MessageLog.add(
					"Only a Rogue can use the Cloak of Shadows.",
					Color.RED
				)
		super.on_equip(hero)

	func on_turn(hero: Char) -> void:
		# Recharge over time
		if not activated:
			_recharge()

		# Tick down invisibility
		if activated and invis_turns > 0:
			invis_turns -= 1
			if invis_turns <= 0:
				activated = false
				# Remove invisibility buff
				if hero and hero.has_method("remove_buff_by_id"):
					hero.remove_buff_by_id("Invisibility")
				if MessageLog:
					MessageLog.add("You emerge from the shadows.", icon_color)

	func activate(hero: Char) -> bool:
		var hero_class: int = hero.get("hero_class") if hero.get("hero_class") != null else -1
		if hero_class != ConstantsData.HeroClass.ROGUE:
			if MessageLog:
				MessageLog.add("Only a Rogue can use the Cloak of Shadows.", Color.RED)
			return false

		var cost: int = 1
		if not _spend_charge(cost):
			if MessageLog:
				MessageLog.add("The cloak has no charges.", icon_color)
			return false

		activated = true
		invis_turns = 5 + level
		gain_exp(1)

		# Apply invisibility buff
		if hero.has_method("add_buff"):
			var invis: Invisibility = Invisibility.new()
			invis.duration = float(invis_turns)
			invis.time_left = float(invis_turns)
			hero.add_buff(invis)

		if MessageLog:
			MessageLog.add(
				"You wrap yourself in shadows. (%d turns)" % invis_turns,
				icon_color
			)
		return true

	func level_up() -> void:
		super.level_up()
		charge_max = 6 + level * 2

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["invis_turns"] = invis_turns
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		invis_turns = data.get("invis_turns", 0)


# ===========================================================================
# DRIED ROSE
# ===========================================================================
class DriedRose extends Artifact:
	## Summons a ghost ally. Charges by collecting rose petals. Ghost fights
	## alongside the hero.

	## Number of rose petals collected (need 3 to summon ghost first time).
	var petals_collected: int = 0
	## Whether the ghost has been summoned on this floor.
	var ghost_summoned: bool = false
	## Ghost's current HP (persists between floors).
	var ghost_hp: int = 20
	## Ghost's max HP, scales with level.
	var ghost_hp_max: int = 20

	func _init() -> void:
		super._init()
		item_id = "dried_rose"
		item_name = "Dried Rose"
		description = "A withered rose that still holds a faint glow. Collect rose petals " \
			+ "scattered across the dungeon to awaken the spirit within. Once summoned, " \
			+ "a ghostly ally fights alongside you."
		icon_color = Color(1.0, 0.6, 0.7)  # pink
		charge_max = 3
		charge = 0
		charge_rate = 0.0  # charges from petals, not time
		exp_to_level = 20

	func on_turn(_hero: Char) -> void:
		# Ghost passive regen if summoned
		if ghost_summoned and ghost_hp < ghost_hp_max:
			ghost_hp = mini(ghost_hp + 1, ghost_hp_max)

	func passives(_hero: Char) -> void:
		pass

	## Feed a petal to the rose.
	func add_petal() -> void:
		petals_collected += 1
		charge = mini(charge + 1, charge_max)
		gain_exp(5)
		if MessageLog:
			MessageLog.add(
				"You add a petal to the Dried Rose. (%d/%d)" % [charge, charge_max],
				icon_color
			)

	func activate(hero: Char) -> bool:
		if ghost_summoned:
			if MessageLog:
				MessageLog.add("The ghost is already by your side.", icon_color)
			return false

		if charge < charge_max:
			if MessageLog:
				MessageLog.add(
					"The rose needs more petals to summon the ghost. (%d/%d)" % [charge, charge_max],
					icon_color
				)
			return false

		# Summon ghost
		charge = 0
		ghost_summoned = true
		ghost_hp = ghost_hp_max
		gain_exp(5)

		if MessageLog:
			MessageLog.add(
				"A ghostly figure emerges from the rose and takes form beside you!",
				icon_color
			)
		# The actual ghost mob spawning is handled by the level/mob system
		# via EventBus
		if EventBus:
			EventBus.item_used.emit(item_name)
		return true

	## Called when moving to a new floor — ghost must be re-summoned.
	func on_floor_change() -> void:
		ghost_summoned = false

	func level_up() -> void:
		super.level_up()
		ghost_hp_max = 20 + level * 5
		charge_max = 3  # Always 3 petals needed

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["petals_collected"] = petals_collected
		data["ghost_summoned"] = ghost_summoned
		data["ghost_hp"] = ghost_hp
		data["ghost_hp_max"] = ghost_hp_max
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		petals_collected = data.get("petals_collected", 0)
		ghost_summoned = data.get("ghost_summoned", false)
		ghost_hp = data.get("ghost_hp", 20)
		ghost_hp_max = data.get("ghost_hp_max", 20)


# ===========================================================================
# ETHEREAL CHAINS
# ===========================================================================
class EtherealChains extends Artifact:
	## Pull yourself to a location or pull an enemy to you. Charges over time.

	func _init() -> void:
		super._init()
		item_id = "ethereal_chains"
		item_name = "Ethereal Chains"
		description = "Spectral chains that can latch onto surfaces or creatures. Use to " \
			+ "pull yourself toward a distant point, or yank an enemy to your position."
		icon_color = Color(0.6, 0.8, 1.0)  # light_blue
		charge_max = 5
		charge = 5
		charge_rate = 0.2
		exp_to_level = 12

	func on_turn(_hero: Char) -> void:
		if not activated:
			_recharge()

	func passives(_hero: Char) -> void:
		pass

	## Pull hero toward target position. Returns true if successful.
	func activate(_hero: Char) -> bool:
		var cost: int = 1
		if not _spend_charge(cost):
			if MessageLog:
				MessageLog.add("The chains have no charges.", icon_color)
			return false

		gain_exp(2)
		activated = false  # Instant effect, not sustained

		if MessageLog:
			MessageLog.add(
				"The ethereal chains lash out!",
				icon_color
			)
		if EventBus:
			EventBus.item_used.emit(item_name)
		# Actual movement logic is handled by the targeting/movement system.
		# This method signals intent; the game controller resolves positioning.
		return true

	## Pull an enemy toward the hero's position.
	func pull_enemy(_hero: Char, _enemy: Variant) -> bool:
		var cost: int = 1
		if not _spend_charge(cost):
			if MessageLog:
				MessageLog.add("The chains have no charges.", icon_color)
			return false

		gain_exp(2)

		if MessageLog:
			MessageLog.add(
				"The ethereal chains yank the enemy toward you!",
				icon_color
			)
		if EventBus:
			EventBus.item_used.emit(item_name)
		return true

	func level_up() -> void:
		super.level_up()
		charge_max = 5 + level


# ===========================================================================
# HORN OF PLENTY
# ===========================================================================
class HornOfPlenty extends Artifact:
	## Stores food charges. Eat to satisfy hunger. Gains exp from feeding it food.

	## Amount of hunger satisfied per charge spent.
	var hunger_per_charge: float = 50.0

	func _init() -> void:
		super._init()
		item_id = "horn_of_plenty"
		item_name = "Horn of Plenty"
		description = "A magical cornucopia that can store food energy. Feed it food items " \
			+ "to charge it, then eat from it to satisfy your hunger."
		icon_color = Color(0.72, 0.53, 0.04)  # golden/brown
		charge_max = 10
		charge = 0
		charge_rate = 0.0  # charges from feeding, not time
		exp_to_level = 15
		default_action = "EAT"

	func on_turn(_hero: Char) -> void:
		pass  # No passive regen

	func passives(_hero: Char) -> void:
		pass

	## Feed a food item to the horn to gain charges.
	func feed_food(food_value: int) -> void:
		@warning_ignore("integer_division")
		var charges_gained: int = maxi(1, food_value / 50)
		charge = mini(charge + charges_gained, charge_max)
		gain_exp(charges_gained * 2)
		if MessageLog:
			MessageLog.add(
				"The Horn of Plenty absorbs the food! (+%d charges, %d/%d)" % [
					charges_gained, charge, charge_max
				],
				icon_color
			)

	## Eat from the horn to reduce hunger.
	func activate(_hero: Char) -> bool:
		var hero: Char = _hero
		if charge <= 0:
			if MessageLog:
				MessageLog.add("The Horn of Plenty is empty.", icon_color)
			return false

		var charges_to_eat: int = mini(charge, 3)
		charge -= charges_to_eat
		var hunger_restored: float = hunger_per_charge * float(charges_to_eat)

		# Find and reduce the hunger buff on the hero
		if hero and hero.get("_buffs") != null:
			for buff: Node in hero._buffs:
				if buff.get("buff_id") == "Hunger":
					var current_hunger: float = buff.get("hunger_level") if buff.get("hunger_level") != null else 0.0
					buff.hunger_level = maxf(0.0, current_hunger - hunger_restored)
					break

		gain_exp(charges_to_eat)
		if MessageLog:
			MessageLog.add(
				"You eat from the Horn of Plenty. (-%d charges, restored %.0f hunger)" % [
					charges_to_eat, hunger_restored
				],
				icon_color
			)
		if EventBus:
			EventBus.item_used.emit(item_name)
			EventBus.hero_stats_changed.emit()
		return true

	func level_up() -> void:
		super.level_up()
		charge_max = 10 + level * 2
		hunger_per_charge = 50.0 + float(level) * 10.0


# ===========================================================================
# MASTER THIEVES ARMBAND
# ===========================================================================
class MasterThievesArmband extends Artifact:
	## Identifies item value. Charges from picking up gold.
	## Active: steal from shopkeeper.

	## Total gold collected while this artifact was equipped.
	var gold_collected_total: int = 0

	func _init() -> void:
		super._init()
		item_id = "master_thieves_armband"
		item_name = "Master Thieves' Armband"
		description = "An inconspicuous leather armband once worn by the king of thieves. " \
			+ "Reveals the true value of items and allows you to steal from shopkeepers."
		icon_color = Color(0.1, 0.35, 0.1)  # dark_green
		charge_max = 15
		charge = 0
		charge_rate = 0.0  # charges from gold pickup
		exp_to_level = 20

	func on_turn(_hero: Char) -> void:
		pass

	func passives(_hero: Char) -> void:
		# Passive: hero can see item sell values (handled by UI layer)
		pass

	## Called when the hero picks up gold while this artifact is equipped.
	func on_gold_pickup(gold_amount: int) -> void:
		gold_collected_total += gold_amount
		@warning_ignore("integer_division")
		var charge_gain: int = maxi(1, gold_amount / 10)
		charge = mini(charge + charge_gain, charge_max)
		@warning_ignore("integer_division")
		gain_exp(maxi(1, gold_amount / 20))

	## Attempt to steal from a shopkeeper.
	func activate(hero: Char) -> bool:
		if hero == null:
			return false
		var cost: int = charge_max
		if not _spend_charge(cost):
			if MessageLog:
				MessageLog.add(
					"The armband needs a full charge to steal. (%d/%d)" % [charge, charge_max],
					icon_color
				)
			return false

		var shopkeeper: Variant = _find_nearby_shopkeeper(hero)
		if shopkeeper == null:
			if MessageLog:
				MessageLog.add(
					"There is no shopkeeper nearby to steal from.",
					icon_color
				)
			charge = mini(charge + cost, charge_max)
			return false

		var stolen_entry: Dictionary = _pick_shop_item_to_steal(shopkeeper)
		if stolen_entry.is_empty():
			if MessageLog:
				MessageLog.add(
					"The shopkeeper has nothing left worth stealing.",
					icon_color
				)
			charge = mini(charge + cost, charge_max)
			return false

		# Steal success chance scales with level
		var success_chance: float = 0.5 + float(level) * 0.05
		var roll: float = randf()

		if roll < success_chance:
			var stolen_item: Variant = stolen_entry.get("item")
			var shop_inventory: Array = shopkeeper.shop_inventory if shopkeeper.get("shop_inventory") != null else []
			var index: int = shop_inventory.find(stolen_entry)
			if index >= 0:
				shopkeeper.shop_inventory.remove_at(index)
			var belongings: Variant = hero.get("belongings")
			var added_to_inventory: bool = false
			if belongings != null and belongings.has_method("add_item") and stolen_item != null:
				added_to_inventory = belongings.add_item(stolen_item)
			if not added_to_inventory:
				var hero_level_ref: Variant = hero.get("level")
				if hero_level_ref != null and hero_level_ref.has_method("drop_item") and stolen_item != null:
					hero_level_ref.drop_item(hero.pos, stolen_item)
			if MessageLog:
				MessageLog.add(
					"Your fingers are quicker than the eye! You steal %s!" % ConstantsData.get_prop(stolen_item, "item_name", "an item"),
					icon_color
				)
			gain_exp(10)
			if EventBus:
				EventBus.item_used.emit(item_name)
			return true
		else:
			if MessageLog:
				MessageLog.add(
					"You are caught stealing! The shopkeeper is furious!",
					Color.RED
				)
			if shopkeeper.has_method("_flee"):
				shopkeeper.call("_flee")
			if EventBus:
				EventBus.item_used.emit(item_name)
			return false

	func _find_nearby_shopkeeper(hero: Char) -> Variant:
		var hero_level_ref: Variant = hero.get("level") if hero != null else null
		if hero_level_ref == null or hero_level_ref.get("mobs") == null:
			return null
		for mob_ref: Variant in hero_level_ref.mobs:
			if mob_ref == null or not is_instance_valid(mob_ref):
				continue
			if str(mob_ref.get("mob_id")) == "shopkeeper" and hero.distance_to(mob_ref.pos) <= 1:
				return mob_ref
		return null

	func _pick_shop_item_to_steal(shopkeeper: Variant) -> Dictionary:
		var inventory: Array = shopkeeper.shop_inventory if shopkeeper != null and shopkeeper.get("shop_inventory") != null else []
		if inventory.is_empty():
			return {}
		var best_entry: Dictionary = {}
		var best_price: int = -1
		for entry_variant: Variant in inventory:
			if entry_variant is Dictionary:
				var entry: Dictionary = entry_variant as Dictionary
				var price: int = int(entry.get("price", 0))
				if price > best_price:
					best_price = price
					best_entry = entry
		return best_entry

	func level_up() -> void:
		super.level_up()
		charge_max = 15 + level * 3

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["gold_collected_total"] = gold_collected_total
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		gold_collected_total = data.get("gold_collected_total", 0)


# ===========================================================================
# SANDALS OF NATURE
# ===========================================================================
class SandalsOfNature extends Artifact:
	## Grow grass and plants. Charges from collecting seeds.
	## Higher level = more powerful plants.

	## Number of seeds fed to the sandals.
	var seeds_fed: int = 0

	func _init() -> void:
		super._init()
		item_id = "sandals_of_nature"
		item_name = "Sandals of Nature"
		description = "Soft leather sandals entwined with living vines. Feed them seeds to " \
			+ "charge them, then walk to grow grass and plants in your wake. Higher " \
			+ "levels produce more potent plants."
		icon_color = Color(0.2, 0.7, 0.2)  # green
		charge_max = 8
		charge = 0
		charge_rate = 0.0  # charges from seeds
		exp_to_level = 12

	func on_turn(hero: Char) -> void:
		# When charged and walking, grow grass at the hero's position
		if charge > 0:
			var hero_pos: int = hero.get("pos") if hero.get("pos") != null else -1
			if hero_pos >= 0:
				_grow_at_position(hero_pos, hero)

	func passives(_hero: Char) -> void:
		# Passive: grass and plants near hero grow faster (handled by level system)
		pass

	## Feed a seed to the sandals.
	func feed_seed(seed_name: String) -> void:
		seeds_fed += 1
		charge = mini(charge + 1, charge_max)
		gain_exp(3)
		if MessageLog:
			MessageLog.add(
				"The Sandals of Nature absorb the %s. (%d/%d)" % [
					seed_name, charge, charge_max
				],
				icon_color
			)

	func activate(hero: Char) -> bool:
		if charge <= 0:
			if MessageLog:
				MessageLog.add("The sandals have no charges.", icon_color)
			return false

		var hero_pos: int = hero.get("pos") if hero.get("pos") != null else -1
		var hero_level_ref: Variant = hero.get("level") if hero != null else null
		if hero_pos < 0:
			return false
		if hero_level_ref == null:
			return false

		_spend_charge(1)
		@warning_ignore("integer_division")
		var plant_tier: int = mini(level / 3, 3)  # 0-3 based on level
		var grown_cells: int = _burst_growth(hero_pos, hero_level_ref, plant_tier)

		if MessageLog:
			var plant_names: Array[String] = ["grass", "a patch of grass", "a thick patch of high grass", "a vibrant overgrowth"]
			MessageLog.add(
				"You channel nature's energy, growing %s! (%d)" % [plant_names[plant_tier], grown_cells],
				icon_color
			)
		gain_exp(2)
		if EventBus:
			EventBus.item_used.emit(item_name)
		return true

	## Internal: grow grass/plants when walking over tiles.
	func _grow_at_position(_pos: int, _hero: Char) -> void:
		# Chance to grow grass scales with level
		var grow_chance: float = 0.1 + float(level) * 0.05
		if randf() < grow_chance:
			var hero_level_ref: Variant = _hero.get("level") if _hero != null else null
			if hero_level_ref != null:
				if _apply_growth_to_cell(_pos, hero_level_ref, level >= 6):
					_spend_charge(1)
					gain_exp(1)

	func _burst_growth(center_pos: int, hero_level_ref: Variant, plant_tier: int) -> int:
		var grown_cells: int = 0
		var radius: int = mini(1 + plant_tier, 2)
		var upgrade_to_high_grass: bool = plant_tier >= 2
		var positions: Array[int] = [center_pos]
		for dir: int in ConstantsData.DIRS_8:
			positions.append(center_pos + dir)
		if radius > 1:
			for pos: int in positions.duplicate():
				for dir: int in ConstantsData.DIRS_8:
					var next_pos: int = pos + dir
					if next_pos not in positions:
						positions.append(next_pos)
		for cell: int in positions:
			if _apply_growth_to_cell(cell, hero_level_ref, upgrade_to_high_grass):
				grown_cells += 1
		return grown_cells

	func _apply_growth_to_cell(cell: int, hero_level_ref: Variant, upgrade_to_high_grass: bool) -> bool:
		if hero_level_ref == null or not hero_level_ref.has_method("get_terrain") or not hero_level_ref.has_method("set_terrain"):
			return false
		if cell < 0 or cell >= ConstantsData.LENGTH:
			return false
		var terrain: int = hero_level_ref.get_terrain(cell)
		match terrain:
			ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.EMBERS:
				hero_level_ref.set_terrain(cell, ConstantsData.Terrain.GRASS)
				return true
			ConstantsData.Terrain.GRASS, ConstantsData.Terrain.FURROWED_GRASS:
				if upgrade_to_high_grass:
					hero_level_ref.set_terrain(cell, ConstantsData.Terrain.HIGH_GRASS)
					return true
			ConstantsData.Terrain.HIGH_GRASS:
				return false
		return false

	func level_up() -> void:
		super.level_up()
		charge_max = 8 + level * 2

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["seeds_fed"] = seeds_fed
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		seeds_fed = data.get("seeds_fed", 0)


# ===========================================================================
# TALISMAN OF FORESIGHT
# ===========================================================================
class TalismanOfForesight extends Artifact:
	## Detect secrets. Passive: nearby traps/secret doors revealed.
	## Charges from searching. Active: reveal all secrets on level.

	## Radius of passive detection (tiles).
	var detection_radius: int = 2
	## Turns spent searching while equipped.
	var search_turns: int = 0

	func _init() -> void:
		super._init()
		item_id = "talisman_of_foresight"
		item_name = "Talisman of Foresight"
		description = "A crystal talisman that glows faintly in the presence of hidden things. " \
			+ "Passively reveals nearby traps and secret doors. Charge it by searching, " \
			+ "then activate to reveal all secrets on the current floor."
		icon_color = Color(1.0, 0.84, 0.0)  # gold
		charge_max = 100
		charge = 0
		charge_rate = 0.0  # charges from searching
		exp_to_level = 18

	func on_turn(hero: Char) -> void:
		# Passive: reveal traps and secrets within detection radius
		var hero_pos: int = hero.get("pos") if hero.get("pos") != null else -1
		if hero_pos >= 0:
			_detect_nearby(hero_pos, hero)

	func passives(_hero: Char) -> void:
		# Detection radius scales with level
		@warning_ignore("integer_division")
		detection_radius = 2 + level / 2

	## Called when the hero performs a search action.
	func on_search() -> void:
		search_turns += 1
		var charge_gain: int = 5 + level
		charge = mini(charge + charge_gain, charge_max)
		gain_exp(1)

	## Reveal all secrets on the current floor.
	func activate(hero: Char) -> bool:
		if charge < charge_max:
			if MessageLog:
				MessageLog.add(
					"The talisman is not fully charged. (%d/%d)" % [charge, charge_max],
					icon_color
				)
			return false

		charge = 0
		gain_exp(10)

		# Reveal all hidden things on the floor
		var hero_level_ref: Variant = hero.get("level") if hero != null else null
		if hero_level_ref != null and hero_level_ref.has_method("reveal_all_secrets"):
			hero_level_ref.reveal_all_secrets()

		if MessageLog:
			MessageLog.add(
				"The Talisman flashes brilliantly! All secrets on this floor are revealed!",
				icon_color
			)
		if EventBus:
			EventBus.item_used.emit(item_name)
		return true

	## Internal: detect nearby traps and secrets.
	func _detect_nearby(hero_pos: int, hero: Char) -> void:
		var hero_level_ref: Variant = hero.get("level") if hero != null else null
		if hero_level_ref == null:
			return
		# The actual trap/secret reveal logic is handled by the Level class.
		# We just signal the detection range.
		if hero_level_ref.has_method("reveal_around"):
			hero_level_ref.reveal_around(hero_pos, detection_radius)

	func level_up() -> void:
		super.level_up()
		@warning_ignore("integer_division")
		detection_radius = 2 + level / 2

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["detection_radius"] = detection_radius
		data["search_turns"] = search_turns
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		detection_radius = data.get("detection_radius", 2)
		search_turns = data.get("search_turns", 0)


# ===========================================================================
# TIMEKEEPER HOURGLASS
# ===========================================================================
class TimekeeperHourglass extends Artifact:
	## Freeze time. Activate to stop all enemies for several turns.
	## Charges slowly over time.

	## Turns remaining on time freeze.
	var freeze_turns: int = 0

	func _init() -> void:
		super._init()
		item_id = "timekeeper_hourglass"
		item_name = "Timekeeper's Hourglass"
		description = "An ancient hourglass filled with shimmering golden sand. Activate to " \
			+ "freeze time around you, stopping all enemies in their tracks for " \
			+ "several turns."
		icon_color = Color(0.76, 0.7, 0.5)  # sandy
		charge_max = 10
		charge = 10
		charge_rate = 0.15  # Charges very slowly
		exp_to_level = 25

	func on_turn(_hero: Char) -> void:
		if activated and freeze_turns > 0:
			freeze_turns -= 1
			if freeze_turns <= 0:
				activated = false
				if MessageLog:
					MessageLog.add("Time resumes its normal flow.", icon_color)
		else:
			_recharge()

	func passives(_hero: Char) -> void:
		pass

	## Is time currently frozen?
	func is_time_frozen() -> bool:
		return activated and freeze_turns > 0

	func activate(_hero: Char) -> bool:
		if activated:
			if MessageLog:
				MessageLog.add("Time is already frozen!", icon_color)
			return false

		var cost: int = charge_max
		if not _spend_charge(cost):
			if MessageLog:
				MessageLog.add(
					"The hourglass needs a full charge. (%d/%d)" % [charge, charge_max],
					icon_color
				)
			return false

		activated = true
		@warning_ignore("integer_division")
		freeze_turns = 3 + level / 2
		gain_exp(5)

		if MessageLog:
			MessageLog.add(
				"The sands of time stand still! (%d turns)" % freeze_turns,
				icon_color
			)
		if EventBus:
			EventBus.item_used.emit(item_name)
		# The TurnManager checks is_time_frozen() to skip enemy turns.
		return true

	func level_up() -> void:
		super.level_up()
		charge_max = 10 + level

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["freeze_turns"] = freeze_turns
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		freeze_turns = data.get("freeze_turns", 0)


# ===========================================================================
# UNSTABLE SPELLBOOK
# ===========================================================================
class UnstableSpellbook extends Artifact:
	## Randomized scroll effects. Use to cast a random scroll effect.
	## Gains exp from feeding it scrolls.

	## All possible scroll effect IDs that can be cast.
	const SCROLL_EFFECTS: Array[String] = [
		"identify",
		"upgrade",
		"remove_curse",
		"teleportation",
		"lullaby",
		"rage",
		"terror",
		"magic_mapping",
		"retribution",
		"mirror_image",
		"transmutation",
		"recharging",
	]

	## Scrolls that have been fed to the book (can't get those as random results).
	var fed_scrolls: Array[String] = []

	func _init() -> void:
		super._init()
		item_id = "unstable_spellbook"
		item_name = "Unstable Spellbook"
		description = "A leather-bound book crackling with chaotic arcane energy. Feed it " \
			+ "scrolls to level it up. Use it to unleash a random scroll effect — " \
			+ "you never know what you will get!"
		icon_color = Color(0.1, 0.15, 0.6)  # deep_blue
		charge_max = 3
		charge = 3
		charge_rate = 0.25
		exp_to_level = 15
		default_action = "READ"

	func on_turn(_hero: Char) -> void:
		_recharge()

	func passives(_hero: Char) -> void:
		pass

	## Feed a scroll to the spellbook for experience.
	func feed_scroll(scroll_id: String) -> void:
		if scroll_id not in fed_scrolls:
			fed_scrolls.append(scroll_id)
		gain_exp(10)
		if MessageLog:
			MessageLog.add(
				"The Spellbook absorbs the scroll's knowledge!",
				icon_color
			)

	## Cast a random scroll effect.
	func activate(hero: Char) -> bool:
		if hero == null:
			return false
		var cost: int = 1
		if not _spend_charge(cost):
			if MessageLog:
				MessageLog.add("The spellbook has no charges.", icon_color)
			return false

		# Choose a random scroll effect (excluding fed scrolls at higher levels)
		var available: Array[String] = []
		for effect: String in SCROLL_EFFECTS:
			if level >= 5 and effect in fed_scrolls:
				continue  # At high level, fed scrolls are excluded from random pool
			available.append(effect)

		if available.is_empty():
			available = SCROLL_EFFECTS.duplicate()

		var chosen: String = available[randi() % available.size()]
		var scroll: Scroll = Scroll.create(chosen)
		if scroll == null:
			if MessageLog:
				MessageLog.add("The spellbook sputters and fails to weave a spell.", Color.RED)
			return false
		scroll.identified = true
		scroll.known = true

		gain_exp(3)
		if MessageLog:
			var display_name: String = chosen.replace("_", " ").capitalize()
			MessageLog.add(
				"The Spellbook casts: %s!" % display_name,
				icon_color
			)
		scroll.read_scroll(hero)
		if EventBus:
			EventBus.item_used.emit(item_name)
		return true

	func level_up() -> void:
		super.level_up()
		@warning_ignore("integer_division")
		charge_max = 3 + level / 3

	func serialize() -> Dictionary:
		var data: Dictionary = super.serialize()
		data["fed_scrolls"] = fed_scrolls
		return data

	func deserialize(data: Dictionary) -> void:
		super.deserialize(data)
		var raw: Variant = data.get("fed_scrolls", [])
		fed_scrolls.clear()
		if raw is Array:
			for s: Variant in raw:
				if s is String:
					fed_scrolls.append(s)


# ===========================================================================
# ALCHEMISTS TOOLKIT
# ===========================================================================
class AlchemistsToolkit extends Artifact:
	## Alchemy bonuses. Reduces energy cost of recipes. Gains exp from crafting.

	## Percentage reduction in alchemy energy cost (0.0 to 1.0).
	var energy_discount: float = 0.1

	func _init() -> void:
		super._init()
		item_id = "alchemists_toolkit"
		item_name = "Alchemist's Toolkit"
		description = "A portable alchemy kit containing vials, burners, and reagents. " \
			+ "Reduces the energy cost of alchemical recipes. Gains experience " \
			+ "each time you craft something."
		icon_color = Color(0.85, 0.65, 0.13)  # amber
		charge_max = 0  # Not charge-based — passive effect
		charge_rate = 0.0
		exp_to_level = 18

	func on_turn(_hero: Char) -> void:
		pass

	func passives(_hero: Char) -> void:
		# The alchemy system checks get_energy_discount() when crafting
		energy_discount = 0.1 + float(level) * 0.05

	## Returns the fractional energy discount (e.g. 0.25 = 25% off).
	func get_energy_discount() -> float:
		return minf(energy_discount, 0.6)  # Cap at 60% discount

	## Called by the alchemy system when a recipe is crafted.
	func on_craft(recipe_cost: int) -> void:
		@warning_ignore("integer_division")
		var exp_gain: int = maxi(1, recipe_cost / 2)
		gain_exp(exp_gain)
		if MessageLog:
			MessageLog.add(
				"The toolkit hums with satisfaction!",
				icon_color
			)

	## Calculate the reduced energy cost for a recipe.
	func apply_discount(base_cost: int) -> int:
		var discount: float = get_energy_discount()
		var reduced: int = maxi(1, int(float(base_cost) * (1.0 - discount)))
		return reduced

	func activate(_hero: Char) -> bool:
		if MessageLog:
			MessageLog.add(
				"The toolkit has no active ability. It reduces alchemy costs passively. " \
				+ "(%.0f%% discount)" % (get_energy_discount() * 100.0),
				icon_color
			)
		return false

	func get_display_name() -> String:
		var display: String = item_name
		if level > 0:
			display += " +%d" % level
		display += " (%.0f%% off)" % (get_energy_discount() * 100.0)
		if cursed and cursed_known:
			display = "cursed " + display
		return display
