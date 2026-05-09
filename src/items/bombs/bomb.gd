class_name Bomb
extends Item
## Throwable explosive items. Stackable. After being thrown or placed, a fuse
## counts down for a number of turns before the bomb detonates, damaging
## characters and destroying breakable terrain in a radius.

# --- Enums ---
enum BombType { NORMAL, FIRE, FROST, HOLY, WOOLY, NOISEMAKER, FLASHBANG, SHOCK, REGROWTH, ARCANE }

# --- Properties ---
## Number of turns before detonation after being thrown/placed.
var fuse_turns: int = 2
## Blast radius in cells.
var radius: int = 1
## Minimum damage dealt at the center of the explosion.
var damage_min: int = 10
## Maximum damage dealt at the center of the explosion.
var damage_max: int = 30
## The bomb subtype, determining special detonation effects.
var bomb_type: BombType = BombType.NORMAL

func _init() -> void:
	category = ConstantsData.ItemCategory.MISC
	stackable = true
	default_action = "THROW"
	identified = true
	cursed_known = true
	icon_color = Color(0.3, 0.3, 0.3)

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

## Throw or place the bomb at a position, starting the fuse countdown.
func execute(hero: Char) -> void:
	if hero == null:
		return
	# Place bomb at the hero's current position (throw logic would use target pos)
	var target_pos: int = hero.pos if hero.get("pos") != null else 0
	if MessageLog:
		MessageLog.add("You light the %s!" % item_name)
	if EventBus:
		EventBus.item_used.emit(item_name)
	_start_fuse(target_pos, hero)
	_consume_one(hero)

## Start the fuse countdown. In a full implementation this would register with
## TurnManager to count down. For now we detonate immediately as a placeholder.
func _start_fuse(target_pos: int, hero: Char) -> void:
	# TODO: Register a delayed action with TurnManager for fuse_turns countdown.
	# For immediate gameplay testing, detonate now.
	var dungeon_level: Variant = hero.get("level") if hero != null else null
	detonate(target_pos, dungeon_level)

## Detonate the bomb at a position, dealing damage and applying effects.
func detonate(bomb_pos: int, dungeon_level: Variant) -> void:
	if MessageLog:
		MessageLog.add_negative("The %s explodes!" % item_name)

	# Gather all cells in the blast radius
	var affected_cells: Array[int] = _get_cells_in_radius(bomb_pos, radius)

	# Deal damage to all characters in the blast area
	if dungeon_level != null and dungeon_level.has_method("get_chars_at_positions"):
		var chars: Array = dungeon_level.get_chars_at_positions(affected_cells)
		for ch: Variant in chars:
			if ch != null and ch.has_method("take_damage"):
				var dmg: int = randi_range(damage_min, damage_max)
				# Distance falloff: halve damage for each cell away from center
				var dist: int = _chebyshev_distance(bomb_pos, ch.pos)
				if dist > 0:
					dmg = maxi(1, int(float(dmg) / float(dist + 1)))
				# Apply type-specific damage modifiers
				dmg = _modify_damage_for_type(dmg, ch)
				ch.take_damage(dmg, null)

	# Apply type-specific area effects
	_apply_area_effect(bomb_pos, affected_cells, dungeon_level)

	# Destroy breakable terrain
	if dungeon_level != null and dungeon_level.has_method("destroy_terrain"):
		for cell: int in affected_cells:
			dungeon_level.destroy_terrain(cell)

## Modify damage based on bomb type and target.
func _modify_damage_for_type(dmg: int, target: Variant) -> int:
	match bomb_type:
		BombType.HOLY:
			# Bonus damage vs undead (check for undead property)
			if target.get("is_undead") == true:
				dmg = int(dmg * 2.0)
		BombType.ARCANE:
			# Ignore armor: set damage directly (bypasses armor in take_damage)
			# This is handled by passing damage as-is; target armor reduction
			# is a separate concern in the combat system.
			pass
	return dmg

## Apply special area effects based on bomb type.
func _apply_area_effect(bomb_pos: int, cells: Array[int], dungeon_level: Variant) -> void:
	match bomb_type:
		BombType.FIRE:
			# Leave fire blobs in the area
			if dungeon_level != null and dungeon_level.has_method("add_blob"):
				for cell: int in cells:
					var fire: FireBlob = FireBlob.new()
					dungeon_level.add_blob(fire, cell)
			if MessageLog:
				MessageLog.add_warning("Flames engulf the area!")

		BombType.FROST:
			# Freeze characters in the area
			if dungeon_level != null and dungeon_level.has_method("get_chars_at_positions"):
				var chars: Array = dungeon_level.get_chars_at_positions(cells)
				for ch: Variant in chars:
					if ch != null and ch.has_method("add_buff"):
						var frost: Paralysis = Paralysis.new()
						frost.set_duration(5.0)
						ch.add_buff(frost)
			if MessageLog:
				MessageLog.add_info("Ice crystals spread across the area!")

		BombType.WOOLY:
			# Summon sheep that block movement at each affected cell
			var spawned: int = 0
			if dungeon_level != null:
				for cell: int in cells:
					if dungeon_level.has_method("is_passable") and not dungeon_level.is_passable(cell):
						continue
					if dungeon_level.has_method("find_char_at") and dungeon_level.find_char_at(cell) != null:
						continue
					Sheep.spawn_at(cell, dungeon_level, 10)
					spawned += 1
			if MessageLog:
				if spawned > 0:
					MessageLog.add("Sheep appear everywhere!")
				else:
					MessageLog.add("The wooly magic fizzles without room to form sheep.")

		BombType.NOISEMAKER:
			# Alert all enemies on the level
			if dungeon_level != null and dungeon_level.has_method("alert_all_mobs"):
				dungeon_level.alert_all_mobs(bomb_pos)
			if MessageLog:
				MessageLog.add_warning("A deafening noise echoes through the dungeon!")

		BombType.FLASHBANG:
			# Blind all characters in the radius
			if dungeon_level != null and dungeon_level.has_method("get_chars_at_positions"):
				var chars: Array = dungeon_level.get_chars_at_positions(cells)
				for ch: Variant in chars:
					if ch != null and ch.has_method("add_buff"):
						var blind: Blindness = Blindness.new()
						blind.set_duration(10.0)
						ch.add_buff(blind)
			if MessageLog:
				MessageLog.add_warning("A blinding flash fills the area!")

		BombType.SHOCK:
			# Chain lightning between characters
			if dungeon_level != null and dungeon_level.has_method("get_chars_at_positions"):
				var chars: Array = dungeon_level.get_chars_at_positions(cells)
				for ch: Variant in chars:
					if ch != null and ch.has_method("take_damage"):
						@warning_ignore("integer_division")
						var shock_dmg: int = randi_range(damage_min / 2, damage_max / 2)
						ch.take_damage(shock_dmg, null)
			if MessageLog:
				MessageLog.add_warning("Lightning arcs between targets!")

		BombType.REGROWTH:
			# Grow plants in the area
			if dungeon_level != null and dungeon_level.has_method("set_terrain"):
				for cell: int in cells:
					if dungeon_level.has_method("get_terrain"):
						var terrain: int = dungeon_level.get_terrain(cell)
						if terrain == ConstantsData.Terrain.EMPTY or terrain == ConstantsData.Terrain.EMBERS:
							dungeon_level.set_terrain(cell, ConstantsData.Terrain.HIGH_GRASS)
			if MessageLog:
				MessageLog.add_positive("Lush vegetation springs up!")

		BombType.HOLY:
			if MessageLog:
				MessageLog.add_positive("Holy light sears the undead!")

		BombType.ARCANE:
			if MessageLog:
				MessageLog.add_info("Arcane energy rips through all defenses!")

## Get all cell positions within a Chebyshev radius of a center position.
func _get_cells_in_radius(center: int, rad: int) -> Array[int]:
	var cells: Array[int] = []
	var cx: int = ConstantsData.pos_to_x(center)
	var cy: int = ConstantsData.pos_to_y(center)
	for dy: int in range(-rad, rad + 1):
		for dx: int in range(-rad, rad + 1):
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx >= 0 and nx < ConstantsData.WIDTH and ny >= 0 and ny < ConstantsData.HEIGHT:
				cells.append(ConstantsData.xy_to_pos(nx, ny))
	return cells

## Chebyshev distance between two flat-index positions.
func _chebyshev_distance(a: int, b: int) -> int:
	var ax: int = ConstantsData.pos_to_x(a)
	var ay: int = ConstantsData.pos_to_y(a)
	var bx: int = ConstantsData.pos_to_x(b)
	var by: int = ConstantsData.pos_to_y(b)
	return maxi(absi(bx - ax), absi(by - ay))

## Remove one from the stack and remove the item if depleted.
func _consume_one(hero: Char) -> void:
	quantity -= 1
	if quantity <= 0:
		if hero != null and hero.get("belongings") != null:
			hero.belongings.remove_item(self)

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	match item_id:
		"bomb":
			return 20 * quantity
		"holy_bomb", "arcane_bomb":
			return 40 * quantity
		_:
			return 30 * quantity

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Bomb"
	data["fuse_turns"] = fuse_turns
	data["radius"] = radius
	data["damage_min"] = damage_min
	data["damage_max"] = damage_max
	data["bomb_type"] = bomb_type
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	fuse_turns = data.get("fuse_turns", 2)
	radius = data.get("radius", 1)
	damage_min = data.get("damage_min", 10)
	damage_max = data.get("damage_max", 30)
	bomb_type = data.get("bomb_type", BombType.NORMAL) as BombType

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a bomb by ID.
static func create(bomb_id: String) -> Bomb:
	var bomb: Bomb = Bomb.new()
	bomb.item_id = bomb_id

	match bomb_id:
		"bomb":
			bomb.item_name = "Bomb"
			bomb.description = "A black-powder bomb. Explodes after a short fuse, dealing damage in an area."
			bomb.damage_min = 10
			bomb.damage_max = 30
			bomb.bomb_type = BombType.NORMAL
			bomb.icon_color = Color(0.3, 0.3, 0.3)

		"fire_bomb":
			bomb.item_name = "Fire Bomb"
			bomb.description = "Explodes and leaves fire blobs that burn anything in the area."
			bomb.damage_min = 8
			bomb.damage_max = 20
			bomb.bomb_type = BombType.FIRE
			bomb.icon_color = Color(1.0, 0.4, 0.1)

		"frost_bomb":
			bomb.item_name = "Frost Bomb"
			bomb.description = "Explodes in a burst of cold, freezing everything nearby."
			bomb.damage_min = 5
			bomb.damage_max = 15
			bomb.bomb_type = BombType.FROST
			bomb.icon_color = Color(0.4, 0.7, 1.0)

		"holy_bomb":
			bomb.item_name = "Holy Bomb"
			bomb.description = "Blessed explosives that deal double damage to undead creatures."
			bomb.damage_min = 10
			bomb.damage_max = 30
			bomb.bomb_type = BombType.HOLY
			bomb.icon_color = Color(1.0, 1.0, 0.6)

		"wooly_bomb":
			bomb.item_name = "Wooly Bomb"
			bomb.description = "Summons a flock of magic sheep that block movement."
			bomb.damage_min = 0
			bomb.damage_max = 0
			bomb.bomb_type = BombType.WOOLY
			bomb.icon_color = Color(0.95, 0.95, 0.9)

		"noisemaker":
			bomb.item_name = "Noisemaker"
			bomb.description = "A deafening device that alerts every enemy on the floor."
			bomb.damage_min = 0
			bomb.damage_max = 0
			bomb.bomb_type = BombType.NOISEMAKER
			bomb.icon_color = Color(0.9, 0.8, 0.2)

		"flashbang":
			bomb.item_name = "Flashbang"
			bomb.description = "Emits a blinding flash that blinds all creatures in the blast radius."
			bomb.damage_min = 2
			bomb.damage_max = 8
			bomb.bomb_type = BombType.FLASHBANG
			bomb.icon_color = Color(1.0, 1.0, 0.9)

		"shock_bomb":
			bomb.item_name = "Shock Bomb"
			bomb.description = "Releases chain lightning that arcs between nearby targets."
			bomb.damage_min = 8
			bomb.damage_max = 25
			bomb.bomb_type = BombType.SHOCK
			bomb.icon_color = Color(0.3, 0.5, 1.0)

		"regrowth_bomb":
			bomb.item_name = "Regrowth Bomb"
			bomb.description = "Scatters enchanted seeds that cause rapid plant growth."
			bomb.damage_min = 0
			bomb.damage_max = 0
			bomb.bomb_type = BombType.REGROWTH
			bomb.icon_color = Color(0.3, 0.8, 0.3)

		"arcane_bomb":
			bomb.item_name = "Arcane Bomb"
			bomb.description = "Detonates with pure magical energy that ignores all armor."
			bomb.damage_min = 15
			bomb.damage_max = 40
			bomb.bomb_type = BombType.ARCANE
			bomb.icon_color = Color(0.7, 0.3, 0.9)

		_:
			bomb.item_name = "Bomb"
			bomb.description = "An explosive device."
			bomb.bomb_type = BombType.NORMAL
			bomb.icon_color = Color(0.5, 0.5, 0.5)

	return bomb
