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
	"res://tests/cases/test_boss_hp_signals.gd",
	"res://tests/cases/test_headless_save_descend_reload.gd",
	"res://tests/cases/test_game_manager_run_state.gd",
	"res://tests/cases/test_network_run_config_authority.gd",
	"res://tests/cases/test_save_manager.gd",
	"res://tests/cases/test_turn_manager_schedule_persistence.gd",
	"res://tests/cases/test_buff_timeline.gd",
	"res://tests/cases/test_status_pane.gd",
	"res://tests/cases/test_minimap_refresh.gd",
	"res://tests/cases/test_scene_transition_current_scene.gd",
	"res://tests/cases/test_audio_manager_assets.gd",
	"res://tests/cases/test_mobile_hud_input.gd",
	"res://tests/cases/test_hud_desktop_buffs.gd",
	"res://tests/cases/test_game_menu_access.gd",
	"res://tests/cases/test_touch_gesture_routing.gd",
	"res://tests/cases/test_hud_window_stack.gd",
	"res://tests/cases/test_wnd_item_drop_slots.gd",
	"res://tests/cases/test_targeting_input.gd",
	"res://tests/cases/test_stairs_click_input.gd",
	"res://tests/cases/test_hero_search_radius.gd",
	"res://tests/cases/test_title_mobile_layout.gd",
	"res://tests/cases/test_hero_select_portrait_layout.gd",
	"res://tests/cases/test_game_camera_mobile_zoom.gd",
	"res://tests/cases/test_char_sprite_animations.gd",
	"res://tests/cases/test_wand_recharge.gd",
	"res://tests/cases/test_mages_staff.gd",
	"res://tests/cases/test_wand_use_identification.gd",
	"res://tests/cases/test_hero_xp_cap.gd",
	"res://tests/cases/test_shop_gold_events.gd",
	"res://tests/cases/test_wand_of_frost.gd",
	"res://tests/cases/test_wand_of_lightning.gd",
	"res://tests/cases/test_wand_of_disintegration.gd",
	"res://tests/cases/test_wand_of_corrosion.gd",
	"res://tests/cases/test_wand_of_corruption.gd",
	"res://tests/cases/test_wand_of_warding.gd",
	"res://tests/cases/test_halls_traps.gd",
	"res://tests/cases/test_region_trap_tables.gd",
	"res://tests/cases/test_disarming_trap.gd",
	"res://tests/cases/test_stone_of_disarming.gd",
	"res://tests/cases/test_cursing_trap.gd",
	"res://tests/cases/test_fire_trap.gd",
	"res://tests/cases/test_frost_trap.gd",
	"res://tests/cases/test_electricity_traps.gd",
	"res://tests/cases/test_corrosion_trap.gd",
	"res://tests/cases/test_confusion_trap.gd",
	"res://tests/cases/test_weakening_trap.gd",
	"res://tests/cases/test_disintegration_trap.gd",
	"res://tests/cases/test_grim_trap.gd",
	"res://tests/cases/test_gateway_trap.gd",
	"res://tests/cases/test_geyser_trap.gd",
	"res://tests/cases/test_pitfall_trap_seal.gd",
	"res://tests/cases/test_pitfall_heap_drop.gd",
	"res://tests/cases/test_chasm_drop_item.gd",
	"res://tests/cases/test_pit_room_contents.gd",
	"res://tests/cases/test_trap_edge_wrap.gd",
	"res://tests/cases/test_plant_blob_seeding.gd",
	"res://tests/cases/test_paralytic_trap.gd",
	"res://tests/cases/test_chasm_fall.gd",
	"res://tests/cases/test_door_key_gating.gd",
	"res://tests/cases/test_mob_factory.gd",
	"res://tests/cases/test_mob_invisibility_targeting.gd",
	"res://tests/cases/test_fetid_rat_stench.gd",
	"res://tests/cases/test_dm201_corrosive_gas.gd",
	"res://tests/cases/test_spinner_ai.gd",
	"res://tests/cases/test_necromancer_summon.gd",
	"res://tests/cases/test_thrown_potion_shatter.gd",
	"res://tests/cases/test_potion_of_experience.gd",
	"res://tests/cases/test_item_stack_splitting.gd",
	"res://tests/cases/test_bag_serialization.gd",
	"res://tests/cases/test_ankh_revival.gd",
	"res://tests/cases/test_bag_pickup_routing.gd",
	"res://tests/cases/test_char_combat_serialization.gd",
	"res://tests/cases/test_speed_modifiers.gd",
	"res://tests/cases/test_blobs.gd",
	"res://tests/cases/test_blob_timeline.gd",
	"res://tests/cases/test_confusion_gas_seeder.gd",
	"res://tests/cases/test_smoke_screen.gd",
	"res://tests/cases/test_smoke_bomb.gd",
	"res://tests/cases/test_frost_bomb.gd",
	"res://tests/cases/test_regrowth_bomb.gd",
	"res://tests/cases/test_wild_energy_spell.gd",
	"res://tests/cases/test_water_of_health_well.gd",
	"res://tests/cases/test_mob_spawn_positions.gd",
	"res://tests/cases/test_level_generation_doors.gd",
	"res://tests/cases/test_mimic_loot.gd",
	"res://tests/cases/test_fury_damage.gd",
	"res://tests/cases/test_damage_roll_distribution.gd",
	"res://tests/cases/test_combat_buffs.gd",
	"res://tests/cases/test_poison_damage_timing.gd",
	"res://tests/cases/test_status_source_serialization.gd",
	"res://tests/cases/test_frozen.gd",
	"res://tests/cases/test_gladiator_combo.gd",
	"res://tests/cases/test_sleep_freeze_effects.gd",
	"res://tests/cases/test_stormvine_parity.gd",
	"res://tests/cases/test_sorrowmoss.gd",
	"res://tests/cases/test_plant_edge_wrap.gd",
	"res://tests/cases/test_vertigo_edge_wrap.gd",
	"res://tests/cases/test_barrier_shielding.gd",
	"res://tests/cases/test_herbal_armor.gd",
	"res://tests/cases/test_interval_armor_buffs.gd",
	"res://tests/cases/test_armor_random_glyphs.gd",
	"res://tests/cases/test_flow_entanglement_glyphs.gd",
	"res://tests/cases/test_curse_weapon_enchantments.gd",
	"res://tests/cases/test_ring_of_might_state.gd",
	"res://tests/cases/test_ring_of_wealth.gd",
	"res://tests/cases/test_ring_of_force.gd",
	"res://tests/cases/test_ring_of_sharpshooting.gd",
	"res://tests/cases/test_cape_of_thorns.gd",
	"res://tests/cases/test_surprise_attacks.gd",
	"res://tests/cases/test_swarm_split.gd",
	"res://tests/cases/test_weapon_differentiation.gd",
	"res://tests/cases/test_spirit_bow_serialization.gd",
	"res://tests/cases/test_blacksmith_ore_quest.gd",
	"res://tests/cases/test_sad_ghost_rewards.gd",
	"res://tests/cases/test_ballistica.gd",
	"res://tests/cases/test_pathfinder.gd",
	"res://tests/cases/test_shadow_caster.gd",
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
