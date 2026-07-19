extends RefCounted
## Contract test for the EventBus autoload.
##
## Systems all over the codebase `connect()` to these signals by name. If one is
## renamed or removed, the connect() silently no-ops (or errors at runtime) with
## no compile-time warning. This pins the declared signal contract so CI fails
## the moment a required signal disappears.
##
## (The audit also found signals that are emitted-but-never-consumed and
## connected-but-never-emitted; that's a wiring problem tracked in the backlog.
## What we can guard mechanically is that the contract itself stays intact.)

const REQUIRED_SIGNALS: Array[String] = [
	"hero_moved", "hero_moved_detailed", "hero_died", "hero_fell", "hero_stats_changed",
	"mob_defeated", "mob_died", "mob_damaged",
	"level_changed", "door_opened", "trap_triggered", "gold_collected",
	"game_saved", "game_loaded",
	"item_picked_up", "item_used", "item_equipped", "item_unequipped",
	"enter_targeting", "cancel_targeting", "request_hero_action",
	"boss_fight_started", "boss_damaged", "boss_defeated",
	"badge_unlocked", "quest_updated",
]

class CountingEffectManager:
	extends Node

	var damage_calls: int = 0

	func show_damage(_pos: int, _amount: int, _is_crit: bool = false) -> void:
		damage_calls += 1

func run(t: Object) -> void:
	var script: Variant = load("res://src/autoloads/event_bus.gd")
	t.check(script != null and script is GDScript, "event_bus.gd compiles")
	if script == null:
		return
	var bus: Object = script.new()
	for sig: String in REQUIRED_SIGNALS:
		t.check(bus.has_signal(sig), "EventBus declares signal: " + sig)
	if bus is Node:
		(bus as Node).free()
	_test_game_scene_event_bus_connections_are_idempotent(t)


func _test_game_scene_event_bus_connections_are_idempotent(t: Object) -> void:
	var scene := GameScene.new()
	var effects := CountingEffectManager.new()
	scene.effect_manager = effects
	scene.add_child(effects)
	scene._connect_signals()
	scene._connect_signals()

	EventBus.mob_damaged.emit(42, 7)
	t.check(
		effects.damage_calls == 1,
		"GameScene connects mob damage feedback once even if setup runs twice"
	)

	scene.free()
