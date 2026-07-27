class_name HeroClassData
extends RefCounted
## Static data for each hero class: starting stats, items, and descriptions.

## Starting stats structure.
class StartingStats:
	var hp: int = 20
	var str_val: int = 10
	var attack_skill: int = 10
	var defense_skill: int = 5
	var damage_min: int = 1
	var damage_max: int = 5

static func get_starting_stats(hero_class: int) -> StartingStats:
	var s: StartingStats = StartingStats.new()
	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			s.hp = 20
			s.str_val = 10
			s.attack_skill = 11
			s.defense_skill = 5
			s.damage_min = 1
			s.damage_max = 8
		ConstantsData.HeroClass.MAGE:
			s.hp = 20
			s.str_val = 10
			s.attack_skill = 10
			s.defense_skill = 4
			s.damage_min = 1
			s.damage_max = 6
		ConstantsData.HeroClass.ROGUE:
			s.hp = 20
			s.str_val = 10
			s.attack_skill = 12
			s.defense_skill = 6
			s.damage_min = 1
			s.damage_max = 6
		ConstantsData.HeroClass.HUNTRESS:
			s.hp = 20
			s.str_val = 10
			s.attack_skill = 11
			s.defense_skill = 5
			s.damage_min = 1
			s.damage_max = 6
		ConstantsData.HeroClass.DUELIST:
			s.hp = 20
			s.str_val = 10
			s.attack_skill = 12
			s.defense_skill = 5
			s.damage_min = 1
			s.damage_max = 7
	return s

static func get_class_name_str(hero_class: int) -> String:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR: return "Warrior"
		ConstantsData.HeroClass.MAGE: return "Mage"
		ConstantsData.HeroClass.ROGUE: return "Rogue"
		ConstantsData.HeroClass.HUNTRESS: return "Huntress"
		ConstantsData.HeroClass.DUELIST: return "Duelist"
	return "Unknown"

static func get_class_description(hero_class: int) -> String:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			return "The Warrior starts with a worn shortsword and a unique broken seal. When a hit leaves him at or below half health, the seal grants a burst of shielding. The seal can be moved between armors."
		ConstantsData.HeroClass.MAGE:
			return "The Mage starts with a staff that can be imbued with wand effects. Wands recharge faster for the Mage, and he can use them as melee weapons."
		ConstantsData.HeroClass.ROGUE:
			return "The Rogue starts with a dagger and a unique cloak of shadows, which he can use to become invisible at will. He detects secrets and traps from a greater distance."
		ConstantsData.HeroClass.HUNTRESS:
			return "The Huntress starts with a spirit bow and has a natural affinity for thrown weapons. She can see further than other classes and has an innate bonus to her ranged attacks."
		ConstantsData.HeroClass.DUELIST:
			return "The Duelist starts with a rapier and excels at melee combat. Each weapon type grants her a unique ability that she can use to gain an edge in battle."
	return ""

## Returns the perk descriptions for the hero select screen.
static func get_perks(hero_class: int) -> Array[String]:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			return [
				"Starts with a worn shortsword and broken seal",
				"Seal grants a shield burst when dropped to half health",
				"Seal can be moved between armors",
				"Highest starting damage of any class",
			]
		ConstantsData.HeroClass.MAGE:
			return [
				"Starts with the Mage's Staff, imbued with Magic Missile",
				"Staff recharges faster than a normal wand",
				"Staff can be imbued with any wand found",
				"Starts with a scroll of identify",
			]
		ConstantsData.HeroClass.ROGUE:
			return [
				"Starts with a dagger and cloak of shadows",
				"Cloak of Shadows grants invisibility at will",
				"Detects traps and secret doors from further away",
				"Highest starting accuracy and evasion",
			]
		ConstantsData.HeroClass.HUNTRESS:
			return [
				"Starts with a spirit bow and studded gloves",
				"Natural bonus to thrown weapon damage",
				"Increased sight range (+2 tiles)",
				"Spirit bow conjures infinite arrows",
			]
		ConstantsData.HeroClass.DUELIST:
			return [
				"Starts with a rapier",
				"Each weapon grants a unique ability",
				"Gains bonus damage after dodging",
				"Weapon abilities charge faster with successive hits",
			]
	return []

## Returns the display name for a subclass.
static func get_subclass_name(subclass: int) -> String:
	match subclass:
		ConstantsData.HeroSubclass.BERSERKER: return "Berserker"
		ConstantsData.HeroSubclass.GLADIATOR: return "Gladiator"
		ConstantsData.HeroSubclass.BATTLEMAGE: return "Battlemage"
		ConstantsData.HeroSubclass.WARLOCK: return "Warlock"
		ConstantsData.HeroSubclass.ASSASSIN: return "Assassin"
		ConstantsData.HeroSubclass.FREERUNNER: return "Freerunner"
		ConstantsData.HeroSubclass.SNIPER: return "Sniper"
		ConstantsData.HeroSubclass.WARDEN: return "Warden"
		ConstantsData.HeroSubclass.CHAMPION: return "Champion"
		ConstantsData.HeroSubclass.MONK: return "Monk"
	return "None"

## Returns a short description for a subclass.
static func get_subclass_description(subclass: int) -> String:
	var info: SubclassAbilities.SubclassInfo = SubclassAbilities.get_subclass_info(subclass)
	return info.description
