class_name WndTalents
extends WndBase
## Talent management window. Lets the player spend available talent points.

var _hero: Hero = null


func _init() -> void:
	window_title = "Talents"
	custom_minimum_size = Vector2(460, 420)


func _ready() -> void:
	super._ready()
	if EventBus and not EventBus.hero_stats_changed.is_connected(_on_hero_stats_changed):
		EventBus.hero_stats_changed.connect(_on_hero_stats_changed)


func _build_content() -> Control:
	_hero = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	scroll.add_child(main)

	if _hero == null:
		var missing_label: Label = Label.new()
		missing_label.text = "No hero data available."
		main.add_child(missing_label)
		return scroll

	var points_label: Label = Label.new()
	points_label.text = "Available Points: %d" % _hero.talent_points_available
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 16)
	points_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	main.add_child(points_label)

	var hint_label: Label = Label.new()
	hint_label.text = "Spend points to improve your current class talents."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main.add_child(hint_label)

	var talents: Array[TalentData.TalentInfo] = _hero.get_talents() if _hero.has_method("get_talents") else []
	if talents.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No talents available."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		main.add_child(empty_label)
		return scroll

	var current_tier: int = -1
	for talent: TalentData.TalentInfo in talents:
		if talent.tier != current_tier:
			current_tier = talent.tier
			if main.get_child_count() > 2:
				main.add_child(HSeparator.new())
			var tier_label: Label = Label.new()
			tier_label.text = "Tier %d" % current_tier
			tier_label.add_theme_font_size_override("font_size", 15)
			tier_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			main.add_child(tier_label)

		main.add_child(_build_talent_row(talent))

	return scroll


func _build_talent_row(talent: TalentData.TalentInfo) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.10, 0.95)
	style.border_color = Color(0.38, 0.34, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	panel.add_child(body)

	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)

	var title_label: Label = Label.new()
	var current_points: int = _hero.get_talent_level(talent.id)
	title_label.text = "%s  %d/%d" % [talent.name, current_points, talent.max_points]
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	header.add_child(title_label)

	var upgrade_button: Button = WndBase.create_spd_button("+1")
	upgrade_button.custom_minimum_size = Vector2(56, 32)
	upgrade_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	upgrade_button.disabled = not _hero.can_upgrade_talent(talent.id)
	upgrade_button.tooltip_text = "Spend 1 point on %s" % talent.name
	upgrade_button.pressed.connect(_on_upgrade_pressed.bind(talent.id))
	header.add_child(upgrade_button)

	var desc_label: Label = Label.new()
	desc_label.text = talent.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.76, 0.76, 0.76))
	body.add_child(desc_label)

	return panel


func _on_upgrade_pressed(talent_id: String) -> void:
	if _hero == null:
		return
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "upgrade_talent", "talent_id": talent_id})


func _on_hero_stats_changed() -> void:
	if is_inside_tree():
		refresh_content()


func _on_close() -> void:
	if EventBus and EventBus.hero_stats_changed.is_connected(_on_hero_stats_changed):
		EventBus.hero_stats_changed.disconnect(_on_hero_stats_changed)
