class_name BossHPBar
extends CanvasLayer
## Displays a boss name and HP bar at the top-center of the screen during boss fights.
## Renders on CanvasLayer 11 (above HUD layer 10).

# --- Constants ---
const BAR_WIDTH: int = 400
const BAR_HEIGHT: int = 20
const PANEL_HEIGHT: int = 52
const ANIM_DURATION: float = 0.4
const HP_TWEEN_DURATION: float = 0.5

# --- Internal ---
var _panel: PanelContainer = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _boss_name: String = ""
var _max_hp: int = 1
var _current_hp: int = 0
var _hp_tween: Tween = null
var _is_visible: bool = false


func _ready() -> void:
	layer = 11
	_build_ui()
	_panel.visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.name = "BossHPRoot"
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "BossPanel"
	_panel.custom_minimum_size = Vector2(BAR_WIDTH + 40, PANEL_HEIGHT)
	_panel.size = Vector2(BAR_WIDTH + 40, PANEL_HEIGHT)
	_panel.position = Vector2((1280 - BAR_WIDTH - 40) / 2.0, 4)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dark panel style
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.02, 0.02, 0.9)
	panel_style.border_color = Color(0.6, 0.1, 0.1, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	# Boss name label
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	# HP bar
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.1, 0.1)
	fill_style.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.05, 0.05)
	bg_style.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(_hp_bar)

	# HP text label overlaying the bar
	_hp_label = Label.new()
	_hp_label.text = ""
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hp_label)


# --- Public API ---

## Show the boss HP bar with boss name and initial HP values.
func show_boss(boss_name: String, hp: int, max_hp: int) -> void:
	_boss_name = boss_name
	_max_hp = maxi(max_hp, 1)
	_current_hp = hp
	_name_label.text = boss_name
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _current_hp
	_hp_label.text = "%d / %d" % [_current_hp, _max_hp]
	_panel.visible = true
	_is_visible = true
	_play_show_animation()


## Update the current HP with animated bar decrease.
func update_hp(current_hp: int) -> void:
	if not _is_visible:
		return
	var old_hp: int = _current_hp
	_current_hp = clampi(current_hp, 0, _max_hp)
	_hp_label.text = "%d / %d" % [_current_hp, _max_hp]

	# Animate HP bar decrease
	if _hp_tween:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_hp_bar, "value", float(_current_hp), HP_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Flash effect on damage
	if _current_hp < old_hp:
		_flash_damage()

	# Update bar color based on remaining HP ratio
	var ratio: float = float(_current_hp) / float(_max_hp)
	var fill_style: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if ratio > 0.5:
			fill_style.bg_color = Color(0.85, 0.1, 0.1)
		elif ratio > 0.25:
			fill_style.bg_color = Color(0.9, 0.4, 0.1)
		else:
			fill_style.bg_color = Color(0.95, 0.2, 0.2)


## Hide the boss HP bar.
func hide_boss() -> void:
	if not _is_visible:
		return
	_is_visible = false
	_play_hide_animation()


# --- Animations ---

func _play_show_animation() -> void:
	_panel.modulate.a = 0.0
	_panel.position.y = -PANEL_HEIGHT
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, ANIM_DURATION)
	tween.tween_property(_panel, "position:y", 4.0, ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _play_hide_animation() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 0.0, ANIM_DURATION)
	tween.tween_property(_panel, "position:y", -PANEL_HEIGHT, ANIM_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(func() -> void: _panel.visible = false)


func _flash_damage() -> void:
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_panel, "modulate", Color(1.5, 0.5, 0.5), 0.05)
	flash_tween.tween_property(_panel, "modulate", Color.WHITE, 0.15)
