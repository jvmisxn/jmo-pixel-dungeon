class_name WndInfoTrap
extends WndBase
## Trap information window (upstream WndInfoTrap): the trap's in-scene glyph
## next to the description, with the upstream inactive prefix line when the
## trap has already been triggered. Upstream shows the trap tile image via
## WndTitledMessage; the port reuses its procedural TrapSprite glyph.

## Upstream windows.properties `windows.wndinfotrap.inactive`.
const INACTIVE_TEXT: String = "This trap is inactive, and can no longer be triggered."
const GLYPH_SCALE: float = 1.6

var _trap: Variant = null
var _desc: String = ""


func _init() -> void:
	window_title = "Trap"
	custom_minimum_size = Vector2(320, 130)


func setup(trap: Variant, desc: String) -> void:
	_trap = trap
	_desc = desc
	if trap != null and "trap_name" in trap:
		window_title = str(trap.trap_name).capitalize()
	if _title_label:
		_title_label.text = window_title
	refresh_content()


func _build_content() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var active: bool = _trap == null or _trap.get("active") != false
	var glyph_holder: Control = Control.new()
	glyph_holder.custom_minimum_size = Vector2(30, 30)
	glyph_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var glyph: TrapSprite = TrapSprite.new()
	var trap_name: String = str(_trap.trap_name) if _trap != null and "trap_name" in _trap else ""
	glyph.setup_for_trap(trap_name, active)
	glyph.position = Vector2(15, 15)
	glyph.scale = Vector2(GLYPH_SCALE, GLYPH_SCALE)
	glyph_holder.add_child(glyph)
	row.add_child(glyph_holder)

	var desc: Label = Label.new()
	var text: String = _desc
	if not active:
		text = INACTIVE_TEXT + "\n\n" + text
	desc.text = text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	row.add_child(desc)
	return row
