class_name WndInfoMob
extends WndBase
## Mob information window (upstream WndInfoMob): name, health, AI state,
## active buffs, and the mob's description.

var _mob: Variant = null


func _init() -> void:
	window_title = "Mob Info"
	custom_minimum_size = Vector2(320, 160)


func setup(mob: Variant) -> void:
	_mob = mob
	if mob != null:
		window_title = str(mob.mob_name).capitalize() if "mob_name" in mob else "Creature"
	if _title_label:
		_title_label.text = window_title
	refresh_content()


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	if _mob == null:
		return main

	var hp_label: Label = Label.new()
	hp_label.text = "Health: %d / %d" % [int(_mob.hp), int(_mob.ht)]
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.45))
	main.add_child(hp_label)

	var state_text: String = _state_text()
	if not state_text.is_empty():
		var state_label: Label = Label.new()
		state_label.text = state_text
		state_label.add_theme_font_size_override("font_size", 13)
		state_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.6))
		main.add_child(state_label)

	var buff_names: Array[String] = []
	if _mob.has_method("get_buffs"):
		for buff: Variant in _mob.get_buffs():
			if buff != null and "buff_name" in buff:
				buff_names.append(str(buff.buff_name))
	if not buff_names.is_empty():
		var buffs_label: Label = Label.new()
		buffs_label.text = "Affected by: %s" % ", ".join(buff_names)
		buffs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buffs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buffs_label.add_theme_font_size_override("font_size", 12)
		buffs_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		main.add_child(buffs_label)

	var desc: Label = Label.new()
	var desc_text: String = str(_mob.description) if "description" in _mob else ""
	if desc_text.is_empty():
		desc_text = "You know nothing about this creature."
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	main.add_child(desc)
	return main


func _state_text() -> String:
	if _mob == null or not ("state" in _mob):
		return ""
	if _mob.get("is_ally") == true:
		return "This creature fights on your side."
	match int(_mob.state):
		Mob.AIState.SLEEPING: return "This creature is sleeping."
		Mob.AIState.WANDERING: return "This creature is wandering."
		Mob.AIState.HUNTING: return "This creature is hunting."
		Mob.AIState.FLEEING: return "This creature is fleeing."
		Mob.AIState.PASSIVE: return "This creature is passive."
	return ""
