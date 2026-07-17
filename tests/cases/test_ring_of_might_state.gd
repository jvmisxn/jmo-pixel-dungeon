extends RefCounted
## Ring of Might must behave as a removable STR/HP modifier and must never bake
## its bonus into the hero's persisted base stats. Covers:
##   - equip applies the bonus, unequip fully removes it
##   - serialize stores CLEAN base stats (bonus excluded, buff not persisted)
##   - deserialize rebuilds the passive so a reload is idempotent (no double count)
##   - the v1 -> v2 save migration un-bakes bonuses from pre-fix saves

const HERO_SCRIPT: String = "res://src/actors/hero/hero.gd"

const BASE_STR: int = 13
const BASE_HP: int = 25
const RING_LEVEL: int = 2

func run(t: Object) -> void:
	_check_equip_unequip(t)
	_check_save_load_idempotent(t)
	_check_clean_base_persisted(t)
	_check_v1_migration(t)

func _make_hero() -> Object:
	var hero_script: GDScript = load(HERO_SCRIPT) as GDScript
	var hero: Object = hero_script.new()
	hero.hp = BASE_HP
	hero.hp_max = BASE_HP
	hero.ht = BASE_HP
	hero.str_val = BASE_STR
	return hero

func _make_might_ring(ring_level: int) -> Object:
	var ring: Object = Generator.create_item("ring_of_might")
	ring.level = ring_level
	ring.cursed = false
	return ring

func _expected_hp_bonus(base_ht: int, bonus: int) -> int:
	var multiplier: float = pow(1.035, float(maxi(0, bonus)))
	return maxi(0, int(float(base_ht) * multiplier) - base_ht)

func _check_equip_unequip(t: Object) -> void:
	var hero: Object = _make_hero()
	var hp_bonus: int = _expected_hp_bonus(BASE_HP, RING_LEVEL)

	hero.belongings.equip_ring(_make_might_ring(RING_LEVEL), true)
	t.check(hero.str_val == BASE_STR + RING_LEVEL, "equip adds STR bonus")
	t.check(hero.hp_max == BASE_HP + hp_bonus, "equip adds max-HP bonus")
	t.check(hero.ht == BASE_HP + hp_bonus, "equip adds HT bonus")

	hero.belongings.unequip("ring_left")
	t.check(hero.str_val == BASE_STR, "unequip restores base STR")
	t.check(hero.hp_max == BASE_HP, "unequip restores base max-HP")
	t.check(hero.ht == BASE_HP, "unequip restores base HT")

	hero.free()

func _check_save_load_idempotent(t: Object) -> void:
	var hero: Object = _make_hero()
	hero.belongings.equip_ring(_make_might_ring(RING_LEVEL), true)
	var equipped_str: int = hero.str_val
	var equipped_hp_max: int = hero.hp_max
	var equipped_ht: int = hero.ht

	# First save/load cycle: the reload must match the live equipped values,
	# not double-count the bonus.
	var data: Dictionary = hero.serialize()
	hero.free()
	var reloaded: Object = (load(HERO_SCRIPT) as GDScript).new()
	reloaded.deserialize(data)
	t.check(reloaded.str_val == equipped_str, "reload preserves equipped STR (no double count)")
	t.check(reloaded.hp_max == equipped_hp_max, "reload preserves equipped max-HP")
	t.check(reloaded.ht == equipped_ht, "reload preserves equipped HT")

	# Second cycle: still stable (idempotent, no drift).
	var data2: Dictionary = reloaded.serialize()
	var reloaded2: Object = (load(HERO_SCRIPT) as GDScript).new()
	reloaded2.deserialize(data2)
	t.check(reloaded2.str_val == equipped_str, "second reload keeps STR stable")
	t.check(reloaded2.hp_max == equipped_hp_max, "second reload keeps max-HP stable")

	# Unequip after a reload must still remove the bonus cleanly.
	reloaded2.belongings.unequip("ring_left")
	t.check(reloaded2.str_val == BASE_STR, "unequip after reload removes STR bonus")
	t.check(reloaded2.hp_max == BASE_HP, "unequip after reload removes max-HP bonus")

	reloaded.free()
	reloaded2.free()

func _check_clean_base_persisted(t: Object) -> void:
	var hero: Object = _make_hero()
	hero.belongings.equip_ring(_make_might_ring(RING_LEVEL), true)
	var data: Dictionary = hero.serialize()

	t.check(int(data.get("str_val", -1)) == BASE_STR, "serialized base STR excludes ring bonus")
	t.check(int(data.get("ht", -1)) == BASE_HP, "serialized base HT excludes ring bonus")
	t.check(int(data.get("hp_max", -1)) == BASE_HP, "serialized base max-HP excludes ring bonus")

	var persisted_might: bool = false
	for entry: Variant in data.get("buffs", []):
		if entry is Dictionary and str((entry as Dictionary).get("buff_id", "")) == "RingOfMight":
			persisted_might = true
	t.check(not persisted_might, "Ring of Might buff is not persisted")

	hero.free()

func _check_v1_migration(t: Object) -> void:
	var hp_bonus: int = _expected_hp_bonus(BASE_HP, RING_LEVEL)
	var inflated_ht: int = BASE_HP + hp_bonus
	# A pre-fix (v1) hero: base stats inflated in place + a persisted Might buff.
	var hero_data: Dictionary = {
		"str_val": BASE_STR + RING_LEVEL,
		"hp_max": inflated_ht,
		"ht": inflated_ht,
		"hp": inflated_ht,
		"buffs": [
			{"buff_id": "RingOfMight", "_script_path": "res://src/items/rings/ring.gd"},
			{"buff_id": "SomethingElse", "_script_path": "res://src/items/rings/ring.gd"},
		],
		"belongings": {
			"ring_left": {"item_id": "ring_of_might", "level": RING_LEVEL, "cursed": false},
		},
	}
	var save: Dictionary = {"save_version": 1, "hero": hero_data, "heroes": []}

	var migrated: Dictionary = SaveManager._migrate_save(save, 1)
	var mh: Dictionary = migrated.get("hero", {})
	t.check(int(mh.get("str_val", -1)) == BASE_STR, "migration un-bakes STR to clean base")
	t.check(int(mh.get("ht", -1)) == BASE_HP, "migration un-bakes HT to clean base")
	t.check(int(mh.get("hp_max", -1)) == BASE_HP, "migration un-bakes max-HP to clean base")

	var still_has_might: bool = false
	var kept_other: bool = false
	for entry: Variant in mh.get("buffs", []):
		if entry is Dictionary:
			var bid: String = str((entry as Dictionary).get("buff_id", ""))
			if bid == "RingOfMight":
				still_has_might = true
			elif bid == "SomethingElse":
				kept_other = true
	t.check(not still_has_might, "migration strips the persisted Might buff")
	t.check(kept_other, "migration keeps unrelated buffs")
	t.check(int(migrated.get("save_version", 0)) == SaveManager.SAVE_VERSION, "migration bumps save version")
