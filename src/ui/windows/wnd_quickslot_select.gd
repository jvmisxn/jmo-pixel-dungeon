class_name WndQuickslotSelect
extends WndBase
## Small selector window for assigning an item to one of the HUD quickslots.

var _hero: Hero = null
var _item: Item = null

func _init() -> void:
	window_title = "Quickslot"
	custom_minimum_size = Vector2(300, 240)

func setup(hero: Hero, item: Item) -> void:
	_hero = hero
	_item = item

func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = "Assign %s to a quickslot" % ConstantsData.get_prop(_item, "item_name", "item")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(label)

	for i: int in range(Belongings.QUICKSLOT_COUNT):
		var btn: Button = create_spd_button(_slot_label(i))
		btn.pressed.connect(_assign_slot.bind(i))
		main.add_child(btn)

	if _hero != null and _hero.belongings != null and _hero.belongings.has_method("get_quickslot_index"):
		var idx: int = _hero.belongings.get_quickslot_index(_item)
		if idx >= 0:
			var clear_btn: Button = create_spd_button("Clear current assignment")
			clear_btn.pressed.connect(_clear_assignment)
			main.add_child(clear_btn)

	return main

func _slot_label(slot_idx: int) -> String:
	var equipped: Variant = _hero.belongings.get_quickslot(slot_idx) if _hero and _hero.belongings else null
	if equipped == null:
		return "Slot %d: Empty" % (slot_idx + 1)
	return "Slot %d: %s" % [slot_idx + 1, ConstantsData.get_prop(equipped, "item_name", "item")]

func _assign_slot(slot_idx: int) -> void:
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "set_quickslot", "slot_index": slot_idx, "item": _item})
		if MessageLog:
			MessageLog.add("Set %s to quickslot %d." % [ConstantsData.get_prop(_item, "item_name", "item"), slot_idx + 1])
	close_window()

func _clear_assignment() -> void:
	if _hero == null or _hero.belongings == null:
		close_window()
		return
	var idx: int = _hero.belongings.get_quickslot_index(_item)
	if idx >= 0 and EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "clear_quickslot", "slot_index": idx})
		if MessageLog:
			MessageLog.add("Removed %s from quickslots." % ConstantsData.get_prop(_item, "item_name", "item"))
	close_window()
