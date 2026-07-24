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
var _hp_header: Label = null
var _hp_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_header: Label = null
var _xp_label: Label = null
var _str_label: Label = null
var _depth_label: Label = null
var _level_label: Label = null
var _focus_label: Label = null
var _equip_grid: GridContainer = null
var _buffs_container: HFlowContainer = null
var _hunger_bar: ProgressBar = null
var _hunger_label: Label = null
var _portrait_container: CenterContainer = null
var _hp_section: VBoxContainer = null
var _xp_section: VBoxContainer = null
var _hunger_section: VBoxContainer = null
var _equip_label: Label = null
var _buffs_label: Label = null
var _separator_equipment: HSeparator = null
var _separator_buffs: HSeparator = null
var _compact_strip: HBoxContainer = null
var _compact_level_label: Label = null
var _compact_hp_bar: ProgressBar = null
var _compact_shield_bar: ProgressBar = null
var _compact_hp_label: Label = null
var _compact_xp_bar: ProgressBar = null
var _compact_xp_label: Label = null

# Equipment slot references (ItemSlot components for proper sprite rendering)
var _slot_weapon: ItemSlot = null
var _slot_spirit_bow: ItemSlot = null
var _slot_armor: ItemSlot = null
var _slot_artifact: ItemSlot = null
var _slot_ring_left: ItemSlot = null
var _slot_ring_right: ItemSlot = null
var _slot_misc: ItemSlot = null
var _compact_mode: bool = false

# --- Constants ---
const SLOT_SIZE: Vector2 = Vector2(28, 28)
const BAR_HEIGHT: int = 14
const COMPACT_MINIMUM_SIZE: Vector2 = Vector2(1, 76)
const STATUS_PANE_PATH: String = "res://assets/spd/interfaces/status_pane.png"
const HERO_ICONS_PATH: String = "res://assets/spd/interfaces/hero_icons.png"
const BUFFS_PATH: String = "res://assets/spd/interfaces/buffs.png"
const HERO_AVATARS_PATH: String = "res://assets/spd/sprites/avatars.png"
const HERO_AVATAR_WIDTH: int = 24
const HERO_AVATAR_HEIGHT: int = 32

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


func _get_minimum_size() -> Vector2:
	return COMPACT_MINIMUM_SIZE if _compact_mode else Vector2.ZERO


## Per-frame update for the low-HP warning flash on the hero portrait.
## Matches original StatusPane.java update() warning interpolation.
func _process(delta: float) -> void:
	var hero: Variant = _get_hero()
	if not hero:
		return
	var hp: int = hero.hp
	var hp_max: int = hero.hp_max
	var is_alive: bool = hero.is_alive

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
	_portrait_container = CenterContainer.new()
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

	# ColorRect background for warning flash tinting
	_portrait_fallback = ColorRect.new()
	_portrait_fallback.custom_minimum_size = Vector2(48, 60)
	_portrait_fallback.color = Color(0.1, 0.09, 0.08)
	portrait_panel.add_child(_portrait_fallback)

	# Hero sprite from class sprite sheet (12x15 scaled up with nearest filter)
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(48, 60)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_fallback.add_child(_portrait_rect)

	# Fallback class name label (shown only if sprite sheet is missing)
	_class_label = Label.new()
	_class_label.text = ""
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_class_label.add_theme_font_size_override("font_size", 11)
	_class_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_class_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_fallback.add_child(_class_label)

	_portrait_container.add_child(portrait_panel)
	add_child(_portrait_container)

	# --- Level Label ---
	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	add_child(_level_label)

	_focus_label = Label.new()
	_focus_label.text = ""
	_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_label.add_theme_font_size_override("font_size", 10)
	_focus_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.92))
	add_child(_focus_label)

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
	_separator_equipment = HSeparator.new()
	_separator_equipment.modulate = Color(0.5, 0.45, 0.35)
	add_child(_separator_equipment)

	# --- Equipment Slots ---
	_equip_label = Label.new()
	_equip_label.text = "Equipment"
	_equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equip_label.add_theme_font_size_override("font_size", 11)
	_equip_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	add_child(_equip_label)

	_equip_grid = GridContainer.new()
	_equip_grid.columns = 4
	_equip_grid.add_theme_constant_override("h_separation", 4)
	_equip_grid.add_theme_constant_override("v_separation", 4)

	_slot_weapon = _create_item_slot("Weapon")
	_slot_spirit_bow = _create_item_slot("Bow")
	_slot_armor = _create_item_slot("Armor")
	_slot_artifact = _create_item_slot("Artifact")
	_slot_ring_left = _create_item_slot("Ring L")
	_slot_ring_right = _create_item_slot("Ring R")
	_slot_misc = _create_item_slot("Misc")

	_equip_grid.add_child(_slot_weapon)
	_equip_grid.add_child(_slot_spirit_bow)
	_equip_grid.add_child(_slot_armor)
	_equip_grid.add_child(_slot_artifact)
	_equip_grid.add_child(_slot_ring_left)
	_equip_grid.add_child(_slot_ring_right)
	_equip_grid.add_child(_slot_misc)
	add_child(_equip_grid)

	# --- Separator ---
	_separator_buffs = HSeparator.new()
	_separator_buffs.modulate = Color(0.5, 0.45, 0.35)
	add_child(_separator_buffs)

	# --- Active Buffs ---
	_buffs_label = Label.new()
	_buffs_label.text = "Buffs"
	_buffs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buffs_label.add_theme_font_size_override("font_size", 11)
	_buffs_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	add_child(_buffs_label)

	_buffs_container = HFlowContainer.new()
	_buffs_container.name = "BuffsContainer"
	_buffs_container.add_theme_constant_override("h_separation", 2)
	_buffs_container.add_theme_constant_override("v_separation", 2)
	add_child(_buffs_container)

	_build_compact_strip()


func _build_compact_strip() -> void:
	_compact_strip = HBoxContainer.new()
	_compact_strip.visible = false
	_compact_strip.custom_minimum_size = COMPACT_MINIMUM_SIZE
	_compact_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_compact_strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	_compact_strip.add_theme_constant_override("separation", 8)

	_compact_level_label = Label.new()
	_compact_level_label.text = "Lv. 1"
	_compact_level_label.custom_minimum_size = Vector2(58, 0)
	_compact_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_compact_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compact_level_label.add_theme_font_size_override("font_size", 18)
	_compact_level_label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.62))
	_compact_strip.add_child(_compact_level_label)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.custom_minimum_size = Vector2(1, 64)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 6)
	_compact_strip.add_child(bars)

	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_theme_constant_override("separation", 6)
	bars.add_child(hp_row)

	var hp_bar_container: Control = Control.new()
	hp_bar_container.custom_minimum_size = Vector2(0, 22)
	hp_bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_bar_container)

	_compact_shield_bar = ProgressBar.new()
	_compact_shield_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_compact_shield_bar.show_percentage = false
	var compact_shield_fill := StyleBoxFlat.new()
	compact_shield_fill.bg_color = Color(0.85, 0.78, 0.35)
	compact_shield_fill.set_corner_radius_all(2)
	_compact_shield_bar.add_theme_stylebox_override("fill", compact_shield_fill)
	var compact_shield_bg := StyleBoxFlat.new()
	compact_shield_bg.bg_color = Color(0.15, 0.05, 0.05)
	compact_shield_bg.border_color = Color(0.4, 0.2, 0.2)
	compact_shield_bg.set_border_width_all(1)
	compact_shield_bg.set_corner_radius_all(2)
	_compact_shield_bar.add_theme_stylebox_override("background", compact_shield_bg)
	hp_bar_container.add_child(_compact_shield_bar)

	_compact_hp_bar = ProgressBar.new()
	_compact_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_compact_hp_bar.show_percentage = false
	var compact_hp_fill := StyleBoxFlat.new()
	compact_hp_fill.bg_color = Color(0.78, 0.16, 0.16)
	compact_hp_fill.set_corner_radius_all(2)
	_compact_hp_bar.add_theme_stylebox_override("fill", compact_hp_fill)
	var compact_hp_bg := StyleBoxFlat.new()
	compact_hp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	compact_hp_bg.set_corner_radius_all(2)
	_compact_hp_bar.add_theme_stylebox_override("background", compact_hp_bg)
	hp_bar_container.add_child(_compact_hp_bar)

	_compact_hp_label = Label.new()
	_compact_hp_label.text = "20/20"
	_compact_hp_label.custom_minimum_size = Vector2(72, 0)
	_compact_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_compact_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_compact_hp_label.add_theme_font_size_override("font_size", 16)
	_compact_hp_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.72))
	hp_row.add_child(_compact_hp_label)

	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_theme_constant_override("separation", 6)
	bars.add_child(xp_row)

	_compact_xp_bar = ProgressBar.new()
	_compact_xp_bar.custom_minimum_size = Vector2(0, 18)
	_compact_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_xp_bar.show_percentage = false
	var compact_xp_fill := StyleBoxFlat.new()
	compact_xp_fill.bg_color = Color(0.2, 0.55, 0.85)
	compact_xp_fill.set_corner_radius_all(2)
	_compact_xp_bar.add_theme_stylebox_override("fill", compact_xp_fill)
	var compact_xp_bg := StyleBoxFlat.new()
	compact_xp_bg.bg_color = Color(0.05, 0.1, 0.18)
	compact_xp_bg.border_color = Color(0.2, 0.3, 0.45)
	compact_xp_bg.set_border_width_all(1)
	compact_xp_bg.set_corner_radius_all(2)
	_compact_xp_bar.add_theme_stylebox_override("background", compact_xp_bg)
	xp_row.add_child(_compact_xp_bar)

	_compact_xp_label = Label.new()
	_compact_xp_label.text = "0/10"
	_compact_xp_label.custom_minimum_size = Vector2(72, 0)
	_compact_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_compact_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_compact_xp_label.add_theme_font_size_override("font_size", 14)
	_compact_xp_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.96))
	xp_row.add_child(_compact_xp_label)

	add_child(_compact_strip)


func _build_hp_section() -> void:
	_hp_section = VBoxContainer.new()
	_hp_section.add_theme_constant_override("separation", 1)
	_hp_header = Label.new()
	_hp_header.text = "HP"
	_hp_header.add_theme_font_size_override("font_size", 10)
	_hp_header.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	_hp_section.add_child(_hp_header)

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

	_hp_section.add_child(hp_bar_container)

	_hp_label = Label.new()
	_hp_label.text = "20 / 20"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	_hp_section.add_child(_hp_label)
	add_child(_hp_section)


func _build_xp_section() -> void:
	_xp_section = VBoxContainer.new()
	_xp_section.add_theme_constant_override("separation", 1)
	_xp_header = Label.new()
	_xp_header.text = "XP"
	_xp_header.add_theme_font_size_override("font_size", 10)
	_xp_header.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8))
	_xp_section.add_child(_xp_header)

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
	_xp_section.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.text = "0 / 10"
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 11)
	_xp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_xp_section.add_child(_xp_label)
	add_child(_xp_section)


func _build_hunger_section() -> void:
	_hunger_section = VBoxContainer.new()
	_hunger_section.add_theme_constant_override("separation", 1)
	var hunger_header := Label.new()
	hunger_header.text = "Hunger"
	hunger_header.add_theme_font_size_override("font_size", 10)
	hunger_header.add_theme_color_override("font_color", Color(0.4, 0.7, 0.3))
	_hunger_section.add_child(hunger_header)

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
	_hunger_section.add_child(_hunger_bar)

	_hunger_label = Label.new()
	_hunger_label.text = "Satisfied"
	_hunger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hunger_label.add_theme_font_size_override("font_size", 10)
	_hunger_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.4))
	_hunger_section.add_child(_hunger_label)
	add_child(_hunger_section)


func set_compact_mode(is_compact: bool) -> void:
	if _compact_mode == is_compact:
		return
	_compact_mode = is_compact
	custom_minimum_size = Vector2.ZERO
	add_theme_constant_override("separation", 2 if _compact_mode else 6)
	if _level_label:
		_level_label.visible = not _compact_mode
		_level_label.add_theme_font_size_override("font_size", 16 if _compact_mode else 13)
	if _compact_strip:
		_compact_strip.visible = _compact_mode
		_compact_strip.custom_minimum_size = COMPACT_MINIMUM_SIZE
		_compact_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_compact_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _portrait_container:
		_portrait_container.visible = not _compact_mode
	if _focus_label:
		_focus_label.visible = false if _compact_mode else _focus_label.visible
	if _str_label:
		_str_label.visible = not _compact_mode
		_str_label.add_theme_font_size_override("font_size", 12 if _compact_mode else 11)
	if _depth_label:
		_depth_label.visible = not _compact_mode
		_depth_label.add_theme_font_size_override("font_size", 12 if _compact_mode else 11)
	if _separator_equipment:
		_separator_equipment.visible = not _compact_mode
	if _equip_label:
		_equip_label.visible = not _compact_mode
	if _equip_grid:
		_equip_grid.visible = not _compact_mode
	if _separator_buffs:
		_separator_buffs.visible = not _compact_mode
	if _buffs_label:
		_buffs_label.visible = not _compact_mode
	if _buffs_container:
		_buffs_container.visible = not _compact_mode
	if _hp_section:
		_hp_section.visible = not _compact_mode
		_hp_section.add_theme_constant_override("separation", 1)
	if _hp_header:
		_hp_header.add_theme_font_size_override("font_size", 11 if _compact_mode else 10)
	if _hp_label:
		_hp_label.visible = true
		_hp_label.add_theme_font_size_override("font_size", 12 if _compact_mode else 11)
	if _xp_section:
		_xp_section.visible = not _compact_mode
		_xp_section.add_theme_constant_override("separation", 1)
	if _xp_header:
		_xp_header.add_theme_font_size_override("font_size", 11 if _compact_mode else 10)
	if _xp_label:
		_xp_label.visible = true
		_xp_label.add_theme_font_size_override("font_size", 12 if _compact_mode else 11)
	if _hunger_section:
		_hunger_section.visible = not _compact_mode
	update_minimum_size()
	queue_sort()


# ---------------------------------------------------------------------------
# Missing Methods
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	var event_bus: Node = EventBus
	if event_bus:
		event_bus.hero_stats_changed.connect(_on_hero_stats_changed)
		event_bus.item_equipped.connect(_on_item_equipped)
		event_bus.item_unequipped.connect(_on_item_unequipped)


func _on_hero_stats_changed() -> void:
	update_all()


func _on_item_equipped(_item_name: String, _slot: String) -> void:
	_update_equipment()


func _on_item_unequipped(_item_name: String, _slot: String) -> void:
	_update_equipment()


func _get_hero() -> Variant:
	if GameManager == null:
		return null
	return GameManager.get_local_hero() if GameManager.has_method("get_local_hero") else GameManager.hero


func _create_item_slot(tooltip: String) -> ItemSlot:
	var slot: ItemSlot = ItemSlot.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	slot.tooltip_text = tooltip
	return slot


## Refresh all status pane elements from current hero state.
func update_all() -> void:
	var hero: Variant = _get_hero()
	if not hero:
		return

	# HP
	var hp: int = hero.hp
	var hp_max: int = hero.hp_max
	if _hp_bar:
		_hp_bar.max_value = hp_max
		_hp_bar.value = hp
	if _hp_label:
		_hp_label.text = "%d / %d" % [hp, hp_max]
	if _compact_hp_bar:
		_compact_hp_bar.max_value = hp_max
		_compact_hp_bar.value = hp
	if _compact_hp_label:
		_compact_hp_label.text = "%d/%d" % [hp, hp_max]

	# Shielding (barrier buff)
	var shield: int = hero.shielding
	if _shield_bar:
		_shield_bar.max_value = hp_max
		_shield_bar.value = hp + shield
	if _compact_shield_bar:
		_compact_shield_bar.max_value = hp_max
		_compact_shield_bar.value = hp + shield

	# XP
	var xp: int = hero.xp
	var xp_max: int = hero.xp_to_next
	var hero_level: int = hero.hero_level
	if _xp_bar:
		_xp_bar.max_value = xp_max
		_xp_bar.value = xp
	if _xp_label:
		_xp_label.text = "%d / %d" % [xp, xp_max]
	if _level_label:
		_level_label.text = "Lv. %d" % hero_level
	if _compact_xp_bar:
		_compact_xp_bar.max_value = xp_max
		_compact_xp_bar.value = xp
	if _compact_xp_label:
		_compact_xp_label.text = "%d/%d" % [xp, xp_max]
	if _compact_level_label:
		_compact_level_label.text = "Lv.%d" % hero_level
	if _focus_label:
		_focus_label.visible = false
		if not _compact_mode and GameManager and GameManager.has_method("is_party_run") and GameManager.is_party_run() and GameManager.has_method("get_hero_index"):
			var hero_index: int = GameManager.get_hero_index(hero)
			if hero_index >= 0:
				var focus_text: String = "Focus: P%d/%d" % [hero_index + 1, GameManager.heroes.size()]
				if GameManager.has_method("is_local_player_spectating") and GameManager.is_local_player_spectating():
					focus_text += "  Spectating"
				elif hero.get("is_alive") != true:
					focus_text += "  Down"
				_focus_label.text = focus_text
				_focus_label.visible = true

	# STR
	var hero_str: int = hero.str_val
	if _str_label:
		_str_label.text = "STR: %d" % hero_str

	# Depth
	if _depth_label and GameManager:
		_depth_label.text = "Depth: %d" % GameManager.depth

	# Hero portrait sprite
	_update_portrait()

	# Hunger
	_update_hunger(hero)

	# Buffs
	_update_buffs(hero)

	# Equipment
	_update_equipment()


func _update_hunger(hero: Variant) -> void:
	var hunger_val: float = 0.0
	var hunger_level_name: String = "Satisfied"
	var hunger_buff: Variant = hero.get_buff("Hunger") if hero.has_method("get_buff") else null
	if hunger_buff and hunger_buff.get("hunger_value") != null:
		hunger_val = float(hunger_buff.hunger_value)

	if hunger_val <= 0.0:
		hunger_level_name = "Satisfied"
	elif hunger_val < ConstantsData.MAX_HUNGER * 0.5:
		hunger_level_name = "Normal"
	elif hunger_val < ConstantsData.MAX_HUNGER * 0.8:
		hunger_level_name = "Hungry"
	else:
		hunger_level_name = "Starving"

	if _hunger_bar:
		_hunger_bar.value = ConstantsData.MAX_HUNGER - hunger_val
	if _hunger_label:
		_hunger_label.text = hunger_level_name
		if hunger_level_name == "Starving":
			_hunger_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		elif hunger_level_name == "Hungry":
			_hunger_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		else:
			_hunger_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.4))


func _update_buffs(hero: Variant) -> void:
	if not _buffs_container:
		return
	# Clear existing buff icons
	for child: Node in _buffs_container.get_children():
		_buffs_container.remove_child(child)
		child.queue_free()
	# Add current buffs
	var buffs: Array = hero.get_buffs() if hero.has_method("get_buffs") else []
	for buff: Variant in buffs:
		if buff is Buff and not (buff as Buff).show_in_ui:
			continue
		var icon: BuffIcon = BuffIcon.new()
		icon.buff_ref = buff as Node
		icon.update_flash_state()
		_buffs_container.add_child(icon)


func _update_equipment() -> void:
	var hero: Variant = _get_hero()
	if not hero:
		return
	var belongings: Variant = hero.belongings
	if not belongings:
		return

	# Access equipment properties directly (weapon, armor, artifact, ring_left, ring_right, misc)
	_set_slot_item(_slot_weapon, belongings.weapon if "weapon" in belongings else null)
	_set_slot_item(_slot_spirit_bow, belongings.spirit_bow if "spirit_bow" in belongings else null)
	_set_slot_item(_slot_armor, belongings.armor if "armor" in belongings else null)
	_set_slot_item(_slot_artifact, belongings.artifact if "artifact" in belongings else null)
	_set_slot_item(_slot_ring_left, belongings.ring_left if "ring_left" in belongings else null)
	_set_slot_item(_slot_ring_right, belongings.ring_right if "ring_right" in belongings else null)
	_set_slot_item(_slot_misc, belongings.misc if "misc" in belongings else null)


func _set_slot_item(slot: ItemSlot, item: Variant) -> void:
	if not slot:
		return
	slot.item = item  # null clears the slot, valid item draws the icon


## Extract the hero's portrait from the SPD avatar sheet and display it.
func _update_portrait() -> void:
	if not _portrait_rect:
		return
	var hero: Variant = _get_hero()
	var class_idx: int = hero.hero_class if hero != null and hero.get("hero_class") != null else (GameManager.hero_class if GameManager else 0)
	if class_idx < 0:
		# Fallback: show class name text
		if _class_label:
			_class_label.text = HeroClassData.get_class_name_str(class_idx).left(3) if GameManager else "???"
		return
	if not ResourceLoader.exists(HERO_AVATARS_PATH):
		if _class_label:
			_class_label.text = HeroClassData.get_class_name_str(class_idx).left(3)
		return
	var sheet: Texture2D = load(HERO_AVATARS_PATH) as Texture2D
	if sheet == null or sheet.get_width() < HERO_AVATAR_WIDTH * (class_idx + 1):
		if _class_label:
			_class_label.text = HeroClassData.get_class_name_str(class_idx).left(3)
		return
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(class_idx * HERO_AVATAR_WIDTH, 0, HERO_AVATAR_WIDTH, HERO_AVATAR_HEIGHT)
	_portrait_rect.texture = atlas
	# Hide fallback text since we have a real sprite
	if _class_label:
		_class_label.text = ""
