class_name TalentData
extends RefCounted
## Static registry for hero talents. This is a groundwork layer only:
## point gain, storage, save/load, and read-only UI can build on this before
## active talent effects and picker windows are implemented.

class TalentInfo:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var max_points: int = 2
	var tier: int = 1
	var required_subclass: int = ConstantsData.HeroSubclass.NONE
	## False for groundwork slots whose effect is not wired into gameplay yet.
	## Unimplemented talents cannot be upgraded and are flagged in the picker.
	var implemented: bool = true

## Upstream Talent.tierLevelThresholds: tiers 1/2/3/4 start at levels 2/7/13/21,
## and the final 31 bounds tier 4's point band (tiers earn points only inside
## their own level band — see Hero.talent_points_available_for).
const TIER_LEVEL_THRESHOLDS: Array[int] = [0, 2, 7, 13, 21, 31]

static func tier_unlock_level(tier: int) -> int:
	if tier < 1 or tier >= TIER_LEVEL_THRESHOLDS.size():
		return TIER_LEVEL_THRESHOLDS[TIER_LEVEL_THRESHOLDS.size() - 1]
	return TIER_LEVEL_THRESHOLDS[tier]

static func get_talents_for(hero_class: int, hero_subclass: int = ConstantsData.HeroSubclass.NONE) -> Array[TalentInfo]:
	var talents: Array[TalentInfo] = []
	talents.append_array(_class_talents(hero_class))
	if hero_subclass != ConstantsData.HeroSubclass.NONE:
		talents.append_array(_subclass_talents(hero_subclass))
	return talents

static func get_talent(hero_class: int, talent_id: String, hero_subclass: int = ConstantsData.HeroSubclass.NONE) -> TalentInfo:
	for talent: TalentInfo in get_talents_for(hero_class, hero_subclass):
		if talent.id == talent_id:
			return talent
	return null

static func _class_talents(hero_class: int) -> Array[TalentInfo]:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			return [
				_make("warrior_hearty_meal", "Hearty Meal", "Eating while healthy grants a temporary barrier.", 2, 1),
				_make("warrior_veterans_intuition", "Veteran's Intuition", "The Warrior's intuition with armor improves: equipping armor has a 50% chance to identify it, or always identifies it at +2.", 2, 1),
				_make("warrior_tested_hypothesis", "Tested Hypothesis", "Potions of Healing and Scrolls of Identify can be recognized on pickup.", 2, 1),
				_make("warrior_provoked_anger", "Provoked Anger", "When any shielding buff applied to the Warrior is broken by damage, his next physical attack deals 3/5 bonus damage.", 2, 1),
				_make("warrior_iron_will", "Iron Will", "The Warrior's broken seal grants +1/+2 max shield.", 2, 2),
				_make("warrior_iron_stomach", "Iron Stomach", "Eating food grants the Warrior 75%/100% damage resistance while he eats.", 2, 2),
				_make("warrior_liquid_willpower", "Liquid Willpower", "When the Warrior drinks or throws a potion, he gains a shield equal to 6.5%/10% of his max HP.", 2, 2),
				_make("warrior_runic_transference", "Runic Transference", "When the Warrior's broken seal moves to unglyphed armor, the old armor's glyph transfers with it. At +1 common and uncommon glyphs transfer, at +2 any glyph transfers.", 2, 2),
				_make("warrior_lethal_momentum", "Lethal Momentum", "When the Warrior lands a killing blow, there is a 67%/100% chance that the attack takes no time.", 2, 2),
				_make("warrior_improvised_projectiles", "Improvised Projectiles", "When the Warrior throws any item that isn't a thrown weapon at an enemy, that enemy is blinded for 2/3 turns. This effect has a 50 turn cooldown.", 2, 2),
				_make("warrior_hold_fast", "Hold Fast", "When the Warrior waits he gains 1-2/2-4/3-6 armor and slows the decay of combo and shielding buffs by 50%/75%/100% until he moves.", 3, 3),
				_make("warrior_strongman", "Strongman", "The Warrior's strength is increased by 8%/13%/18% of its base value, rounded down.", 3, 3),
			]
		ConstantsData.HeroClass.MAGE:
			return [
				_make("mage_empowering_meal", "Empowering Meal", "Eating food grants the Mage 2/3 bonus damage on his next 3 damage-wand zaps.", 2, 1),
				_make("mage_scholars_intuition", "Scholar's Intuition", "The Mage identifies wands as he uses them 3x/5x faster, and at +2 a single zap fully identifies a wand.", 2, 1),
				_make("mage_lingering_magic", "Lingering Magic", "When the Mage zaps with a wand or staff, his next physical attack deals 1-2/2 bonus damage.", 2, 1),
				_make("mage_backup_barrier", "Backup Barrier", "Crossing below half health triggers an emergency barrier once until you recover.", 2, 1),
				_make("mage_energizing_meal", "Energizing Meal", "Eating food grants the Mage 5/8 turns of Recharging.", 2, 2),
				_make_inert("mage_inscribed_power", "Inscribed Power", "Groundwork slot: reading a scroll grants bonus wand levels for a few turns (ScrollEmpower buff not ported yet).", 2, 2),
				_make_inert("mage_wand_preservation", "Wand Preservation", "Groundwork slot: a wand consumed to imbue the Mage's staff has a chance to be preserved (staff imbue flow not ported yet).", 2, 2),
				_make("mage_arcane_vision", "Arcane Vision", "When the Mage zaps a character with a wand, he can see that character for 10/15 turns, even through walls.", 2, 2),
				_make("mage_shield_battery", "Shield Battery", "The Mage can zap a wand at himself to convert all of its charges into a barrier of 4% max HP per charge, 6% at +2.", 2, 2),
				_make("mage_desperate_power", "Desperate Power", "When the Mage zaps a wand's last charge, that zap acts as if the wand were 1/2/3 levels higher. (In the port this currently boosts bolt damage only.)", 3, 3),
				_make_inert("mage_ally_warp", "Ally Warp", "Groundwork slot: the Mage can target an ally with a wand to teleport them next to him instead of zapping (ally system not ported yet).", 3, 3),
			]
		ConstantsData.HeroClass.ROGUE:
			return [
				_make("rogue_cached_rations", "Cached Rations", "Food satisfies extra hunger.", 2, 1),
				_make("rogue_thiefs_intuition", "Thief's Intuition", "Rings can be identified on pickup.", 2, 1),
				_make("rogue_sucker_punch", "Sucker Punch", "The first time the Rogue surprise attacks each enemy, he deals 1-2/2 bonus damage.", 2, 1),
				_make("rogue_protective_shadows", "Protective Shadows", "While invisible, the Rogue gradually gains a protective barrier.", 2, 1),
				_make("rogue_mystical_meal", "Mystical Meal", "Eating food instantly grants the Rogue 3/5 turns' worth of artifact recharging.", 2, 2),
				_make("rogue_inscribed_stealth", "Inscribed Stealth", "Reading a scroll grants the Rogue 3/5 turns of invisibility.", 2, 2),
				_make("rogue_wide_search", "Wide Search", "The Rogue's search radius is increased by 1. At +1 the corners of the expanded area are rounded off, at +2 the full expanded area is searched.", 2, 2),
				_make("rogue_silent_steps", "Silent Steps", "The Rogue will not wake sleeping enemies while he is 3 or more tiles away from them, or at +2 while he is not adjacent to them.", 2, 2),
				_make_inert("rogue_rogues_foresight", "Rogue's Foresight", "Groundwork slot: the Rogue has a 75%/100% chance to notice when a level contains a secret room (secret-room detection not ported yet).", 2, 2),
			]
		ConstantsData.HeroClass.HUNTRESS:
			return [
				_make("huntress_natures_bounty", "Nature's Bounty", "Trampling high grass can yield dewdrops or seeds.", 2, 1),
				_make("huntress_survivalists_intuition", "Survivalist's Intuition", "Missile weapons can be identified on pickup.", 2, 1),
				_make("huntress_followup_strike", "Followup Strike", "Landing a ranged hit empowers your next melee attack.", 2, 2),
				_make("huntress_natures_aid", "Nature's Aid", "When a plant triggers within her sight, the Huntress gains 2 points of barkskin for 3/5 turns.", 2, 2),
			]
		ConstantsData.HeroClass.DUELIST:
			return [
				_make("duelist_adventurers_intuition", "Adventurer's Intuition", "Weapons and armor can be identified on pickup.", 2, 1),
				_make("duelist_patient_strike", "Patient Strike", "Waiting primes your next melee attack to deal increased damage.", 2, 1),
				_make_inert("duelist_aggressive_barrier", "Aggressive Barrier", "Supports offensive pressure with defensive conversion.", 2, 2),
				_make_inert("duelist_weapon_recharging", "Weapon Recharging", "Groundwork slot for weapon ability cadence.", 3, 2),
			]
	return []

static func _subclass_talents(hero_subclass: int) -> Array[TalentInfo]:
	match hero_subclass:
		ConstantsData.HeroSubclass.BERSERKER:
			return [
				_make("berserker_endless_rage", "Endless Rage", "The Berserker's rage cap is raised to 117%/133%/150%. Rage above 100% multiplies his damage.", 3, 3, hero_subclass),
				_make("berserker_deathless_fury", "Deathless Fury", "At full rage, lethal damage sends the Berserker into a deathless fury instead of killing him, granting a rage shield. More points shorten the recovery before it can trigger again.", 3, 3, hero_subclass),
				_make("berserker_enraged_catalyst", "Enraged Catalyst", "Enchantments on the Berserker's weapon trigger more often the more rage he has, up to 15%/30%/45% more often at 100% rage.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.GLADIATOR:
			return [
				_make("gladiator_cleave", "Cleave", "When the Gladiator kills an enemy with a combo hit, his combo lasts much longer: 6/9/12 turns instead of 3.", 3, 3, hero_subclass),
				_make("gladiator_lethal_defense", "Lethal Defense", "When the Gladiator kills an enemy with a combo finisher, the cooldown on his broken seal shielding is reduced by 50/100/150 turns. The cooldown can drop as low as -150 turns, making the shield immediately available again once it activates.", 3, 3, hero_subclass),
				_make("gladiator_enhanced_combo", "Enhanced Combo", "The Gladiator's combo builds further before unleashing: his finisher triggers at 5/7/9 hits instead of 3, hitting far harder — up to x3 damage at a 10-hit combo.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.BATTLEMAGE:
			return [
				_make("battlemage_empowered_strikes", "Empowered Strike", "The Battlemage's first melee strike with his staff within 10 turns of zapping it deals 17%/33%/50% bonus damage. (Upstream's bonus wand-effect power is not ported yet.)", 3, 3, hero_subclass),
				_make("battlemage_mystical_charge", "Mystical Charge", "Every melee hit with his staff instantly grants the Battlemage 0.5/1/1.5 turns of artifact recharging. Cursed artifacts do not benefit.", 3, 3, hero_subclass),
				_make("battlemage_excess_charge", "Excess Charge", "When the Battlemage zaps his staff while its wand is at full charge, he gains a shield equal to 0.67x/1.33x/2x the staff's level.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.WARLOCK:
			return [
				_make("warlock_soul_siphon", "Soul Siphon", "Physical damage dealt by other characters triggers the Warlock's soul mark at 13%/27%/40% effectiveness.", 3, 3, hero_subclass),
				_make("warlock_soul_eater", "Soul Eater", "Soul mark restoration also feeds the Warlock at 33%/67%/100% effectiveness, and killing a soul marked enemy has a 10%/20%/30% chance to trigger his on-eat talent effects.", 3, 3, hero_subclass),
				_make("warlock_necromancers_minions", "Necromancer's Minions", "Killing a soul marked enemy has a 13%/27%/40% chance to raise it as a wraith corrupted to fight for the Warlock.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.ASSASSIN:
			return [
				_make("assassin_enhanced_lethality", "Enhanced Lethality", "The Assassin's prepared attacks can instantly kill enemies at higher percentages of their max health, up to 67%/83%/100% at full preparation.", 3, 3, hero_subclass),
				_make_inert("assassin_assassins_reach", "Assassin's Reach", "Groundwork slot: prepared blink strikes reach further (blink attack UI not implemented yet).", 3, 3, hero_subclass),
				_make("assassin_bounty_hunter", "Bounty Hunter", "Killing an enemy with a prepared attack boosts its chance to drop loot by 2%/4%/8%/16% per preparation level, multiplied by talent points.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.FREERUNNER:
			return [
				_make("freerunner_evasive_armor", "Evasive Armor", "While at full momentum, the Freerunner gains 1/2/3 bonus evasion for each point of excess strength on his armor.", 3, 3, hero_subclass),
				_make("freerunner_projectile_momentum", "Projectile Momentum", "While at full momentum, the Freerunner's thrown weapon attacks are 50%/100%/150% more accurate.", 3, 3, hero_subclass),
				_make("freerunner_speedy_stealth", "Speedy Stealth", "While invisible, the Freerunner builds momentum rapidly instead of losing it. At +2 invisibility fully preserves his momentum, and at +3 he also moves twice as fast while invisible.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.SNIPER:
			return [
				_make("sniper_farsight", "Farsight", "The Sniper's vision range is increased by 25%/50%/75%.", 3, 3, hero_subclass),
				_make("sniper_shared_enchantment", "Shared Enchantment", "The Sniper's thrown weapons have a 33%/67%/100% chance to also benefit from the enchantment on her spirit bow.", 3, 3, hero_subclass),
				_make_inert("sniper_shared_upgrades", "Shared Upgrades", "Groundwork slot: the Sniper's marked bonus shots gain duration and damage from thrown-weapon upgrades (sniper's-mark free-shot system not ported yet).", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.WARDEN:
			return [
				_make("warden_durable_tips", "Durable Tips", "The Warden's tipped darts last longer: each dart survives 2/3/4 throws before being used up.", 3, 3, hero_subclass),
				_make("warden_barkskin", "Barkskin", "When stepping in grass, the Warden gains 0-50%/100%/150% of her level in barkskin armor which fades every turn.", 3, 3, hero_subclass),
				_make("warden_shielding_dew", "Shielding Dew", "Dew healing the Warden doesn't need is converted into shielding, up to a max of 20%/40%/60% of her max HP.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.CHAMPION:
			return [
				_make_inert("champion_dual_mastery", "Dual Mastery", "Supports more efficient dual-weapon pressure.", 3, 3, hero_subclass),
				_make_inert("champion_guarded_offense", "Guarded Offense", "Groundwork slot for weapon-based defensive synergy.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.MONK:
			return [
				_make_inert("monk_flurry_mastery", "Flurry Mastery", "Supports faster and more damaging unarmed chains.", 3, 3, hero_subclass),
				_make_inert("monk_centered_breath", "Centered Breath", "Groundwork slot for focus and recovery synergy.", 3, 3, hero_subclass),
			]
	return []

static func _make(id: String, name: String, description: String, max_points: int, tier: int, required_subclass: int = ConstantsData.HeroSubclass.NONE) -> TalentInfo:
	var info: TalentInfo = TalentInfo.new()
	info.id = id
	info.name = name
	info.description = description
	info.max_points = max_points
	info.tier = tier
	info.required_subclass = required_subclass
	return info


static func _make_inert(id: String, name: String, description: String, max_points: int, tier: int, required_subclass: int = ConstantsData.HeroSubclass.NONE) -> TalentInfo:
	var info: TalentInfo = _make(id, name, description, max_points, tier, required_subclass)
	info.implemented = false
	return info
