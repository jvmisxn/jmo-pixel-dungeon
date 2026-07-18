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

	EventBus.request_hero_action.disconnect(_on_request_hero_action)
	left_wnd.free()
	right_wnd.free()
	hero.free()

func _on_request_hero_action(action: Dictionary) -> void:
	_last_action = action
