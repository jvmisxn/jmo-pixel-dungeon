class_name Earthroot
extends Plant
## Grants Earthroot's stationary damage-absorbing armor. Matches upstream
## `Earthroot.activate()`: a Warden hero instead gains Barkskin(hero.lvl+5, 5),
## while everyone else gets an Armor pool sized to their max HP (`ch.HT`).

func _init() -> void:
	plant_id = "Earthroot"
	plant_name = "Earthroot"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	# SPD: Warden receives Barkskin from the natural growth rather than the
	# stationary Armor buff.
	if char is Hero and char.hero_subclass == ConstantsData.HeroSubclass.WARDEN:
		var hero_lvl: int = int(char.hero_level) if char.get("hero_level") != null else 1
		Barkskin.conditionally_append(char, hero_lvl + 5, 5)
	elif char.has_method("add_buff"):
		# SPD: Buff.affect(ch, Armor.class).level(ch.HT) — pool sized to max HP.
		var buff: HerbalArmorBuff = HerbalArmorBuff.new()
		var applied: Node = char.add_buff(buff)
		var max_hp: int = 0
		if char.get("ht") != null:
			max_hp = int(char.ht)
		elif char.get("hp_max") != null:
			max_hp = int(char.hp_max)
		if applied != null and applied.has_method("apply_pool"):
			applied.apply_pool(max_hp)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_positive("Roots emerge and wrap around you protectively.")
		else:
			MessageLog.add("Roots wrap around the %s." % str(char.get("name")))
