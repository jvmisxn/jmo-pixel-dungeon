class_name Key
extends Item
## Key items used to unlock doors, chests, and special locks. Not stackable and
## not upgradeable. Each key records the dungeon depth it belongs to.

# --- Properties ---
## The dungeon depth this key is valid for.
var depth: int = 0

func _init() -> void:
	category = ConstantsData.ItemCategory.MISC
	stackable = false
	unique = false
	default_action = "UNLOCK"
	identified = true
	cursed_known = true
	icon_color = Color(0.85, 0.75, 0.2)

func is_upgradeable() -> bool:
	return false

func is_stackable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

## Keys are used contextually (opening doors/chests) rather than via execute.
## The hero's interact action checks for keys in inventory.
func execute(_hero: Char) -> void:
	if MessageLog:
		MessageLog.add_info("Use this key on a locked door or chest.")

func on_pickup(_hero: Char) -> void:
	# Assign the key's depth to the current dungeon depth
	if GameManager:
		depth = GameManager.depth
	if MessageLog:
		MessageLog.add("You pick up a %s." % item_name)

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	return "%s (depth %d)" % [item_name, depth]

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	match item_id:
		"golden_key":
			return 100
		"crystal_key":
			return 150
		"skeleton_key":
			return 200
		_:
			return 50

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Key"
	data["depth"] = depth
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	depth = data.get("depth", 0)

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a key by ID.
static func create(key_id: String) -> Key:
	var key: Key = Key.new()
	key.item_id = key_id
	if GameManager:
		key.depth = GameManager.depth

	match key_id:
		"iron_key":
			key.item_name = "Iron Key"
			key.description = "A rusty iron key. Opens a single locked door on this floor."
			key.icon_color = Color(0.6, 0.55, 0.5)

		"golden_key":
			key.item_name = "Golden Key"
			key.description = "A gleaming golden key. Opens a golden chest."
			key.icon_color = Color(1.0, 0.85, 0.2)

		"crystal_key":
			key.item_name = "Crystal Key"
			key.description = "A translucent crystal key. Opens a crystal door and the crystal chest beyond it."
			key.icon_color = Color(0.6, 0.85, 1.0)

		"skeleton_key":
			key.item_name = "Skeleton Key"
			key.description = "A heavy bone key dropped by a defeated boss. Opens the special lock barring the way forward."
			key.icon_color = Color(0.9, 0.9, 0.85)
			key.unique = true

		_:
			key.item_name = "Key"
			key.description = "A key of unknown origin."

	return key
