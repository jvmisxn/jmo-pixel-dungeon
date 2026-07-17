extends SceneTree
## Headless test runner for jmo-pixel-dungeon.
##
## Run locally (once Godot 4.5 is installed):
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Exit code is 0 when all checks pass, 1 otherwise — CI keys off that.
## Each entry in CASES is a script exposing `func run(t: Object) -> void`,
## where `t` is this runner (call `t.check(cond, msg)` for each assertion).

const CASES: Array[String] = [
	"res://tests/cases/test_compile.gd",
	"res://tests/cases/test_event_bus.gd",
	"res://tests/cases/test_headless_save_descend_reload.gd",
	"res://tests/cases/test_game_manager_run_state.gd",
	"res://tests/cases/test_save_manager.gd",
	"res://tests/cases/test_wand_recharge.gd",
	"res://tests/cases/test_speed_modifiers.gd",
]

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	print("== jmo-pixel-dungeon test runner ==")
	for case_path: String in CASES:
		var script: Variant = load(case_path)
		if script == null or not script is Script or not (script as Script).can_instantiate():
			_record_failure("could not load test case: " + case_path)
			continue
		var case: Object = script.new()
		if not case.has_method("run"):
			_record_failure("test case missing run(t): " + case_path)
			continue
		print("-- ", case_path)
		case.run(self)
	print("")
	print("Ran %d check(s), %d failure(s)." % [_checks, _failures.size()])
	for f: String in _failures:
		print("  FAIL: ", f)
	quit(1 if _failures.size() > 0 else 0)

## Assertion entry point used by test cases.
func check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("   ok  ", msg)
	else:
		_failures.append(msg)
		print("   XX  ", msg)

func _record_failure(msg: String) -> void:
	_checks += 1
	_failures.append(msg)
	print("   XX  ", msg)
