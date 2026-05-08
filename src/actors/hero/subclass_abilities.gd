class_name SubclassAbilities
extends RefCounted
## Central registry for all hero subclass abilities and passive effects.
## Each subclass has one or more abilities that modify combat, movement, or item use.
## This is called from Hero when a subclass is assigned (depth 6 boss).

# ---------------------------------------------------------------------------
# Subclass Data
# ---------------------------------------------------------------------------

class SubclassInfo:
	var id: int = ConstantsData.HeroSubclass.NONE
	var name: String = ""
	var description: String = ""
	var perks: Array[String] = []

static func get_subclass_info(subclass: int) -> SubclassInfo:
	var info: SubclassInfo = SubclassInfo.new()
	info.id = subclass
	match subclass:
		ConstantsData.HeroSubclass.BERSERKER:
			info.name = "Berserker"
			info.description = "The Berserker channels fury from wounds into devastating power."
			info.perks = [
				"Gains Fury buff at low HP (below 50%), boosting damage by 50%",
				"Rage builds as damage is taken, preventing death once per fight when maxed",
				"Bonus damage scales with missing HP percentage",
			]
		ConstantsData.HeroSubclass.GLADIATOR:
			info.name = "Gladiator"
			info.description = "The Gladiator chains attacks into powerful combo finishers."
			info.perks = [
				"Successive hits build combo counter (max 10)",
				"Combo finisher at 3+ hits deals bonus damage (1.5x at 3, up to 3x at 10)",
				"Combo resets if a turn passes without attacking",
			]
		ConstantsData.HeroSubclass.BATTLEMAGE:
			info.name = "Battlemage"
			info.description = "The Battlemage imbues melee attacks with wand effects."
			info.perks = [
				"Melee attacks with staff trigger the imbued wand's on-hit effect",
				"Wand recharge rate increased by 33%",
				"Staff melee attacks have a chance to gain a charge on the imbued wand",
			]
		ConstantsData.HeroSubclass.WARLOCK:
			info.name = "Warlock"
			info.description = "The Warlock marks enemies with dark magic, draining their life force."
			info.perks = [
				"Wand attacks apply Soul Mark to targets",
				"Melee kills on Soul Marked enemies heal the Warlock and satisfy hunger",
				"Soul Mark healing scales with enemy max HP (10%)",
			]
		ConstantsData.HeroSubclass.ASSASSIN:
			info.name = "Assassin"
			info.description = "The Assassin prepares devastating strikes from the shadows."
			info.perks = [
				"Gains Preparation buff while invisible or out of enemy sight",
				"First attack from Preparation deals massive bonus damage (up to 3x)",
				"Preparation level increases the longer the Assassin stays hidden",
			]
		ConstantsData.HeroSubclass.FREERUNNER:
			info.name = "Freerunner"
			info.description = "The Freerunner builds momentum through constant movement."
			info.perks = [
				"Gains Momentum buff from consecutive movement without attacking",
				"At max momentum, gains +50% evasion and +50% speed",
				"Momentum resets when the Freerunner attacks or waits",
			]
		ConstantsData.HeroSubclass.SNIPER:
			info.name = "Sniper"
			info.description = "The Sniper excels at precise, long-range attacks."
			info.perks = [
				"Ranged attacks gain +50% accuracy",
				"Thrown weapons and spirit bow shots can snapshot (instant, no turn cost) every 3 turns",
				"See enemy HP bars from further away",
			]
		ConstantsData.HeroSubclass.WARDEN:
			info.name = "Warden"
			info.description = "The Warden draws power from nature, turning the dungeon itself into an ally."
			info.perks = [
				"Walking over grass/plants grants temporary Barkskin (armor from nature)",
				"Seeds thrown by the Warden have double area of effect",
				"Plants last twice as long and have enhanced effects",
			]
		ConstantsData.HeroSubclass.CHAMPION:
			info.name = "Champion"
			info.description = "The Champion masters wielding two weapons simultaneously."
			info.perks = [
				"Can equip a second melee weapon in the ring slot",
				"Alternates attacks between primary and secondary weapon",
				"Both weapons contribute to defense",
			]
		ConstantsData.HeroSubclass.MONK:
			info.name = "Monk"
			info.description = "The Monk unleashes rapid flurries of unarmed strikes."
			info.perks = [
				"Unarmed attacks become faster with consecutive hits (up to 3x speed)",
				"Gains Focus buff: next attack has +100% accuracy after dodging",
				"Unarmed damage scales with hero level",
			]
	return info

# ---------------------------------------------------------------------------
# Applying Subclass to Hero
# ---------------------------------------------------------------------------

## Apply subclass abilities to a hero. Called when the subclass is chosen.
static func apply_subclass(hero: Hero, subclass: int) -> void:
	hero.hero_subclass = subclass
	if GameManager:
		GameManager.hero_subclass = subclass

	match subclass:
		ConstantsData.HeroSubclass.BERSERKER:
			_apply_berserker(hero)
		ConstantsData.HeroSubclass.GLADIATOR:
			_apply_gladiator(hero)
		ConstantsData.HeroSubclass.BATTLEMAGE:
			_apply_battlemage(hero)
		ConstantsData.HeroSubclass.WARLOCK:
			_apply_warlock(hero)
		ConstantsData.HeroSubclass.ASSASSIN:
			_apply_assassin(hero)
		ConstantsData.HeroSubclass.FREERUNNER:
			_apply_freerunner(hero)
		ConstantsData.HeroSubclass.SNIPER:
			_apply_sniper(hero)
		ConstantsData.HeroSubclass.WARDEN:
			_apply_warden(hero)
		ConstantsData.HeroSubclass.CHAMPION:
			_apply_champion(hero)
		ConstantsData.HeroSubclass.MONK:
			_apply_monk(hero)

	if MessageLog:
		var info: SubclassInfo = get_subclass_info(subclass)
		MessageLog.add_positive("You have become a %s!" % info.name)

# ---------------------------------------------------------------------------
# Subclass Application
# ---------------------------------------------------------------------------

static func _apply_berserker(hero: Hero) -> void:
	# Berserker gets a permanent BerserkerRage buff that activates at low HP
	var rage: BerserkerRage = BerserkerRage.new()
	hero.add_buff(rage)

static func _apply_gladiator(hero: Hero) -> void:
	# Gladiator gets a combo tracker buff
	var combo_tracker: GladiatorCombo = GladiatorCombo.new()
	hero.add_buff(combo_tracker)

static func _apply_battlemage(hero: Hero) -> void:
	# Battlemage gets wand recharge boost (passive stat modifier)
	var battlemage_buff: BattemagePower = BattemagePower.new()
	hero.add_buff(battlemage_buff)

static func _apply_warlock(hero: Hero) -> void:
	# Warlock gets soul mark passive
	var soul_mark: SoulMarkPassive = SoulMarkPassive.new()
	hero.add_buff(soul_mark)

static func _apply_assassin(hero: Hero) -> void:
	# Assassin gets preparation tracker
	var prep: AssassinPreparation = AssassinPreparation.new()
	hero.add_buff(prep)

static func _apply_freerunner(hero: Hero) -> void:
	# Freerunner gets momentum tracker
	var momentum: FreerunnerMomentum = FreerunnerMomentum.new()
	hero.add_buff(momentum)

static func _apply_sniper(hero: Hero) -> void:
	# Sniper gets ranged accuracy boost and snapshot tracker
	var sniper_buff: SniperMark = SniperMark.new()
	hero.add_buff(sniper_buff)

static func _apply_warden(hero: Hero) -> void:
	# Warden gets barkskin on nature terrain
	var barkskin: WardenBarkskin = WardenBarkskin.new()
	hero.add_buff(barkskin)

static func _apply_champion(hero: Hero) -> void:
	# Champion gets dual-wield passive
	var dual: ChampionDualWield = ChampionDualWield.new()
	hero.add_buff(dual)

static func _apply_monk(hero: Hero) -> void:
	# Monk gets flurry tracker
	var flurry: MonkFlurry = MonkFlurry.new()
	hero.add_buff(flurry)
