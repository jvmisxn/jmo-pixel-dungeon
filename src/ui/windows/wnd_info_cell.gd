class_name WndInfoCell
extends WndBase
## Simple examine info window: a title plus a block of descriptive text.
## Used for terrain, traps, plants, and heaps inspected via examine mode
## (upstream WndInfoCell / WndInfoTrap / WndInfoPlant equivalents).

var _text: String = ""


func _init() -> void:
	window_title = "Examine"
	custom_minimum_size = Vector2(300, 120)


func setup(title: String, text: String) -> void:
	window_title = title
	_text = text
	if _title_label:
		_title_label.text = title
	refresh_content()


func _build_content() -> Control:
	var body: Label = Label.new()
	body.text = _text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	return body
