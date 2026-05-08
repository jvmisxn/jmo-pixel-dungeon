class_name StatusPane
extends VBoxContainer
## Sidebar status panel showing hero portrait, HP/XP bars, stats, equipment, and buffs.
## Styled to match original SPD's status_pane.png aesthetic — dark stone background
## with warm-toned borders, red HP bars, and blue XP bars.
## Updates reactively via EventBus.hero_stats_changed signal.

# --- UI References ---
var _portrait_rect: TextureRect = null
var _portrait_fallback: ColorRect = null
var _class_label: Label = null
var _hp_bar: ProgressBar = null
var _shield_bar: ProgressBar = null  # Overlay for shielding (yellow tint)
var _hp_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_label: Label = null
var _str_label: Label = null
var _depth_label: Label = null
var _level_label: Label = null
var _equip_grid: GridContainer = null
var _buffs_container: HFlowContainer = null
var _hunger_bar: ProgressBar = null
var _hunger_label: Label = null

# Equipment slot references
var _slot_weapon: Panel = null
var _slot_armor: Panel = null
var _slot_artifact: Panel = null
var _slot_ring_left: Panel = null
var _slot_ring_right: Panel = null
var _slot_misc: Panel = null

# --- Constants ---
const SLOT_SIZE: Vector2 = Vector2(28, 28)
const BAR_HEIGHT: int = 14
const BUFF_ICON_SIZE: Vector2 = Vector2(16, 16)
const STATUS_PANE_PATH: String = "res://assets/spd/interfaces/status_pane.png"
const HERO_ICONS_PATH: String = "res://assets/spd/interfaces/hero_icons.png"
const BUFFS_PATH: String = "res://assets/spd/interfaces/buffs.png"

## Low HP warning flash state — matches original StatusPane.java warning colors.
## Original uses warningColors = [0x660000, 0xCC0000, 0x660000] and cycles
## via `warning += elapsed * 5f * (0.4f - hp_ratio)`.
var _warning: float = 0.0
const WARNING_COLORS: Array[Color] = [
	Color(0.4, 0.0, 0.0),   # 0x660000 — dark red
	Color(0.8, 0.0, 0.0),   # 0xCC0000 — bright red
	Color(0.4, 0.0, 0.0),   # 0x660000 — dark red (loops)
]


func _ready() -> void:
	name = "StatusPane"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 6)
	_build_ui()
	_connect_signals()
	update_all()


## Per-frame update for the low-HP warning flash on the hero portrait.
## Matches original StatusPane.java update() warning interpolation.
func _process(delta: float) -> void:
	var hero: Node = _get_hero()
	if not hero:
		return
	var hp: int = hero.get("hp") if hero.get("hp") != null else 1
	var hp_max: int = hero.get("hp_max") if hero.get("hp_max") != null else 1
	var is_alive: bool = hero.get("is_alive") if hero.get("is_alive") != null else true

	if not is_alive:
		# Dead — tint portrait dark
		_portrait_fallback.modulate = Color(0.5, 0.5, 0.5)
	elif hp_max > 0 and float(hp) / float(hp_max) < 0.334:
		# Low HP — flash portrait between dark/bright red
		# Original: warning += elapsed * 5f * (0.4f - hp_ratio)
		var hp_ratio: float = float(hp) / float(hp_max)
		_warning += delta * 5.0 * (0.4 - hp_ratio)
		_warning = fmod(_warning, 1.0)
		# Interpolate: 0→0.5 = dark→bright, 0.5→1.0 = bright→dark
		var t: float = _warning * 2.0
		var flash_color: Color
		if t <= 1.0:
			flash_color = WARNING_COLORS[0].lerp(WARNING_COLORS[1], t)
		else:
			flash_color = WARNING_COLORS[1].lerp(WARNING_COLORS[2], t - 1.0)
		_portrait_fallback.modulate = Color(1.0, 1.0, 1.0).lerp(flash_color, 0.5)
	else:
		# Healthy — reset tint
		_portrait_fallback.modulate = Color.WHITE


func _build_ui() -> void:
	# --- Panel background style for the whole sidebar ---
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	panel_bg.border_color = Color(0.35, 0.3, 0.25)
	panel_bg.set_border_width_all(1)
	panel_bg.content_margin_left = 8.0
	panel_bg.content_margin_right = 8.0
	panel_bg.content_margin_top = 8.0
	panel_bg.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", panel_bg)

	# --- Hero Portrait ---
	var portrait_container := CenterContainer.new()
	# Try loading hero icon from sprite sheet
	_portrait_fallback = ColorRect.new()
	_portrait_fallback.custom_minimum_size = Vector2(48, 48)
	_portrait_fallback.color = Color(0.3, 0.5, 0.8)
	# Stone border around portrait
	var portrait_panel := PanelContainer.new()
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.1, 0.09, 0.08)
	portrait_style.border_color = Color(0.5, 0.45, 0.35)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(2)
	portrait_style.content_margin_left = 2.0
	portrait_style.content_margin_right = 2.0
	portrait_style.content_margin_top = 2.0
	portrait_style.content_margin_bottom = 2.0
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	portrait_panel.add_child(_portrait_fallback)

	_class_label = Label.new()
	_class_label.text = "Warrior"
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_class_label.add_theme_font_size_override("font_size", 11)
	_class_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_class_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_fallback.add_child(_class_label)

	portrait_container.add_child(portrait_panel)
	add_child(portrait_container)

	# --- Level Label ---
	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	add_child(_level_label)

	# --- HP Bar ---
	_build_hp_section()

	# --- XP Bar ---
	_build_xp_section()

	# --- Hunger Bar ---
	_build_hunger_section()

	# --- STR Display ---
	_str_label = Label.new()
	_str_label.text = "STR: 10"
	_str_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_str_label.add_theme_font_size_override("font_size", 12)
	_str_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	add_child(_str_label)

	# --- Depth Display ---
	_depth_label = Label.new()
	_depth_label.text = "Depth: 1"
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_label.add_theme_font_size_override("font_size", 12)
	_depth_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(_depth_label)

	# --- Separator ---
	var sep := HSeparator.new()
	sep.modulate = Color(0.5, 0.45, 0.35)
	add_child(sep)

	# --- Equipment Slots ---
	var equip_label := Label.new()
	equip_label.text = "Equipment"
	equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_label.add_theme_font_size_override("font_size", 11)
	equip_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	add_child(equip_label)

	_equip_grid = GridContainer.new()
	_equip_grid.columns = 3
	_equip_grid.add_theme_constant_override("h_separation", 4)
	_equip_grid.add_theme_constant_override("v_separation", 4)

	_slot_weapon = _create_equip_slot("Wpn")
	_slot_armor = _create_equip_slot("Arm")
	_slot_artifact = _create_equip_slot("Art")
	_slot_ring_left = _create_equip_slot("R-L")
	_slot_ring_right = _create_equip_slot("R-R")
	_slot_misc = _create_equip_slot("Msc")

	_equip_grid.add_child(_slot_weapon)
	_equip_grid.add_child(_slot_armor)
	_equip_grid.add_child(_slot_artifact)
	_equip_grid.add_child(_slot_ring_left)
	_equip_grid.add_child(_slot_ring_right)
	_equip_grid.add_child(_slot_misc)
	add_child(_equip_grid)

	# --- Separator ---
	var sep2 := HSeparator.new()
	sep2.modulate = Color(0.5, 0.45, 0.35)
	add_child(sep2)

	# --- Active Buffs ---
	var buffs_label := Label.new()
	buffs_label.text = "Buffs"
	buffs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buffs_label.add_theme_font_size_override("font_size", 11)
	buffs_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	add_child(buffs_label)

	_buffs_container = HFlowContainer.new()
	_buffs_container.add_theme_constant_override("h_separation", 2)
	_buffs_container.add_theme_constant_override("v_separation", 2)
	add_child(_buffs_container)


func _build_hp_section() -> void:
	var hp_section := VBoxContainer.new()
	hp_section.add_theme_constant_override("separation", 1)
	var hp_header := Label.new()
	hp_header.text = "HP"
	hp_header.add_theme_font_size_override("font_size", 10)
	hp_header.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	hp_section.add_child(hp_header)

	# Layered container for HP + shield bars (shield draws behind HP)
	var hp_bar_container := Control.new()
	hp_bar_container.custom_minimum_size = Vector2(0, BAR_HEIGHT)

	# Shield bar (drawn behind HP bar — yellow/white tint)
	_shield_bar = ProgressBar.new()
	_shield_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shield_bar.max_value = 20
	_shield_bar.value = 0
	_shield_bar.show_percentage = false
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.85, 0.78, 0.35)  # Yellow shield overlay
	shield_fill.set_corner_radius_all(1)
	_shield_bar.add_theme_stylebox_override("fill", shield_fill)
	var shield_bg := StyleBoxFlat.new()
	shield_bg.bg_color = Color(0.15, 0.05, 0.05)
	shield_bg.border_color = Color(0.4, 0.2, 0.2)
	shield_bg.set_border_width_all(1)
	shield_bg.set_corner_radius_all(1)
	_shield_bar.add_theme_stylebox_override("background", shield_bg)
	hp_bar_container.add_child(_shield_bar)

	# HP bar (drawn on top of shield bar — red)
	_hp_bar = ProgressBar.new()
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_bar.max_value = 20
	_hp_bar.value = 20
	_hp_bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.75, 0.15, 0.15)
	hp_fill.set_corner_radius_all(1)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)  # Transparent — shield bar shows through
	hp_bg.set_corner_radius_all(1)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_bar_container.add_child(_hp_bar)

	hp_section.add_child(hp_bar_container)

	_hp_label = Label.new()
	_hp_label.text = "20 / 20"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	hp_section.add_child(_hp_label)
	add_child(hp_section)


func _build_xp_section() -> void:
	var xp_section := VBoxContainer.new()
	xp_section.add_theme_constant_override("separation", 1)
	var xp_header := Label.new()
	xp_header.text = "XP"
	xp_header.add_theme_font_size_override("font_size", 10)
	xp_header.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8))
	xp_section.add_child(xp_header)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT - 4)
	_xp_bar.max_value = 10
	_xp_bar.value = 0
	_xp_bar.show_percentage = false

	# SPD-style blue/cyan XP bar
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.2, 0.55, 0.85)
	xp_fill.set_corner_radius_all(1)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.05, 0.1, 0.18)
	xp_bg.border_color = Color(0.2, 0.3, 0.45)
	xp_bg.set_border_width_all(1)
	xp_bg.set_corner_radius_all(1)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_section.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.text = "0 / 10"
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 11)
	_xp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	xp_section.add_child(_xp_label)
	add_child(xp_section)


func _build_hunger_section() -> void:
	var hunger_section := VBoxContainer.new()
	hunger_section.add_theme_constant_override("separation", 1)
	var hunger_header := Label.new()
	hunger_header.text = "Hunger"
	hunger_header.add_theme_font_size_override("font_size", 10)
	hunger_header.add_theme_color_override("font_color", Color(0.4, 0.7, 0.3))
	hunger_section.add_child(hunger_header)

	_hunger_bar = ProgressBar.new()
	_hunger_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT - 4)
	_hunger_bar.max_value = ConstantsData.MAX_HUNGER
	_hunger_bar.value = 0
	_hunger_bar.show_percentage = false

	# SPD-style green hunger bar
	var hunger_fill := StyleBoxFlat.new()
	hunger_fill.bg_color = Color(0.2, 0.7, 0.2)
	hunger_fill.set_corner_radius_all(1)
	_hunger_bar.add_theme_stylebox_override("fill", hunger_fill)
	var hunger_bg := StyleBoxFlat.new()
	hunger_bg.bg_color = Color(0.08, 0.12, 0.05)
	hunger_bg.border_color = Color(0.2, 0.35, 0.15)
	hunger_bg.set_border_width_all(1)
	hunger_bg.set_corner_radius_all(1)
	_hunger_bar.add_theme_stylebox_override("background", hunger_bg)
	hunger_section.add_child(_hunger_bar)

	_hunger_label = Label.new()
	_hunger_label.text = "Satisfied"
	_hunger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hunger_label.add_theme_font_size_override("font_size", 10)
	_hunger_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.4))
	hunger_section.add_child(_hunger_label)
	add_child(hunger_section)
