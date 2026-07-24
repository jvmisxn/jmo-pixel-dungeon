class_name Invisibility
extends Buff
## Makes the character invisible to enemies.
## Original: increments target.invisible counter; does NOT boost evasion.
## Broken by attacking, using items, or similar actions via dispel().

const BASE_DURATION: float = 20.0
const ProtectiveShadowsTrackerScript: GDScript = preload("res://src/actors/buffs/protective_shadows_tracker.gd")

func _init() -> void:
	buff_id = "Invisibility"
	buff_name = "Invisible"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.6, 0.6, 1.0, 0.5)

func on_attach() -> void:
	if target:
		# Increment invisible counter — mob detection logic checks this
		target.invisible += 1
		# Original: Invisibility.attachTo starts the Protective Shadows tracker
		# for heroes with the talent.
		if target.has_method("get_talent_level") \
				and target.get_talent_level("rogue_protective_shadows") > 0 \
				and not target.has_buff("ProtectiveShadowsTracker"):
			target.add_buff(ProtectiveShadowsTrackerScript.new())
		if MessageLog:
			MessageLog.add_positive("%s fades from view." % target.name)

func on_detach() -> void:
	if target:
		if target.invisible > 0:
			target.invisible -= 1
