class_name CurseGlyph
extends RefCounted
## Factory for armor curse glyphs, matching upstream SPD `items/armor/curses/`.
## Curse glyphs use flat proc chances (no armor-level scaling) and mark the
## armor as weakly cursed. Each glyph separates its RNG roll (`proc`) from its
## effect (`activate`) so headless tests can drive effects deterministically.

const CURSE_IDS: Array[String] = [
	"anti_entropy", "corrosion", "displacement", "metabolism",
	"multiplicity", "stench", "overgrowth", "bulk",
]


static func create(glyph_id_str: String) -> ArmorGlyph:
	var g: ArmorGlyph = null
	match glyph_id_str:
		"anti_entropy":
			g = AntiEntropyCurse.new()
			g.glyph_name = "Anti-Entropy"
		"corrosion":
			g = CorrosionCurse.new()
			g.glyph_name = "Corrosion"
		"displacement":
			g = DisplacementCurse.new()
			g.glyph_name = "Displacement"
		"metabolism":
			g = MetabolismCurse.new()
			g.glyph_name = "Metabolism"
		"multiplicity":
			g = MultiplicityCurse.new()
			g.glyph_name = "Multiplicity"
		"stench":
			g = StenchCurse.new()
			g.glyph_name = "Stench"
		"overgrowth":
			g = OvergrowthCurse.new()
			g.glyph_name = "Overgrowth"
		"bulk":
			g = BulkCurse.new()
			g.glyph_name = "Bulk"
	if g != null:
		g.glyph_id = glyph_id_str
		g.is_curse = true
		g.color = Color(0.1, 0.1, 0.1, 1.0)
	return g


## Random curse glyph, uniform across the 8 like upstream Glyph.randomCurse().
static func random_curse() -> ArmorGlyph:
	return create(CURSE_IDS[randi() % CURSE_IDS.size()])


static func _level_of(target: Variant) -> Variant:
	if target is Object and target.get("level") != null:
		return target.level
	return null


static func _neighbour_cells(pos: int, include_center: bool) -> Array[int]:
	var cells: Array[int] = []
	var cx: int = ConstantsData.pos_to_x(pos)
	var cy: int = ConstantsData.pos_to_y(pos)
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx == 0 and dy == 0 and not include_center:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or ny < 0 or nx >= ConstantsData.WIDTH or ny >= ConstantsData.HEIGHT:
				continue
			cells.append(ConstantsData.xy_to_pos(nx, ny))
	return cells


# --- Anti-Entropy -----------------------------------------------------------
# Upstream AntiEntropy.java: 1/8 chance; Freezing on the 8 neighbour cells,
# wearer set on fire (unless in water).

class AntiEntropyCurse extends ArmorGlyph:
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 8.0:
			activate(armor, attacker, defender)
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> void:
		var level_ref: Variant = CurseGlyph._level_of(defender)
		var def_pos: int = defender.get("pos") if defender is Object else -1
		if level_ref != null and def_pos >= 0:
			for cell: int in CurseGlyph._neighbour_cells(def_pos, false):
				var ch: Variant = level_ref.find_char_at(cell) if level_ref.has_method("find_char_at") else null
				if ch != null and ch.has_method("add_buff") and not ch.has_buff("Frozen"):
					ch.add_buff(Frozen.new())
			var in_water: bool = false
			if level_ref.has_method("get_terrain"):
				in_water = level_ref.get_terrain(def_pos) == ConstantsData.Terrain.WATER
			if not in_water and defender.has_method("add_buff") and not defender.has_buff("Burning"):
				defender.add_buff(Burning.new())
		if MessageLog:
			MessageLog.add_warning("Your armor flares with anti-entropic energy!")
		ArmorGlyph._emit_glyph_proc("anti_entropy", defender, attacker)


# --- Corrosion --------------------------------------------------------------
# Upstream Corrosion.java: 1/10 chance; caustic ooze (DURATION/2) on every
# char in the 3x3 area around the wearer.

class CorrosionCurse extends ArmorGlyph:
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 10.0:
			activate(armor, attacker, defender)
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> void:
		var level_ref: Variant = CurseGlyph._level_of(defender)
		var def_pos: int = defender.get("pos") if defender is Object else -1
		if level_ref != null and def_pos >= 0:
			for cell: int in CurseGlyph._neighbour_cells(def_pos, true):
				var ch: Variant = level_ref.find_char_at(cell) if level_ref.has_method("find_char_at") else null
				if ch == null and cell == def_pos:
					ch = defender
				if ch != null and ch.has_method("add_buff"):
					var existing: Variant = ch.get_buff("Ooze") if ch.has_method("get_buff") else null
					if existing != null:
						existing.set_duration_value(Ooze.DURATION / 2.0)
					else:
						var ooze: Ooze = Ooze.new()
						ooze.set_duration_value(Ooze.DURATION / 2.0)
						ch.add_buff(ooze)
		if MessageLog:
			MessageLog.add_warning("Caustic ooze splashes from your armor!")
		ArmorGlyph._emit_glyph_proc("corrosion", defender, attacker)


# --- Displacement -----------------------------------------------------------
# Upstream Displacement.java: 1/20 chance; teleports the wearer to a random
# free passable cell and negates the hit (returns 0 damage).

class DisplacementCurse extends ArmorGlyph:
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 20.0:
			if activate(armor, attacker, defender):
				return 0
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> bool:
		var level_ref: Variant = CurseGlyph._level_of(defender)
		if level_ref == null or not level_ref.has_method("is_passable"):
			return false
		var new_pos: int = -1
		for _attempt: int in 100:
			var candidate: int = randi() % ConstantsData.LENGTH
			if level_ref.is_passable(candidate) and level_ref.find_char_at(candidate) == null:
				new_pos = candidate
				break
		if new_pos < 0:
			return false
		defender.pos = new_pos
		if EventBus and defender.get("is_hero") == true:
			EventBus.hero_moved_detailed.emit(defender, new_pos)
		if MessageLog:
			MessageLog.add_warning("Your armor teleports you away!")
		ArmorGlyph._emit_glyph_proc("displacement", defender, attacker)
		return true


# --- Metabolism -------------------------------------------------------------
# Upstream Metabolism.java: 1/6 chance; heals the hero up to STARVING/100 HP
# at 10 hunger per HP, only while not starving.

class MetabolismCurse extends ArmorGlyph:
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 6.0:
			activate(armor, attacker, defender)
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> void:
		if defender == null or defender.get("is_hero") != true:
			return
		var hunger: Variant = defender.get_buff("Hunger") if defender.has_method("get_buff") else null
		if hunger == null or (hunger.has_method("is_starving") and hunger.is_starving()):
			return
		var healing: int = mini(int(Hunger.STARVING_THRESHOLD / 100.0), defender.ht - defender.hp)
		if healing <= 0:
			return
		if hunger.has_method("satisfy"):
			hunger.satisfy(-healing * 10.0)
		defender.hp += healing
		if MessageLog:
			MessageLog.add_warning("Your armor consumes your energy to heal %d HP." % healing)
		ArmorGlyph._emit_glyph_proc("metabolism", defender, attacker)


# --- Multiplicity -----------------------------------------------------------
# Upstream Multiplicity.java: 1/20 chance; spawns either a mirror image of the
# hero wearer (50%) or a duplicate of the attacking mob on a free adjacent cell.

class MultiplicityCurse extends ArmorGlyph:
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 20.0:
			activate(armor, attacker, defender)
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> void:
		var level_ref: Variant = CurseGlyph._level_of(defender)
		var def_pos: int = defender.get("pos") if defender is Object else -1
		if level_ref == null or def_pos < 0:
			return
		var spawn_points: Array[int] = []
		for cell: int in CurseGlyph._neighbour_cells(def_pos, false):
			if level_ref.is_passable(cell) and level_ref.find_char_at(cell) == null:
				spawn_points.append(cell)
		if spawn_points.is_empty():
			return
		var cell: int = spawn_points[randi() % spawn_points.size()]
		if randi() % 2 == 0 and defender.get("is_hero") == true:
			var image_script: GDScript = load("res://src/actors/mobs/special/mirror_image.gd")
			if image_script == null:
				return
			var image: Variant = image_script.new()
			image.pos = cell
			image.level = level_ref
			if image.has_method("setup_from_hero"):
				image.setup_from_hero(defender)
			level_ref.add_mob(image)
			if TurnManager:
				TurnManager.add_actor(image)
		else:
			var dup_id: String = ""
			if attacker is Object and attacker.get("mob_id") != null:
				var is_special: bool = false
				if attacker.has_method("is_boss"):
					is_special = attacker.is_boss()
				if not is_special:
					dup_id = str(attacker.mob_id)
			if dup_id == "" or dup_id == "mob":
				return
			level_ref.spawn_mob(dup_id, cell)
		if MessageLog:
			MessageLog.add_warning("Your armor's curse duplicates a nearby being!")
		ArmorGlyph._emit_glyph_proc("multiplicity", defender, attacker)


# --- Stench -----------------------------------------------------------------
# Upstream Stench.java: 1/8 chance; seeds 250 toxic gas at the wearer's cell.

class StenchCurse extends ArmorGlyph:
	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 8.0:
			activate(armor, attacker, defender)
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> void:
		var level_ref: Variant = CurseGlyph._level_of(defender)
		var def_pos: int = defender.get("pos") if defender is Object else -1
		if level_ref == null or def_pos < 0 or not level_ref.has_method("add_blob"):
			return
		level_ref.add_blob(ToxicGas.new(), def_pos, 250.0)
		if MessageLog:
			MessageLog.add_warning("Toxic gas billows from your armor!")
		ArmorGlyph._emit_glyph_proc("stench", defender, attacker)


# --- Overgrowth -------------------------------------------------------------
# Upstream Overgrowth.java: 1/20 chance; a random plant grows at the wearer's
# cell and activates on them immediately.

class OvergrowthCurse extends ArmorGlyph:
	const PLANT_TYPES: Array[String] = [
		"sungrass", "earthroot", "fadeleaf", "firebloom", "icecap",
		"sorrowmoss", "stormvine", "dreamfoil", "rotberry", "blindweed",
		"starflower", "swiftthistle",
	]

	func proc(armor: Variant, attacker: Variant, defender: Variant, damage: int) -> int:
		if randf() < 1.0 / 20.0:
			activate(armor, attacker, defender)
		return damage

	func activate(_armor: Variant, attacker: Variant, defender: Variant) -> void:
		var level_ref: Variant = CurseGlyph._level_of(defender)
		var def_pos: int = defender.get("pos") if defender is Object else -1
		if level_ref == null or def_pos < 0:
			return
		var seed_item: SeedItem = SeedItem.create("seed_of_" + PLANT_TYPES[randi() % PLANT_TYPES.size()])
		var plant: Plant = seed_item._create_plant()
		if plant == null:
			return
		plant.pos = def_pos
		plant.activate(defender, level_ref)
		if MessageLog:
			MessageLog.add_warning("A %s bursts from under your armor!" % plant.plant_name)
		ArmorGlyph._emit_glyph_proc("overgrowth", defender, attacker)


# --- Bulk -------------------------------------------------------------------
# Upstream Bulk.java: no proc effect; the wearer moves at 1/3 speed while
# standing in a doorway (checked from Armor.speed_factor).

class BulkCurse extends ArmorGlyph:
	func proc(_armor: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
		return damage

	static func speed_multiplier(level_ref: Variant, pos: int) -> float:
		if level_ref == null or pos < 0 or not level_ref.has_method("get_terrain"):
			return 1.0
		var terrain: int = level_ref.get_terrain(pos)
		if terrain == ConstantsData.Terrain.DOOR or terrain == ConstantsData.Terrain.OPEN_DOOR:
			return 1.0 / 3.0
		return 1.0
