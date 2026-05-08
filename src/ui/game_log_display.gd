class_name GameLogDisplay
extends ScrollContainer
## Left panel displaying the scrollable message log.
## Groups messages by turn and auto-scrolls to the latest entry.
## Connects to MessageLog.message_added signal for reactive updates.

# --- Constants ---
const MAX_VISIBLE_MESSAGES: int = 20
const MESSAGE_FONT_SIZE: int = 11
const TURN_HEADER_FONT_SIZE: int = 10

# --- Internal ---
var _vbox: VBoxContainer = null
var _last_turn_shown: int = -1
var _auto_scroll: bool = true


func _ready() -> void:
	name = "GameLogDisplay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_vbox = VBoxContainer.new()
	_vbox.name = "LogEntries"
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)

	_connect_signals()
	# Load existing messages on start
	refresh()


func _connect_signals() -> void:
	var message_log: Node = UIUtils.get_autoload("MessageLog")
	if message_log:
		message_log.message_added.connect(_on_message_added)
		if message_log.has_signal("log_cleared"):
			message_log.log_cleared.connect(_on_log_cleared)


# --- Public API ---

## Rebuild the log display from scratch using the most recent messages.
func refresh() -> void:
	_clear_display()
	_last_turn_shown = -1

	var message_log: Node = UIUtils.get_autoload("MessageLog")
	if not message_log:
		return

	var recent: Array = message_log.get_recent(MAX_VISIBLE_MESSAGES)
	for entry: Dictionary in recent:
		_append_entry(entry)

	_scroll_to_bottom()


# --- Internal Methods ---

func _on_message_added(entry: Dictionary) -> void:
	_append_entry(entry)
	_prune_old_messages()
	_scroll_to_bottom()


func _on_log_cleared() -> void:
	_clear_display()
	_last_turn_shown = -1


func _append_entry(entry: Dictionary) -> void:
	var turn: int = entry.get("turn", 0)
	var text: String = entry.get("text", "")
	var color: Color = entry.get("color", Color.WHITE)

	# Add turn header if this is a new turn
	if turn != _last_turn_shown:
		_last_turn_shown = turn
		var turn_header := Label.new()
		turn_header.text = "--- Turn %d ---" % turn
		turn_header.add_theme_font_size_override("font_size", TURN_HEADER_FONT_SIZE)
		turn_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		turn_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(turn_header)

	# Add message as RichTextLabel for color support
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.custom_minimum_size = Vector2(0, 0)
	rtl.add_theme_font_size_override("normal_font_size", MESSAGE_FONT_SIZE)

	# Format with color
	var color_hex: String = color.to_html(false)
	rtl.text = "[color=#%s]%s[/color]" % [color_hex, text]

	_vbox.add_child(rtl)


func _prune_old_messages() -> void:
	# Keep only the last MAX_VISIBLE_MESSAGES * 2 children (messages + headers)
	var max_children: int = MAX_VISIBLE_MESSAGES * 2
	while _vbox.get_child_count() > max_children:
		var child: Node = _vbox.get_child(0)
		_vbox.remove_child(child)
		child.queue_free()


func _clear_display() -> void:
	for child: Node in _vbox.get_children():
		child.queue_free()


func _scroll_to_bottom() -> void:
	if not _auto_scroll:
		return
	# Defer scroll to allow layout to update
	await get_tree().process_frame
	var v_scroll: VScrollBar = get_v_scroll_bar()
	if v_scroll:
		v_scroll.value = v_scroll.max_value


# --- Utilities ---
# _get_autoload removed — use UIUtils.get_autoload() instead
