class_name Seed
extends RefCounted
## Seed item that, when thrown at a cell, grows into its corresponding plant.
## Seeds can also be found as loot or purchased in shops.
## Mirrors Shattered PD's Plant.Seed.

# --- Item-like properties ---
var item_name: String = "Seed"
var seed_id: String = "Seed"
var plant_type: String = "Plant"
var stackable: bool = true
var quantity: int = 1
var value: int = 10  # gold value for shops

## Mapping of plant types to their display names.
const PLANT_NAMES: Dictionary = {
	"Sungrass": "Seed of Sungrass",
	"Earthroot": "Seed of Earthroot",
	"Fadeleaf": "Seed of Fadeleaf",
	"Firebloom": "Seed of Firebloom",
	"Icecap": "Seed of Icecap",
	"Sorrowmoss": "Seed of Sorrowmoss",
	"Dreamfoil": "Seed of Dreamfoil",
	"Stormvine": "Seed of Stormvine",
	"Blindweed": "Seed of Blindweed",
	"Rotberry": "Seed of Rotberry",
	"Starflower": "Seed of Starflower",
	"Swiftthistle": "Seed of Swiftthistle",
}

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a seed for the given plant type string.
static func create(p_plant_type: String) -> Seed:
	var s: Seed = Seed.new()
	s.plant_type = p_plant_type
	s.seed_id = "seed_of_%s" % p_plant_type.to_lower()
	s.item_name = PLANT_NAMES.get(p_plant_type, "Seed of %s" % p_plant_type)
	return s

## Create a random seed (weighted; Starflower is rare).
static func create_random() -> Seed:
	var types: Array[String] = [
		"Sungrass", "Earthroot", "Fadeleaf", "Firebloom",
		"Icecap", "Sorrowmoss", "Dreamfoil", "Stormvine",
		"Blindweed", "Swiftthistle",
	]
	# Starflower is rare — 5% chance
	if randf() < 0.05:
		return Seed.create("Starflower")
	var idx: int = randi_range(0, types.size() - 1)
	return Seed.create(types[idx])

# ---------------------------------------------------------------------------
# Plant creation
# ---------------------------------------------------------------------------

## Instantiate the Plant object that corresponds to this seed's plant_type.
func create_plant() -> Plant:
	match plant_type:
		"Sungrass":
			return Sungrass.new()
		"Earthroot":
			return Earthroot.new()
		"Fadeleaf":
			return Fadeleaf.new()
		"Firebloom":
			return Firebloom.new()
		"Icecap":
			return Icecap.new()
		"Sorrowmoss":
			return Sorrowmoss.new()
		"Dreamfoil":
			return Dreamfoil.new()
		"Stormvine":
			return Stormvine.new()
		"Blindweed":
			return Blindweed.new()
		"Rotberry":
			return Rotberry.new()
		"Starflower":
			return Starflower.new()
		"Swiftthistle":
			return Swiftthistle.new()
		_:
			return Plant.new()

# ---------------------------------------------------------------------------
# Throw / Plant
# ---------------------------------------------------------------------------

## Throw this seed at a position, planting it on the level.
## If a character is already standing there, the plant activates immediately.
func throw_at(target_pos: int, level: Variant) -> void:
	if level == null or target_pos < 0:
		return

	var plant: Plant = create_plant()
	plant.pos = target_pos

	# Check if someone is standing on the target cell
	var occupant: Variant = null
	if level.has_method("find_char_at"):
		occupant = level.find_char_at(target_pos)

	if occupant != null:
		# Activate immediately
		plant.activate(occupant, level)
		if MessageLog:
			MessageLog.add("The %s grows and " +
				"activates instantly!" % plant.plant_name)
	else:
		# Plant it on the ground
		if level.get("plants") is Dictionary:
			level.plants[target_pos] = plant
		# Update terrain visual
		if level.has_method("set_terrain"):
			level.set_terrain(target_pos, ConstantsData.Terrain.HIGH_GRASS)
		if MessageLog:
			MessageLog.add("A %s grows at the spot." % plant.plant_name)

	if EventBus and EventBus.has_signal("seed_planted"):
		EventBus.emit_signal("seed_planted", target_pos, plant_type)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"seed_id": seed_id,
		"plant_type": plant_type,
		"item_name": item_name,
		"quantity": quantity,
	}

func deserialize(data: Dictionary) -> void:
	seed_id = data.get("seed_id", seed_id)
	plant_type = data.get("plant_type", plant_type)
	item_name = data.get("item_name", item_name)
	quantity = data.get("quantity", 1)

func _to_string() -> String:
	return item_name
