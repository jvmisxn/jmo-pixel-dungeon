class_name ItemAppearanceNode
extends Node
## Per-run unidentified appearance mappings for potions, scrolls, and rings.
## This closes part of the SPD parity gap by giving unidentified item classes
## deterministic run-scoped appearances while preserving true names once known.

const POTION_APPEARANCES: Array[Dictionary] = [
	{"name": "Crimson", "color": [0.86, 0.18, 0.18, 1.0]},
	{"name": "Emerald", "color": [0.18, 0.72, 0.24, 1.0]},
	{"name": "Sapphire", "color": [0.20, 0.30, 0.82, 1.0]},
	{"name": "Golden", "color": [0.88, 0.76, 0.16, 1.0]},
	{"name": "Violet", "color": [0.70, 0.30, 0.82, 1.0]},
	{"name": "Amber", "color": [0.90, 0.54, 0.18, 1.0]},
	{"name": "Turquoise", "color": [0.18, 0.76, 0.72, 1.0]},
	{"name": "Silver", "color": [0.82, 0.82, 0.86, 1.0]},
	{"name": "Onyx", "color": [0.14, 0.14, 0.18, 1.0]},
	{"name": "Rose", "color": [0.84, 0.42, 0.56, 1.0]},
	{"name": "Jade", "color": [0.30, 0.66, 0.40, 1.0]},
	{"name": "Azure", "color": [0.32, 0.62, 0.92, 1.0]},
	{"name": "Ivory", "color": [0.92, 0.90, 0.82, 1.0]},
	{"name": "Umber", "color": [0.46, 0.34, 0.22, 1.0]},
]

const SCROLL_RUNES: Array[String] = [
	"YNGVI", "ODAL", "KAIRO", "ULMAR", "VELT", "NAZAR", "QORI",
	"SERAK", "ITHAR", "MELQT", "DORUN", "AESTR", "PHOEN", "TYRIX",
]

const RING_APPEARANCES: Array[Dictionary] = [
	{"name": "agate", "color": [0.52, 0.42, 0.34, 1.0]},
	{"name": "amethyst", "color": [0.58, 0.36, 0.76, 1.0]},
	{"name": "diamond", "color": [0.84, 0.90, 0.96, 1.0]},
	{"name": "emerald", "color": [0.20, 0.70, 0.36, 1.0]},
	{"name": "garnet", "color": [0.70, 0.18, 0.20, 1.0]},
	{"name": "jade", "color": [0.26, 0.66, 0.48, 1.0]},
	{"name": "opal", "color": [0.78, 0.74, 0.90, 1.0]},
	{"name": "ruby", "color": [0.84, 0.18, 0.26, 1.0]},
	{"name": "sapphire", "color": [0.22, 0.34, 0.82, 1.0]},
	{"name": "topaz", "color": [0.86, 0.66, 0.18, 1.0]},
	{"name": "onyx", "color": [0.16, 0.16, 0.20, 1.0]},
]

var _potion_data: Dictionary = {}
var _scroll_data: Dictionary = {}
var _ring_data: Dictionary = {}

func reset_for_new_run(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else 1

	var potion_ids: Array[String] = Potion.all_ids()
	var potion_pool: Array = POTION_APPEARANCES.duplicate(true)
	_shuffle_array(potion_pool, rng)
	_potion_data.clear()
	for i: int in range(mini(potion_ids.size(), potion_pool.size())):
		_potion_data[potion_ids[i]] = potion_pool[i]

	var scroll_ids: Array[String] = Scroll.all_ids()
	var rune_pool: Array = SCROLL_RUNES.duplicate()
	_shuffle_array(rune_pool, rng)
	_scroll_data.clear()
	for i: int in range(mini(scroll_ids.size(), rune_pool.size())):
		_scroll_data[scroll_ids[i]] = rune_pool[i]

	var ring_ids: Array[String] = Generator.RINGS.duplicate()
	var ring_pool: Array = RING_APPEARANCES.duplicate(true)
	_shuffle_array(ring_pool, rng)
	_ring_data.clear()
	for i: int in range(mini(ring_ids.size(), ring_pool.size())):
		_ring_data[ring_ids[i]] = ring_pool[i]

func ensure_initialized() -> void:
	if _potion_data.is_empty() and _scroll_data.is_empty() and _ring_data.is_empty():
		var seed_value: int = GameManager.run_seed if GameManager else 1
		reset_for_new_run(seed_value)

func apply_appearance(item: Variant) -> void:
	if item == null:
		return
	ensure_initialized()
	var item_id: String = ConstantsData.get_prop(item, "item_id", "")
	if item_id.is_empty():
		return

	if item is Potion:
		var potion_data: Dictionary = _potion_data.get(item_id, {})
		(item as Potion).appearance_name = potion_data.get("name", "")
		var color_values: Array = potion_data.get("color", [])
		if color_values.size() >= 4:
			(item as Potion).potion_color = Color(color_values[0], color_values[1], color_values[2], color_values[3])
	elif item is Scroll:
		(item as Scroll).rune_symbol = _scroll_data.get(item_id, "UNKNOWN")
	elif item is Ring:
		var ring_data: Dictionary = _ring_data.get(item_id, {})
		var gem_name: String = ring_data.get("name", "")
		var gem_color_values: Array = ring_data.get("color", [])
		var ring: Ring = item as Ring
		ring.gem_name = gem_name
		if gem_color_values.size() >= 4:
			ring.gem_color = Color(gem_color_values[0], gem_color_values[1], gem_color_values[2], gem_color_values[3])

func serialize() -> Dictionary:
	return {
		"potions": _potion_data.duplicate(true),
		"scrolls": _scroll_data.duplicate(true),
		"rings": _ring_data.duplicate(true),
	}

func deserialize(data: Dictionary) -> void:
	_potion_data = data.get("potions", {}).duplicate(true)
	_scroll_data = data.get("scrolls", {}).duplicate(true)
	_ring_data = data.get("rings", {}).duplicate(true)
	if _potion_data.is_empty() and _scroll_data.is_empty() and _ring_data.is_empty():
		var seed_value: int = GameManager.run_seed if GameManager else 1
		reset_for_new_run(seed_value)

func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
