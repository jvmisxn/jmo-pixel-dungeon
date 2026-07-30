extends RefCounted
## ItemCatalog load coercion (backlog audit:S29).
##
## `_load()` used to `assign()` an untyped `get_var()` dict straight into the
## typed `Dictionary[String, bool]`, which can raise a runtime type error on
## Godot 4.4+ (e.g. non-String keys or non-bool values in a stale/corrupt
## save) and wipe global identification. It now routes through
## `_coerce_string_bool_dict`, mirroring DiscoveryCatalog. This pins that
## contract: hostile shapes are coerced or dropped, never crash.

func run(t: Object) -> void:
	var script: Variant = load("res://src/autoloads/item_catalog.gd")
	t.check(script != null and script is GDScript, "item_catalog.gd compiles")
	if script == null:
		return
	# new() only — not added to the tree, so _ready()/_load() never touch the
	# real user:// save file.
	var catalog: Object = script.new()

	t.check(catalog.has_method("_coerce_string_bool_dict"),
		"load path routes through _coerce_string_bool_dict")

	# Clean data passes through.
	var clean: Dictionary = {"potion_healing": true, "scroll_upgrade": true}
	var coerced: Dictionary = catalog._coerce_string_bool_dict(clean)
	t.check(coerced.size() == 2 and coerced.get("potion_healing", false),
		"clean String->bool entries survive coercion")

	# Hostile shapes: non-String keys, non-bool values, falsy entries.
	var hostile: Dictionary = {
		42: true,             # int key -> stringified
		"ring_might": 1,      # truthy int value -> kept as true
		"potion_frost": false, # falsy -> dropped (has() is the known check)
		"scroll_identify": "yes", # truthy String -> kept
	}
	var safe: Dictionary = catalog._coerce_string_bool_dict(hostile)
	t.check(safe.get("42", false), "non-String key is stringified, not fatal")
	t.check(safe.get("ring_might", false), "truthy non-bool value coerces to true")
	t.check(not safe.has("potion_frost"), "falsy entry is dropped")
	t.check(safe.get("scroll_identify", false), "truthy String value coerces to true")

	# Non-Dictionary payloads yield an empty typed dict, never a crash.
	t.check(catalog._coerce_string_bool_dict(null).is_empty(), "null payload -> empty")
	t.check(catalog._coerce_string_bool_dict([1, 2]).is_empty(), "Array payload -> empty")
	t.check(catalog._coerce_string_bool_dict("junk").is_empty(), "String payload -> empty")

	# Coerced result feeds the real known-check contract.
	catalog._identified_items = catalog._coerce_string_bool_dict(clean)
	t.check(catalog.is_item_known("potion_healing"), "coerced data drives is_item_known")
	t.check(not catalog.is_item_known("potion_frost"), "unknown id stays unknown")

	if catalog is Node:
		(catalog as Node).free()
