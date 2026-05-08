class_name WndShop
extends WndBase
## Shop window for buying and selling items with the shopkeeper.

@warning_ignore("unused_signal")
signal item_purchased(item: Variant)
@warning_ignore("unused_signal")
signal item_sold(item: Variant, gold_gained: int)

var _shop_items: Array[Dictionary] = []
var _hero: Hero = null
var _gold_label: Label = null
var _shop_grid: GridContainer = null
var _sell_area: Panel = null
var _info_label: Label = null

## Sell price multiplier (items sell at half value).
const SELL_MULTIPLIER: float = 0.5


func _init() -> void:
	window_title = "Shop"
	custom_minimum_size = Vector2(440, 460)


## Configure shop inventory before adding to tree.
func setup(items: Array, hero: Hero) -> void:
	_shop_items = items
	_hero = hero


func _build_content() -> Control:
	if not _hero:
		_hero = GameManager.hero if GameManager else null

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)

	# --- Gold Display ---
	_gold_label = Label.new()
	_update_gold_display()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_gold_label.add_theme_font_size_override("font_size", 16)
	main.add_child(_gold_label)

	# --- Shop Items Grid ---
	var shop_label: Label = Label.new()
	shop_label.text = "For Sale:"
	main.add_child(shop_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	main.add_child(scroll)

	_shop_grid = GridContainer.new()
	_shop_grid.columns = 4
	_shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_grid.add_theme_constant_override("h_separation", 6)
	_shop_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_shop_grid)

	_populate_shop_grid()

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	# --- Sell Area ---
	var sell_label: Label = Label.new()
	sell_label.text = "Sell Items (drag here or click to sell from inventory):"
	main.add_child(sell_label)

	var sell_row: HBoxContainer = HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 8)
	main.add_child(sell_row)

	_sell_area = Panel.new()
	_sell_area.custom_minimum_size = Vector2(200, 56)
	_sell_area.tooltip_text = "Drop items here to sell at half value"
	sell_row.add_child(_sell_area)

	var sell_btn: Button = Button.new()
	sell_btn.text = "Sell from Inventory"
	sell_btn.pressed.connect(_on_sell_from_inventory)
	sell_row.add_child(sell_btn)

	# --- Info Label ---
	_info_label = Label.new()
	_info_label.text = ""
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main.add_child(_info_label)

	return main


func _populate_shop_grid() -> void:
	if not _shop_grid:
		return
	for child: Node in _shop_grid.get_children():
		child.queue_free()

	for i: int in range(_shop_items.size()):
		var shop_entry: Dictionary = _shop_items[i]
		var item: Variant = shop_entry.get("item")
		var price: int = shop_entry.get("price", 0)

		var slot_container: VBoxContainer = VBoxContainer.new()
		slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var item_btn: Button = Button.new()
		item_btn.custom_minimum_size = Vector2(72, 56)
		if item:
			item_btn.text = ConstantsData.get_prop(item, "item_name", "?").substr(0, 7)
			if item.get("icon_color"):
				item_btn.modulate = item.icon_color
		item_btn.pressed.connect(_on_shop_item_pressed.bind(i))
		slot_container.add_child(item_btn)

		var price_label: Label = Label.new()
		price_label.text = "%d g" % price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 11)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		slot_container.add_child(price_label)

		_shop_grid.add_child(slot_container)


func _update_gold_display() -> void:
	if _gold_label:
		var gold: int = GameManager.gold if GameManager else 0
		_gold_label.text = "Your Gold: %d" % gold


func _on_shop_item_pressed(index: int) -> void:
	if index < 0 or index >= _shop_items.size():
		return

	var shop_entry: Dictionary = _shop_items[index]
	var item: Variant = shop_entry.get("item")
	var price: int = shop_entry.get("price", 0)

	if not item:
		return

	var gold: int = GameManager.gold if GameManager else 0
	if gold < price:
		_set_info("Not enough gold! Need %d, have %d." % [price, gold])
		return

	if not _hero or not _hero.belongings:
		return

	if not _hero.belongings.has_space():
		_set_info("Your inventory is full!")
		return

	# Purchase
	if GameManager:
		GameManager.gold -= price
	_hero.belongings.add_item(item)
	_shop_items.remove_at(index)

	_set_info("Purchased %s for %d gold." % [ConstantsData.get_prop(item, "item_name", "item"), price])
	item_purchased.emit(item)

	if EventBus:
		EventBus.item_picked_up.emit(ConstantsData.get_prop(item, "item_name", ""))

	_update_gold_display()
	_populate_shop_grid()


func _on_sell_from_inventory() -> void:
	if not _hero or not _hero.belongings:
		return
	# Open a mini inventory picker for selling
	var picker: WndSellPicker = WndSellPicker.new()
	picker.setup(_hero, self)
	picker.window_closed.connect(_on_sell_picker_closed)
	open_sub_window.emit(picker)


func sell_item(item: Variant) -> void:
	if not item or not _hero:
		return
	var base_price: int = ConstantsData.get_prop(item, "price", 10)
	var sell_price: int = int(base_price * SELL_MULTIPLIER)
	sell_price = maxi(1, sell_price)

	_hero.belongings.remove_item(item)
	if GameManager:
		GameManager.gold += sell_price

	_set_info("Sold %s for %d gold." % [ConstantsData.get_prop(item, "item_name", "item"), sell_price])
	item_sold.emit(item, sell_price)
	_update_gold_display()


func _on_sell_picker_closed() -> void:
	_update_gold_display()


func _set_info(text: String) -> void:
	if _info_label:
		_info_label.text = text


# --- Inner class: Sell Picker Window ---
class WndSellPicker:
	extends WndBase

	var _hero_ref: Hero = null
	var _shop_ref: WndShop = null

	func _init() -> void:
		window_title = "Select Item to Sell"
		custom_minimum_size = Vector2(320, 300)

	func setup(hero: Hero, shop: WndShop) -> void:
		_hero_ref = hero
		_shop_ref = shop

	func _build_content() -> Control:
		if not _hero_ref or not _hero_ref.belongings:
			var empty: Label = Label.new()
			empty.text = "No items to sell."
			return empty

		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)

		for item: Variant in _hero_ref.belongings.backpack:
			var base_price: int = ConstantsData.get_prop(item, "price", 10)
			var sell_price: int = int(base_price * WndShop.SELL_MULTIPLIER)
			sell_price = maxi(1, sell_price)

			var row: HBoxContainer = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_lbl: Label = Label.new()
			name_lbl.text = ConstantsData.get_prop(item, "item_name", "Unknown")
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)

			var price_lbl: Label = Label.new()
			price_lbl.text = "%d g" % sell_price
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			row.add_child(price_lbl)

			var sell_btn: Button = Button.new()
			sell_btn.text = "Sell"
			sell_btn.pressed.connect(_on_sell_item.bind(item))
			row.add_child(sell_btn)

			list.add_child(row)

		return scroll

	func _on_sell_item(item: Variant) -> void:
		if _shop_ref:
			_shop_ref.sell_item(item)
		close_window()
