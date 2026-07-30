extends RefCounted
## Ghoul pair + life link parity (upstream Ghoul.java / GhoulLifeLink):
## ghouls spawn a partner on their first turn, and a downed ghoul near a
## living ghoul crumples instead of dying, reviving after 5*times_downed
## host turns at 1/10 HP. With no host nearby (or when the host chain dies)
## the death sticks.

func run(t: Object) -> void:
	_test_partner_spawn(t)
	_test_no_third_ghoul(t)
	_test_downed_near_partner(t)
	_test_revive_after_countdown(t)
	_test_real_death_without_host(t)
	_test_host_death_kills_downed_ghoul(t)
	_test_second_down_takes_longer(t)
	_test_link_serialization(t)
	_test_city_table_has_ghoul(t)


func _make_level() -> Level:
	var level := Level.new()
	level.depth = 16
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level


func _make_ghoul(level: Level, ghoul_pos: int, spawned: bool = true) -> Ghoul:
	var ghoul := Ghoul.new()
	ghoul.partner_spawned = spawned
	ghoul.pos = ghoul_pos
	ghoul.level = level
	level.add_mob(ghoul)
	return ghoul


func _count_ghouls(level: Level) -> int:
	var n: int = 0
	for m: Variant in level.mobs:
		if m is Object and m.get("mob_id") == "ghoul":
			n += 1
	return n


func _get_link(host: Ghoul) -> GhoulLifeLink:
	for b: Node in host.get_buffs():
		if b is GhoulLifeLink:
			return b as GhoulLifeLink
	return null


func _test_partner_spawn(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5), false)
	ghoul._spawn_partner()
	t.check(ghoul.partner_spawned, "Spawning a partner marks the parent")
	t.check(_count_ghouls(level) == 2, "Partner ghoul added to the level")
	var partner: Ghoul = null
	for m: Variant in level.mobs:
		if m != ghoul and m is Ghoul:
			partner = m
	t.check(partner != null and partner.partner_spawned,
		"Partner is marked so pairs do not chain")
	if partner != null:
		var dist: int = GhoulLifeLink._chebyshev(ghoul.pos, partner.pos)
		t.check(dist == 1, "Partner spawns orthogonally adjacent")


func _test_no_third_ghoul(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5), false)
	ghoul._spawn_partner()
	ghoul._spawn_partner()
	t.check(_count_ghouls(level) == 2,
		"partner_spawned guard is set on success (act() skips respawn)")


func _test_downed_near_partner(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5))
	var host := _make_ghoul(level, ConstantsData.xy_to_pos(6, 5))
	ghoul.take_damage(999)
	t.check(ghoul.is_alive, "Downed ghoul is not dead")
	t.check(ghoul.downed, "Downed flag set")
	t.check(ghoul.times_downed == 1, "times_downed incremented")
	t.check(ghoul not in level.mobs, "Downed ghoul removed from level.mobs")
	var link := _get_link(host)
	t.check(link != null, "Life link attached to the nearby ghoul")
	if link != null:
		t.check(link.turns_to_revive == 5, "First down revives after 5 turns")
		t.check(link.ghoul == ghoul, "Link references the downed ghoul")


func _test_revive_after_countdown(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5))
	var host := _make_ghoul(level, ConstantsData.xy_to_pos(6, 5))
	ghoul.take_damage(999)
	for _i: int in range(5):
		host.process_buffs(1.0)
	t.check(ghoul in level.mobs, "Ghoul rejoins level.mobs after 5 host turns")
	t.check(not ghoul.downed, "Downed flag cleared on revive")
	var expected_hp: int = maxi(1, int(round(float(ghoul.hp_max) / 10.0)))
	t.check(ghoul.hp == expected_hp, "Revives at 1/10 max HP")
	t.check(_get_link(host) == null, "Resolved link removed from the host")


func _test_real_death_without_host(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5))
	ghoul.take_damage(999)
	t.check(not ghoul.is_alive, "With no nearby ghoul the death sticks")
	t.check(not ghoul.downed, "No downed state without a host")


func _test_host_death_kills_downed_ghoul(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5))
	var host := _make_ghoul(level, ConstantsData.xy_to_pos(6, 5))
	ghoul.take_damage(999)
	t.check(ghoul.is_alive and ghoul.downed, "Ghoul downed near its partner")
	host.take_damage(999)
	t.check(not host.is_alive, "Host dies with no third ghoul to catch it")
	t.check(not ghoul.is_alive,
		"Downed ghoul dies for real when its only host dies")


func _test_second_down_takes_longer(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5))
	var host := _make_ghoul(level, ConstantsData.xy_to_pos(6, 5))
	ghoul.take_damage(999)
	for _i: int in range(5):
		host.process_buffs(1.0)
	t.check(ghoul in level.mobs, "First revive happened")
	ghoul.take_damage(999)
	var link := _get_link(host)
	t.check(link != null and link.turns_to_revive == 10,
		"Second down revives after 10 turns (5*times_downed)")


func _test_link_serialization(t: Object) -> void:
	var level := _make_level()
	var ghoul := _make_ghoul(level, ConstantsData.xy_to_pos(5, 5))
	var host := _make_ghoul(level, ConstantsData.xy_to_pos(6, 5))
	ghoul.times_downed = 1
	ghoul.take_damage(999)
	var link := _get_link(host)
	t.check(link != null and link.turns_to_revive == 10,
		"Pre-serialized link counts 10 turns")
	var data: Dictionary = link.serialize()
	var restored := GhoulLifeLink.new()
	restored.deserialize(data)
	t.check(restored.turns_to_revive == 10, "turns_to_revive round-trips")
	t.check(restored.ghoul != null and restored.ghoul.get("mob_id") == "ghoul",
		"Downed ghoul rebuilt from the link bundle")
	if restored.ghoul != null:
		t.check(restored.ghoul.downed and restored.ghoul.is_alive,
			"Rebuilt ghoul is downed but alive")
		t.check(restored.ghoul.times_downed == 2,
			"Rebuilt ghoul keeps times_downed")


func _test_city_table_has_ghoul(t: Object) -> void:
	var ids16: Array = []
	for entry: Dictionary in MobFactory.get_mob_table(16):
		ids16.append(entry["mob_id"])
	t.check("ghoul" in ids16, "Depth 16 spawn table includes ghouls")
	var ids19: Array = []
	for entry: Dictionary in MobFactory.get_mob_table(19):
		ids19.append(entry["mob_id"])
	t.check("ghoul" not in ids19, "Depth 19 spawn table drops ghouls")
	t.check("golem" in ids19, "Depth 19 spawn table includes golems")
	var created: Variant = MobFactory.create_mob("ghoul")
	t.check(created is Ghoul, "MobFactory builds ghouls by id")
