class_name DiscoveryCatalogNode
extends Node
## Persistent cross-run discovery tracking for enemies, traps, and plants.
## This gives the Journal a broader catalog closer to modern SPD behavior.

const SAVE_PATH: String = "user://discovery_catalog.dat"

var _bestiary: Dictionary[String, int] = {}
var _allies: Dictionary[String, int] = {}
var _traps: Dictionary[String, int] = {}
var _plants: Dictionary[String, int] = {}
var _enchantments: Dictionary[String, int] = {}
var _glyphs: Dictionary[String, int] = {}

func _ready() -> void:
	_load()
	if EventBus:
		EventBus.mob_defeated.connect(_on_mob_defeated)
		EventBus.mob_revealed.connect(_on_mob_revealed)
		if EventBus.has_signal("npc_interacted"):
			EventBus.npc_interacted.connect(_on_npc_interacted)
		EventBus.trap_triggered.connect(_on_trap_triggered)
		EventBus.enchantment_proc.connect(_on_enchantment_proc)
		EventBus.glyph_proc.connect(_on_glyph_proc)
		if EventBus.has_signal("plant_activated"):
			EventBus.plant_activated.connect(_on_plant_activated)

func record_mob(mob_name: String) -> void:
	_record(_bestiary, mob_name)

func record_trap(trap_name: String) -> void:
	_record(_traps, trap_name)

func record_plant(plant_name: String) -> void:
	_record(_plants, plant_name)

func record_ally(ally_name: String) -> void:
	_record(_allies, ally_name)

func record_enchantment(enchantment_name: String) -> void:
	_record(_enchantments, enchantment_name)

func record_glyph(glyph_name: String) -> void:
	_record(_glyphs, glyph_name)

func get_sections() -> Dictionary:
	return {
		"bestiary": _build_entries(_bestiary),
		"allies": _build_entries(_allies),
		"traps": _build_entries(_traps),
		"plants": _build_entries(_plants),
		"enchantments": _build_entries(_enchantments),
		"glyphs": _build_entries(_glyphs),
	}

func _on_mob_defeated(_mob_pos: int, mob_name: String) -> void:
	record_mob(mob_name)

func _on_mob_revealed(mob: Variant) -> void:
	if mob != null:
		record_mob(ConstantsData.get_prop(mob, "mob_name", ""))

func _on_npc_interacted(npc_name: String) -> void:
	record_ally(npc_name)

func _on_trap_triggered(_pos: int, trap_name: String) -> void:
	record_trap(trap_name)

func _on_plant_activated(_pos: int, plant_name: String) -> void:
	record_plant(plant_name)

func _on_enchantment_proc(enchant_id: String, _attacker_pos: int, _defender_pos: int) -> void:
	var enchantment: WeaponEnchantment = WeaponEnchantment.create(enchant_id)
	if enchantment != null:
		_record(_enchantments, enchantment.enchant_name)

func _on_glyph_proc(glyph_id: String, _wearer_pos: int, _attacker_pos: int) -> void:
	var glyph: ArmorGlyph = ArmorGlyph.create(glyph_id)
	if glyph != null:
		_record(_glyphs, glyph.glyph_name)

func _record(target: Dictionary[String, int], entry_name: String) -> void:
	var normalized: String = entry_name.strip_edges()
	if normalized.is_empty():
		return
	target[normalized] = target.get(normalized, 0) + 1
	_save()

func _build_entries(source: Dictionary[String, int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_name: String in source.keys():
		result.append({
			"name": entry_name,
			"count": source.get(entry_name, 0),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("name", "") < b.get("name", "")
	)
	return result

func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("DiscoveryCatalog: Failed to open save file for writing.")
		return
	file.store_var({
		"bestiary": _bestiary,
		"allies": _allies,
		"traps": _traps,
		"plants": _plants,
		"enchantments": _enchantments,
		"glyphs": _glyphs,
	}, true)
	file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("DiscoveryCatalog: Failed to open save file for reading.")
		return
	var data: Variant = file.get_var(true)
	file.close()
	if data is Dictionary:
		_bestiary = _coerce_string_int_dict(data.get("bestiary", {}))
		_allies = _coerce_string_int_dict(data.get("allies", {}))
		_traps = _coerce_string_int_dict(data.get("traps", {}))
		_plants = _coerce_string_int_dict(data.get("plants", {}))
		_enchantments = _coerce_string_int_dict(data.get("enchantments", {}))
		_glyphs = _coerce_string_int_dict(data.get("glyphs", {}))

func _coerce_string_int_dict(source: Variant) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	if not source is Dictionary:
		return result
	for key: Variant in source.keys():
		var key_str: String = str(key)
		result[key_str] = int(source.get(key, 0))
	return result
