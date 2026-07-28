extends RefCounted
## Fire/Frost Imbue attack procs (upstream FireImbue.java / FrostImbue.java +
## the Char.attack call site): FireImbue procs a 50% Burning reignite after
## each hit and scorches grass underfoot; FrostImbue applies 3 turns of Chill
## per hit. Both last 50 turns, grant matching immunities, and strip their
## opposing debuff on attach.

func run(t: Object) -> void:
	_test_fire_proc_ignites(t)
	_test_fire_proc_reignites_existing(t)
	_test_frost_proc_chills(t)
	_test_fire_immunity_and_dispel(t)
	_test_frost_immunity_and_dispel(t)
	_test_fire_scorches_grass(t)
	_test_durations(t)

func _make_mob(mob_hp: int = 30) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = mob_hp
	mob.hp = mob_hp
	return mob

func _test_fire_proc_ignites(t: Object) -> void:
	var mob := _make_mob()
	var imbue := FireImbue.new()
	# 50% per proc: 40 attempts miss all with p = 2^-40.
	for i: int in range(40):
		imbue.proc(mob)
	t.check(mob.has_buff("Burning"), "FireImbue.proc eventually ignites the defender")
	imbue.free()
	mob.free()

func _test_fire_proc_reignites_existing(t: Object) -> void:
	var mob := _make_mob()
	var burn := Burning.new()
	mob.add_buff(burn)
	burn.left = 1.0
	var imbue := FireImbue.new()
	for i: int in range(40):
		imbue.proc(mob)
	var refreshed := mob.get_buff("Burning") as Burning
	t.check(refreshed != null and refreshed.left == Burning.DURATION,
		"proc reignites an existing burn back to full duration")
	imbue.free()
	mob.free()

func _test_frost_proc_chills(t: Object) -> void:
	var mob := _make_mob()
	var imbue := FrostImbue.new()
	imbue.proc(mob)
	var chill := mob.get_buff("Chill") as Chill
	t.check(chill != null and chill.left == 3.0, "FrostImbue.proc applies 3 turns of Chill")
	imbue.free()
	mob.free()

func _test_fire_immunity_and_dispel(t: Object) -> void:
	var mob := _make_mob()
	mob.add_buff(Burning.new())
	mob.add_buff(FireImbue.new())
	t.check(not mob.has_buff("Burning"), "FireImbue attach strips existing Burning")
	mob.add_buff(Burning.new())
	t.check(not mob.has_buff("Burning"), "FireImbue owner is immune to Burning")
	mob.free()

func _test_frost_immunity_and_dispel(t: Object) -> void:
	var mob := _make_mob()
	var chill := Chill.new()
	chill.set_level(4.0)
	mob.add_buff(chill)
	mob.add_buff(FrostImbue.new())
	t.check(not mob.has_buff("Chill"), "FrostImbue attach strips existing Chill")
	var chill2 := Chill.new()
	chill2.set_level(4.0)
	mob.add_buff(chill2)
	t.check(not mob.has_buff("Chill"), "FrostImbue owner is immune to Chill")
	mob.free()

func _test_fire_scorches_grass(t: Object) -> void:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	var pos: int = ConstantsData.xy_to_pos(3, 3)
	level.set_terrain(pos, ConstantsData.Terrain.GRASS)
	var prev_level: Variant = GameManager.current_level
	GameManager.current_level = level
	var mob := _make_mob()
	mob.pos = pos
	var imbue := mob.add_buff(FireImbue.new())
	imbue.on_turn()
	t.check(level.terrain_at(pos) == ConstantsData.Terrain.EMBERS,
		"FireImbue scorches grass under the owner to embers")
	GameManager.current_level = prev_level
	mob.free()

func _test_durations(t: Object) -> void:
	t.check(FireImbue.BASE_DURATION == 50.0 and FrostImbue.BASE_DURATION == 50.0,
		"both imbues last upstream's 50 turns")
