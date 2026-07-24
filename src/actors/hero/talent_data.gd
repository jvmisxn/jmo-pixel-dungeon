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
				_make("warrior_tested_hypothesis", "Tested Hypothesis", "Potions of Healing and Scrolls of Identify can be recognized on pickup.", 2, 1),
				_make("warrior_iron_will", "Iron Will", "Improves the Warrior's ability to hold ground under pressure.", 3, 2),
				_make("warrior_runic_transference", "Runic Transference", "Groundwork slot for broken seal and glyph transfer behavior.", 2, 2),
			]
		ConstantsData.HeroClass.MAGE:
			return [
				_make("mage_empowering_meal", "Empowering Meal", "Eating grants a short Recharging buff for wands.", 2, 1),
				_make("mage_backup_barrier", "Backup Barrier", "Crossing below half health triggers an emergency barrier once until you recover.", 2, 1),
				_make("mage_scholars_intuition", "Scholar's Intuition", "Scrolls and wands can be identified on pickup.", 2, 2),
				_make("mage_energizing_upgrade", "Energizing Upgrade", "Groundwork slot for recharge and staff synergy mechanics.", 3, 2),
			]
		ConstantsData.HeroClass.ROGUE:
			return [
				_make("rogue_cached_rations", "Cached Rations", "Food satisfies extra hunger.", 2, 1),
				_make("rogue_thiefs_intuition", "Thief's Intuition", "Rings can be identified on pickup.", 2, 1),
				_make("rogue_sucker_punch", "Sucker Punch", "Surprise attacks deal increased damage.", 2, 2),
				_make("rogue_protective_shadows", "Protective Shadows", "While invisible, the Rogue gradually gains a protective barrier.", 2, 2),
			]
		ConstantsData.HeroClass.HUNTRESS:
			return [
				_make("huntress_natures_bounty", "Nature's Bounty", "Trampling high grass can yield dewdrops or seeds.", 2, 1),
				_make("huntress_survivalists_intuition", "Survivalist's Intuition", "Missile weapons can be identified on pickup.", 2, 1),
				_make("huntress_followup_strike", "Followup Strike", "Landing a ranged hit empowers your next melee attack.", 2, 2),
				_make("huntress_natures_aid", "Nature's Aid", "Supports defensive benefits from plant interactions.", 2, 2),
			]
		ConstantsData.HeroClass.DUELIST:
			return [
				_make("duelist_adventurers_intuition", "Adventurer's Intuition", "Weapons and armor can be identified on pickup.", 2, 1),
				_make("duelist_patient_strike", "Patient Strike", "Waiting primes your next melee attack to deal increased damage.", 2, 1),
				_make("duelist_aggressive_barrier", "Aggressive Barrier", "Supports offensive pressure with defensive conversion.", 2, 2),
				_make("duelist_weapon_recharging", "Weapon Recharging", "Groundwork slot for weapon ability cadence.", 3, 2),
			]
	return []

static func _subclass_talents(hero_subclass: int) -> Array[TalentInfo]:
	match hero_subclass:
		ConstantsData.HeroSubclass.BERSERKER:
			return [
				_make("berserker_endless_rage", "Endless Rage", "Groundwork slot for deeper low-HP damage scaling.", 3, 3, hero_subclass),
				_make("berserker_deathless_fury", "Deathless Fury", "Groundwork slot for stronger rage-based death prevention.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.GLADIATOR:
			return [
				_make("gladiator_cleave", "Cleave", "Groundwork slot for combo finishers affecting multiple enemies.", 3, 3, hero_subclass),
				_make("gladiator_combo_mastery", "Combo Mastery", "Supports longer and more reliable combo chains.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.BATTLEMAGE:
			return [
				_make("battlemage_empowered_strikes", "Empowered Strikes", "Supports stronger staff-triggered magic effects.", 3, 3, hero_subclass),
				_make("battlemage_arcane_renewal", "Arcane Renewal", "Groundwork slot for charge recovery synergies.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.WARLOCK:
			return [
				_make("warlock_soul_siphon", "Soul Siphon", "Supports more rewarding Soul Mark conversions.", 3, 3, hero_subclass),
				_make("warlock_hungry_hex", "Hungry Hex", "Groundwork slot for hunger and sustain interactions.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.ASSASSIN:
			return [
				_make("assassin_deep_preparation", "Deep Preparation", "Supports longer stealth setup and harder ambushes.", 3, 3, hero_subclass),
				_make("assassin_shadow_step", "Shadow Step", "Groundwork slot for post-ambush mobility.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.FREERUNNER:
			return [
				_make("freerunner_momentum_mastery", "Momentum Mastery", "Supports more reliable movement chains.", 3, 3, hero_subclass),
				_make("freerunner_kinetic_flow", "Kinetic Flow", "Groundwork slot for stronger speed and evasion payoff.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.SNIPER:
			return [
				_make("sniper_deadeye", "Deadeye", "Supports more punishing long-range shots.", 3, 3, hero_subclass),
				_make("sniper_snapshot_mastery", "Snapshot Mastery", "Groundwork slot for more flexible snapshot use.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.WARDEN:
			return [
				_make("warden_barkskin_mastery", "Barkskin Mastery", "Supports stronger nature-derived protection.", 3, 3, hero_subclass),
				_make("warden_overgrowth", "Overgrowth", "Groundwork slot for stronger plant and grass interactions.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.CHAMPION:
			return [
				_make("champion_dual_mastery", "Dual Mastery", "Supports more efficient dual-weapon pressure.", 3, 3, hero_subclass),
				_make("champion_guarded_offense", "Guarded Offense", "Groundwork slot for weapon-based defensive synergy.", 3, 3, hero_subclass),
			]
		ConstantsData.HeroSubclass.MONK:
			return [
				_make("monk_flurry_mastery", "Flurry Mastery", "Supports faster and more damaging unarmed chains.", 3, 3, hero_subclass),
				_make("monk_centered_breath", "Centered Breath", "Groundwork slot for focus and recovery synergy.", 3, 3, hero_subclass),
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
