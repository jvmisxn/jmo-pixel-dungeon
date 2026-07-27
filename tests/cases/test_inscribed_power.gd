extends RefCounted
## Mage Inscribed Power (T2, upstream Talent.onScrollUsed + Wand.buffedLvl +
## Wand.wandUsed): reading a scroll attaches ScrollEmpower for 1+points (2/3)
## empowered wand zaps; while live, zaps roll damage at +2 effective wand
## levels; each zap (Wand.zap) consumes one use and the buff detaches at 0.
## Upstream reset() never lowers the remaining count on re-read.
## Port adaptation: like Desperate Power, the +2 applies to bolt damage rolls
## only (inner wand classes read raw level for durations/gas strength).

class _LevelWand extends Wand.WandOfMagicMissile:
	func get_damage(lvl: int) -> Array[int]:
		return [10 + lvl, 10 + lvl] as Array[int]

func run(t: Object) -> void:
	_test_registry(t)
	_test_scroll_read_attaches_buff(t)
	_test_no_talent_or_wrong_class_no_buff(t)
	_test_damage_bonus_and_consumption(t)
	_test_reread_keeps_higher_count(t)
	_test_serialize_round_trip(t)

func _make_mage(points: int = 0) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_inscribed_power"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: Variant = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_inscribed_power")
	t.check(info != null and info.implemented,
		"Inscribed Power is registered and implemented")
	if info != null:
		t.check(info.tier == 2 and info.max_points == 2,
			"Inscribed Power is T2 with 2 max points")

func _test_scroll_read_attaches_buff(t: Object) -> void:
	for points: int in [1, 2]:
		var hero := _make_mage(points)
		hero.on_scroll_read()
		var empower: Variant = hero.get_buff("ScrollEmpower")
		t.check(empower != null, "+%d scroll read attaches ScrollEmpower" % points)
		if empower != null:
			t.check(empower.zaps_left == 1 + points,
				"+%d grants %d empowered zaps, got %d"
				% [points, 1 + points, empower.zaps_left])
		hero.free()

func _test_no_talent_or_wrong_class_no_buff(t: Object) -> void:
	var mage := _make_mage(0)
	mage.on_scroll_read()
	t.check(not mage.has_buff("ScrollEmpower"),
		"Mage without the talent gets no ScrollEmpower")
	mage.free()
	var rogue := Hero.new()
	rogue.init_class(ConstantsData.HeroClass.ROGUE)
	rogue.talent_levels["mage_inscribed_power"] = 2
	rogue.on_scroll_read()
	t.check(not rogue.has_buff("ScrollEmpower"),
		"Non-Mage never gains ScrollEmpower from scroll reads")
	rogue.free()

func _test_damage_bonus_and_consumption(t: Object) -> void:
	var hero := _make_mage(1)
	hero.on_scroll_read()
	var wand := _LevelWand.new()
	t.check(wand.roll_zap_damage(hero) == 12,
		"Empowered damage roll uses level+2 (10+0+2)")
	# Wand.zap consumes one use per zap; simulate the wandUsed tail directly.
	wand._scroll_empower_use(hero)
	t.check(hero.get_buff("ScrollEmpower").zaps_left == 1,
		"First zap consumes one empowered use")
	wand._scroll_empower_use(hero)
	t.check(not hero.has_buff("ScrollEmpower"),
		"Buff detaches after its last empowered zap")
	t.check(wand.roll_zap_damage(hero) == 10,
		"Damage roll returns to raw level once the buff is gone")
	hero.free()

func _test_reread_keeps_higher_count(t: Object) -> void:
	var hero := _make_mage(2)
	hero.on_scroll_read()
	var wand := _LevelWand.new()
	wand._scroll_empower_use(hero)
	t.check(hero.get_buff("ScrollEmpower").zaps_left == 2,
		"Setup: 3 uses minus one zap leaves 2")
	hero.talent_levels["mage_inscribed_power"] = 1
	hero.on_scroll_read()
	t.check(hero.get_buff("ScrollEmpower").zaps_left == 2,
		"Re-read at +1 (2 uses) never lowers the remaining count")
	hero.talent_levels["mage_inscribed_power"] = 2
	hero.on_scroll_read()
	t.check(hero.get_buff("ScrollEmpower").zaps_left == 3,
		"Re-read at +2 raises the count back to 3")
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var empower := ScrollEmpower.new()
	empower.reset(3)
	var data: Dictionary = empower.serialize()
	var restored := ScrollEmpower.new()
	restored.deserialize(data)
	t.check(restored.zaps_left == 3,
		"zaps_left survives a serialize round trip")
	t.check(str(data.get("_script_path", "")).ends_with("scroll_empower.gd"),
		"Serialized buff records its script path for generic restore")
	empower.free()
	restored.free()
