class_name MobFactory
extends RefCounted
## Creates mob instances appropriate for a given dungeon depth.
## Used by level generation to populate floors with enemies.

## Mob spawn table entry: {mob_class: String, weight: float}
## Weight determines relative spawn probability.

static func get_mob_table(depth: int) -> Array[Dictionary]:
	var region: int = ConstantsData.region_for_depth(depth)
	match region:
		ConstantsData.Region.SEWERS:
			return _sewer_table(depth)
		ConstantsData.Region.PRISON:
			return _prison_table(depth)
		ConstantsData.Region.CAVES:
			return _caves_table(depth)
		ConstantsData.Region.CITY:
			return _city_table(depth)
		ConstantsData.Region.HALLS:
			return _halls_table(depth)
	return []

static func _sewer_table(depth: int) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	table.append({"mob_id": "rat", "weight": 4.0 - depth * 0.5})
	if depth >= 2:
		table.append({"mob_id": "gnoll", "weight": 2.0})
	if depth >= 3:
		table.append({"mob_id": "snake", "weight": 1.5})
		table.append({"mob_id": "crab", "weight": 1.5})
		table.append({"mob_id": "swarm", "weight": 1.0})
	if depth >= 4:
		table.append({"mob_id": "slime", "weight": 1.0})
		table.append({"mob_id": "gnoll_trickster", "weight": 0.5})
	# Remove non-positive weights
	var filtered: Array[Dictionary] = []
	for entry: Dictionary in table:
		if entry["weight"] > 0:
			filtered.append(entry)
	return filtered

static func _prison_table(depth: int) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	table.append({"mob_id": "skeleton", "weight": 3.0})
	table.append({"mob_id": "thief", "weight": 2.0})
	if depth >= 7:
		table.append({"mob_id": "guard", "weight": 2.0})
		table.append({"mob_id": "bandit", "weight": 1.0})
	if depth >= 8:
		table.append({"mob_id": "necromancer", "weight": 1.5})
	return table

static func _caves_table(depth: int) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	table.append({"mob_id": "bat", "weight": 3.0})
	table.append({"mob_id": "brute", "weight": 2.0})
	if depth >= 11:
		table.append({"mob_id": "dm100", "weight": 1.5})
	if depth >= 12:
		table.append({"mob_id": "shaman", "weight": 2.0})
		table.append({"mob_id": "spinner", "weight": 1.5})
	if depth >= 13:
		table.append({"mob_id": "dm200", "weight": 1.5})
	if depth >= 14:
		table.append({"mob_id": "dm201", "weight": 0.8})
	return table

static func _city_table(depth: int) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	table.append({"mob_id": "warlock", "weight": 2.5})
	table.append({"mob_id": "monk", "weight": 2.5})
	if depth >= 17:
		table.append({"mob_id": "golem", "weight": 2.0})
	if depth >= 18:
		table.append({"mob_id": "elemental", "weight": 1.5})
	return table

static func _halls_table(_depth: int) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	table.append({"mob_id": "succubus", "weight": 2.0})
	table.append({"mob_id": "eye", "weight": 2.0})
	table.append({"mob_id": "scorpio", "weight": 2.0})
	table.append({"mob_id": "ripper", "weight": 2.0})
	return table

## Create a mob instance by ID.
static func create_mob(mob_id: String) -> Mob:
	match mob_id:
		# Sewer mobs
		"rat": return Rat.new()
		"gnoll": return Gnoll.new()
		"crab": return Crab.new()
		"snake": return Snake.new()
		"slime": return Slime.new()
		"swarm": return Swarm.new()
		"gnoll_trickster": return GnollTrickster.new()
		"great_crab": return GreatCrab.new()
		# Prison mobs
		"skeleton": return Skeleton.new()
		"thief": return Thief.new()
		"guard": return Guard.new()
		"necromancer": return Necromancer.new()
		"bandit": return Bandit.new()
		# Caves mobs
		"bat": return Bat.new()
		"brute": return Brute.new()
		"shaman": return Shaman.new()
		"spinner": return Spinner.new()
		"dm100": return DM100.new()
		"dm200": return DM200.new()
		"dm201": return DM201.new()
		# City mobs
		"warlock": return Warlock.new()
		"monk": return MonkMob.new()
		"golem": return Golem.new()
		"elemental": return Elemental.new()
		# Halls mobs
		"succubus": return Succubus.new()
		"eye": return Eye.new()
		"scorpio": return Scorpio.new()
		"ripper": return Ripper.new()
		# Special mobs
		"piranha": return Piranha.new()
		"mimic": return Mimic.new()
		"animated_statue": return AnimatedStatue.new()
		"golden_statue": return GoldenStatue.new()
		"wraith": return Wraith.new()
		"bee": return Bee.new()
		# Bosses
		"goo": return Goo.new()
		"tengu": return Tengu.new()
		"dm300": return DM300.new()
		"king": return DwarfKing.new()
		"yog": return Yog.new()
	push_warning("MobFactory: Unknown mob_id '%s'" % mob_id)
	return Mob.new()

## Spawn a random mob appropriate for the given depth.
static func create_random_mob(depth: int) -> Mob:
	var table: Array[Dictionary] = get_mob_table(depth)
	if table.is_empty():
		return Rat.new()

	# Weighted random selection
	var total_weight: float = 0.0
	for entry: Dictionary in table:
		total_weight += entry["weight"]

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for entry: Dictionary in table:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return create_mob(entry["mob_id"])

	return create_mob(table[0]["mob_id"])

## Create the boss for a given boss depth.
static func create_boss(depth: int) -> Mob:
	match depth:
		5: return Goo.new()
		10: return Tengu.new()
		15: return DM300.new()
		20: return DwarfKing.new()
		25: return Yog.new()
	return Mob.new()
