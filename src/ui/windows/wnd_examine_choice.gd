class_name WndExamineChoice
extends WndBase
## Upstream WndOptions equivalent for GameScene.examineCell(): when several
## things of interest share a cell, list them by name and let the player pick
## which one to examine. Selection emits option_selected and closes; the
## caller (CellExaminer) opens the chosen object's info window.

signal option_selected(index: int)

## Upstream Icons.INFO region in interfaces/icons.png (uvRectBySize 16,32,14,14).
const ICONS_PATH: String = "res://assets/spd/interfaces/icons.png"
const ICON_REGION_INFO: Rect2 = Rect2(16, 32, 14, 14)

var _message: String = ""
var _options: PackedStringArray = []


func _init() -> void:
	window_title = "Choose Examine"
	custom_minimum_size = Vector2(300, 140)


func _ready() -> void:
	super._ready()
	_add_title_info_icon()


## Upstream GameScene.examineCell passes Icons.INFO as the WndOptions title
## icon; mirror that by prefixing the title bar with the same atlas icon.
func _add_title_info_icon() -> void:
	if _title_bar == null:
		return
	var icon: TextureRect = TextureRect.new()
	icon.texture = UIUtils.atlas_texture(ICONS_PATH, ICON_REGION_INFO)
	icon.custom_minimum_size = Vector2(18, 18)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_bar.add_child(icon)
	_title_bar.move_child(icon, 0)


func setup(message: String, options: PackedStringArray) -> void:
	_message = message
	_options = options
	refresh_content()


func _build_content() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)

	var body: Label = Label.new()
	body.text = _message
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	box.add_child(body)

	for i: int in range(_options.size()):
		var btn: Button = WndBase.create_spd_button(_options[i])
		var idx: int = i
		btn.pressed.connect(func() -> void:
			option_selected.emit(idx)
			close_window())
		box.add_child(btn)

	return box
