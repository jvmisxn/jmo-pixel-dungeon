class_name Invisibility
extends Buff
## Makes the character invisible to enemies.
## Original: increments target.invisible counter; does NOT boost evasion.
## Broken by attacking, using items, or similar actions via dispel().

const BASE_DURATION: float = 20.0

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
		if MessageLog:
			MessageLog.add_positive("%s fades from view." % target.name)

func on_detach() -> void:
	if target:
		if target.invisible > 0:
			target.invisible -= 1
