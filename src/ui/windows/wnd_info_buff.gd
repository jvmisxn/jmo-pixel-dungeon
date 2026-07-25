class_name WndInfoBuff
extends WndBase
## Buff information window (upstream WndInfoBuff): buff icon, title-cased
## buff name, and the buff's description. Opened by tapping a buff icon in
## the status pane (upstream BuffIndicator.BuffButton onClick).

const FALLBACK_DESC: String = "No additional information."

var _buff: Variant = null


func _init() -> void:
	window_title = "Buff Info"
	custom_minimum_size = Vector2(300, 120)


func setup(buff: Variant) -> void:
	_buff = buff
	if buff != null and "buff_name" in buff:
		window_title = str(buff.buff_name).capitalize()
	if _title_label:
		_title_label.text = window_title
	refresh_content()


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	if _buff == null:
		return main

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var icon_rect: TextureRect = _make_icon()
	if icon_rect != null:
		header.add_child(icon_rect)
	var turns_label: Label = Label.new()
	turns_label.text = _turns_text()
	turns_label.add_theme_font_size_override("font_size", 12)
	turns_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	turns_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(turns_label)
	main.add_child(header)

	var desc: Label = Label.new()
	desc.text = describe_buff(_buff)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	main.add_child(desc)
	return main


## Description text for a buff, with a generic fallback so the window is
## never empty (upstream every Buff.desc() is non-empty; port descriptions
## are still being filled in).
static func describe_buff(buff: Variant) -> String:
	if buff != null and buff.has_method("description"):
		var text: String = str(buff.description())
		if not text.is_empty():
			return text
	return FALLBACK_DESC


func _turns_text() -> String:
	var time_left: float = -1.0
	if "time_left" in _buff:
		time_left = _buff.time_left
	if time_left > 0.0:
		return "%d turns remaining" % int(ceil(time_left))
	return "Lasts until removed"


func _make_icon() -> TextureRect:
	var buff_id: String = ""
	if "buff_id" in _buff:
		buff_id = str(_buff.buff_id)
	var region: Rect2 = BuffIcon.icon_region_for_buff_id(buff_id)
	if region.size == Vector2.ZERO:
		return null
	var atlas: AtlasTexture = UIUtils.atlas_texture(BuffIcon.BUFFS_PATH, region)
	if atlas == null or atlas.atlas == null:
		return null
	var rect: TextureRect = TextureRect.new()
	rect.texture = atlas
	rect.custom_minimum_size = Vector2(20, 20)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
