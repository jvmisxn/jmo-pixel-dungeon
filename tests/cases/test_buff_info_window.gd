extends RefCounted
## Tappable buff icon parity (upstream BuffIndicator.BuffButton onClick ->
## WndInfoBuff): the info window titles itself from the buff name, shows the
## buff's description with a fallback, and BuffIcon builds the window from
## its attached buff.


class SilentBuff:
	extends Buff

	func _init() -> void:
		buff_id = "Silent"
		buff_name = "Silent"


func run(t: Object) -> void:
	# --- describe_buff uses description() with a non-empty fallback ---
	var bless := Bless.new()
	t.check(WndInfoBuff.describe_buff(bless).contains("Accuracy"),
		"describe_buff returns the buff's own description text")
	var silent := SilentBuff.new()
	t.check(WndInfoBuff.describe_buff(silent) == WndInfoBuff.FALLBACK_DESC,
		"describe_buff falls back when description() is empty")
	t.check(WndInfoBuff.describe_buff(null) == WndInfoBuff.FALLBACK_DESC,
		"describe_buff handles a null buff")

	# --- setup titles the window from the buff name ---
	var wnd := WndInfoBuff.new()
	wnd.setup(bless)
	t.check(wnd.window_title == "Blessed",
		"WndInfoBuff titles itself from buff_name")
	t.check(wnd._turns_text() == "30 turns remaining",
		"timed buff reports turns remaining")
	wnd.free()

	var wnd_perm := WndInfoBuff.new()
	wnd_perm.setup(silent)
	t.check(wnd_perm._turns_text() == "Lasts until removed",
		"permanent buff reports it lasts until removed")
	wnd_perm.free()

	# --- BuffIcon builds the window from its buff_ref ---
	var icon := BuffIcon.new()
	icon.buff_ref = bless
	var built: WndBase = icon.make_info_window()
	t.check(built is WndInfoBuff and built.window_title == "Blessed",
		"BuffIcon.make_info_window builds a WndInfoBuff for its buff")
	if built:
		built.free()
	icon.buff_ref = null
	t.check(icon.make_info_window() == null,
		"BuffIcon.make_info_window returns null with no buff")
	icon.free()

	bless.free()
	silent.free()
