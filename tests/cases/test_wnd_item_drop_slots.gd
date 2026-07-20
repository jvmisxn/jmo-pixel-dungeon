extends RefCounted

var _last_action: Dictionary = {}

func run(t: Object) -> void:
	EventBus.request_hero_action.connect(_on_request_hero_action)

	var hero := Hero.new()
	var left_ring: Ring = Ring.create("ring_of_might")
	var right_ring: Ring = Ring.create("ring_of_haste")
	hero.belongings.ring_left = left_ring
	hero.belongings.ring_right = right_ring

	var left_wnd := WndItem.new()
	left_wnd.setup(left_ring, hero, true)
	left_wnd._action_drop()
	t.check(
		str(_last_action.get("equip_slot", "")) == "ring_left",
		"dropping equipped left ring emits the ring_left equip slot"
	)
	t.check(
		_last_action.get("item") == left_ring,
		"dropping equipped left ring preserves the item reference"
	)

	var right_wnd := WndItem.new()
	right_wnd.setup(right_ring, hero, true)
	right_wnd._action_drop()
	t.check(
		str(_last_action.get("equip_slot", "")) == "ring_right",
		"dropping equipped right ring emits the ring_right equip slot"
	)
	t.check(
		_last_action.get("item") == right_ring,
		"dropping equipped right ring preserves the item reference"
	)

	var weapon: Weapon = MeleeWeapon.create("shortsword")
	var item_wnd := WndItem.new()
	item_wnd.setup(weapon, hero, false)
	var item_content: Control = item_wnd._build_content()
	var action_flow: HFlowContainer = item_content.get_child(item_content.get_child_count() - 1) as HFlowContainer
	t.check(
		action_flow != null,
		"item action buttons wrap in a flow container on mobile-width windows"
	)
	t.check(
		_find_button_with_text(action_flow, "Equip") != null,
		"equippable item detail exposes the Equip action"
	)
	t.check(
		_find_button_with_text(action_flow, "Close") == null,
		"item detail relies on the title-bar X instead of adding a duplicate Close action"
	)

	var inv_wnd := WndInventory.new()
	var inv_content: Control = inv_wnd._build_content()
	t.check(
		_find_button_with_text(inv_content, "Close") == null,
		"inventory relies on the title-bar X instead of adding a duplicate Close action"
	)
	t.check(
		inv_wnd._inventory_grid_columns_for_width(393.0) == 4,
		"mobile inventory grid uses fewer columns to avoid right-edge clipping"
	)
	t.check(
		inv_wnd._inventory_equip_slot_size_for_width(393.0) < inv_wnd._inventory_equip_slot_size_for_width(852.0),
		"mobile inventory equipment slots shrink before wrapping"
	)

	var touch_slot := ItemSlot.new()
	touch_slot.item = weapon
	var touched_items: Array[Variant] = []
	touch_slot.slot_clicked.connect(func(item: RefCounted) -> void:
		touched_items.append(item)
	)
	var slot_touch := InputEventScreenTouch.new()
	slot_touch.pressed = true
	touch_slot._gui_input(slot_touch)
	t.check(
		touched_items == [weapon],
		"inventory item slots emit inspection clicks from mobile screen touches"
	)

	EventBus.request_hero_action.disconnect(_on_request_hero_action)
	item_content.free()
	item_wnd.free()
	inv_content.free()
	inv_wnd.free()
	touch_slot.free()
	left_wnd.free()
	right_wnd.free()
	hero.free()

func _on_request_hero_action(action: Dictionary) -> void:
	_last_action = action

func _find_button_with_text(root: Node, text: String) -> Button:
	for child: Node in root.get_children():
		var btn: Button = child as Button
		if btn != null and btn.text == text:
			return btn
	return null
