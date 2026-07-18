extends RefCounted
## Cape of Thorns must be wired into the hero damage pipeline. Covers:
##   - taking a hit charges the artifact even when it is not activated
##   - an un-activated cape does NOT reduce incoming damage
##   - an activated (shielded) cape absorbs 50% of the blow
##   - the absorbed amount is reflected back onto a living attacker

const HERO_SCRIPT: String = "res://src/actors/hero/hero.gd"

func run(t: Object) -> void:
	_check_charges_from_hits(t)
	_check_shield_absorbs_and_reflects(t)

func _make_hero() -> Object:
	var hero_script: GDScript = load(HERO_SCRIPT) as GDScript
	var hero: Object = hero_script.new()
	hero.hp = 100
	hero.hp_max = 100
	hero.ht = 100
	return hero

func _equip_cape(hero: Object) -> Object:
	var cape: Object = Generator.create_item("cape_of_thorns")
	hero.belongings.equip_artifact(cape)
	return cape

func _check_charges_from_hits(t: Object) -> void:
	var hero: Object = _make_hero()
	var cape: Object = _equip_cape(hero)
	cape.charge = 0

	var taken: int = hero.take_damage(20, "trap")
	t.check(taken == 20, "un-activated cape does not reduce damage")
	t.check(hero.hp == 80, "full damage lands with no active shield")
	t.check(cape.charge > 0, "taking a hit charges the Cape of Thorns")

	hero.free()

func _check_shield_absorbs_and_reflects(t: Object) -> void:
	var hero: Object = _make_hero()
	var cape: Object = _equip_cape(hero)

	# Fully charge and activate the shield.
	cape.charge = cape.charge_max
	t.check(cape.activate(hero), "cape activates when fully charged")
	t.check(cape.activated and cape.shield_turns > 0, "activation raises the shield")

	var attacker: Char = Char.new()
	attacker.name = "Thorn victim"
	attacker.hp = 50
	attacker.hp_max = 50
	attacker.ht = 50

	var taken: int = hero.take_damage(20, attacker)
	t.check(taken == 10, "active cape absorbs 50% of the blow")
	t.check(hero.hp == 90, "only the reduced damage reaches the hero")
	t.check(attacker.hp == 40, "absorbed damage is reflected onto the attacker")

	attacker.free()
	hero.free()
