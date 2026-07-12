extends RefCounted
## Compile smoke test: every autoload script — the runtime spine that compiles
## on real boot — must load as a valid GDScript. A parse error or truncated file
## makes load() return null, so this catches the exact failure mode this repo has
## historically suffered (partial-file writes breaking a global class).

const MUST_COMPILE: Array[String] = [
	"res://src/autoloads/constants.gd",
	"res://src/autoloads/event_bus.gd",
	"res://src/autoloads/message_log.gd",
	"res://src/autoloads/turn_manager.gd",
	"res://src/autoloads/game_manager.gd",
	"res://src/autoloads/save_manager.gd",
	"res://src/autoloads/audio_manager.gd",
	"res://src/autoloads/badges.gd",
	"res://src/autoloads/item_catalog.gd",
	"res://src/autoloads/item_appearance.gd",
	"res://src/autoloads/discovery_catalog.gd",
	"res://src/autoloads/scene_manager.gd",
	"res://src/autoloads/network_manager.gd",
	"res://src/autoloads/player_profile.gd",
]

func run(t: Object) -> void:
	for path: String in MUST_COMPILE:
		var res: Variant = load(path)
		t.check(res != null and res is GDScript, "compiles: " + path)
