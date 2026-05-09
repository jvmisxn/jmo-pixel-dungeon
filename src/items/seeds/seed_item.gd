class_name SeedItem
extends Item
## Real seed inventory item with targeted planting behavior.

var plant_type: String = ""

const PLANT_NAMES: Dictionary = {
	"firebloom": "Seed of Firebloom",
	"icecap": "Seed of Icecap",
	"sorrowmoss": "Seed of Sorrowmoss",
	"stormvine": "Seed of Stormvine",
	"sungrass": "Seed of Sungrass",
	"earthroot": "Seed of Earthroot",
	"fadeleaf": "Seed of Fadeleaf",
	"rotberry": "Seed of Rotberry",
	"blindweed": "Seed of Blindweed",
	"dreamfoil": "Seed of Dreamfoil",
	"starflower": "Seed of Starflower",
	"swiftthistle": "Seed of Swiftthistle",
}

const SEED_COLORS: Dictionary = {
	"seed_of_firebloom": Color(0.9, 0.4, 0.1),
	"seed_of_icecap": Color(0.4, 0.7, 1.0),
	"seed_of_sorrowmoss": Color(0.3, 0.7, 0.3),
	"seed_of_stormvine": Color(0.6, 0.6, 0.9),
	"seed_of_sungrass": Color(0.7, 0.8, 0.2),
	"seed_of_earthroot": Color(0.5, 0.4, 0.2),
	"seed_of_fadeleaf": Color(0.6, 0.7, 0.5),
	"seed_of_rotberry": Color(0.5, 0.3, 0.4),
	"seed_of_blindweed": Color(0.4, 0.5, 0.3),
	"seed_of_dreamfoil": Color(0.6, 0.5, 0.8),
	"seed_of_starflower": Color(0.9, 0.9, 0.4),
	"seed_of_swiftthistle": Color(0.8, 0.6, 0.7),
}

static func create(seed_id: String) -> SeedItem:
	var seed: SeedItem = SeedItem.new()
	seed._configure(seed_id)
	return seed

func _init() -> void:
	category = ConstantsData.ItemCategory.SEED
	stackable = true
	default_action = "PLANT"
	identified = true
	cursed_known = true

func _configure(seed_id: String) -> void:
	item_id = seed_id
	plant_type = seed_id.trim_prefix("seed_of_")
	item_name = PLANT_NAMES.get(plant_type, "Seed of %s" % plant_type.capitalize())
	description = "A magical seed that can be planted or used in alchemy."
	icon_color = SEED_COLORS.get(seed_id, Color(0.5, 0.7, 0.3))
	quantity = maxi(quantity, 1)

func is_upgradeable() -> bool:
	return false

func execute(hero: Char) -> void:
	if hero == null:
		return
	var callback: Callable = func(cell: int) -> void:
		plant_at(hero, cell)
	if EventBus and EventBus.has_signal("enter_targeting"):
		EventBus.enter_targeting.emit(self, 8, callback)
		if MessageLog:
			MessageLog.add("Choose where to plant the %s." % item_name)

func plant_at(hero: Char, target_pos: int) -> void:
	if hero == null:
		return
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null or target_pos < 0 or target_pos >= ConstantsData.LENGTH:
		return

	var plant: Plant = _create_plant()
	if plant == null:
		return
	plant.pos = target_pos

	var occupant: Variant = dungeon_level.find_char_at(target_pos) if dungeon_level.has_method("find_char_at") else null
	if occupant != null:
		plant.activate(occupant, dungeon_level)
		if MessageLog:
			MessageLog.add("The %s grows and activates instantly!" % plant.plant_name)
	else:
		if not dungeon_level.is_passable(target_pos):
			if MessageLog:
				MessageLog.add_warning("You can't plant a seed there.")
			return
		if dungeon_level.get("plants") is Dictionary:
			dungeon_level.plants[target_pos] = plant
		if dungeon_level.has_method("set_terrain"):
			dungeon_level.set_terrain(target_pos, ConstantsData.Terrain.HIGH_GRASS)
		if MessageLog:
			MessageLog.add("A %s grows at the spot." % plant.plant_name)

	if EventBus:
		if EventBus.has_signal("seed_planted"):
			EventBus.seed_planted.emit(target_pos, plant_type)
		EventBus.item_used.emit(item_name)

	_consume_one(hero)

func _create_plant() -> Plant:
	match plant_type:
		"sungrass":
			return Sungrass.new()
		"earthroot":
			return Earthroot.new()
		"fadeleaf":
			return Fadeleaf.new()
		"firebloom":
			return Firebloom.new()
		"icecap":
			return Icecap.new()
		"sorrowmoss":
			return Sorrowmoss.new()
		"dreamfoil":
			return Dreamfoil.new()
		"stormvine":
			return Stormvine.new()
		"blindweed":
			return Blindweed.new()
		"rotberry":
			return Rotberry.new()
		"starflower":
			return Starflower.new()
		"swiftthistle":
			return Swiftthistle.new()
		_:
			return null

func _consume_one(hero: Char) -> void:
	if hero == null or hero.get("belongings") == null:
		return
	if quantity > 1:
		quantity -= 1
	else:
		hero.belongings.remove_item(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["plant_type"] = plant_type
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	plant_type = str(data.get("plant_type", plant_type))
	_configure(item_id)
	quantity = int(data.get("quantity", quantity))
