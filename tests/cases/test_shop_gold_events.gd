extends RefCounted

class FakeArtifact:
	extends RefCounted

	var gold_pickup_calls: int = 0

	func on_gold_pickup(_amount: int) -> void:
		gold_pickup_calls += 1

class FakeBelongings:
	extends RefCounted

	var removed_items: Array[Variant] = []
	var equipped_artifact: Variant = null

	func remove_item(item: Variant) -> void:
		removed_items.append(item)

	func get_equipped_artifact() -> Variant:
		return equipped_artifact

class FakeHero:
	extends RefCounted

	var belongings: FakeBelongings = FakeBelongings.new()

class FakeItem:
	extends RefCounted

	var item_name: String = "Test Relic"
	var cursed: bool = false
	var equipped: bool = false
	var unique: bool = false
	var stackable: bool = false

	func value() -> int:
		return 40

	func get_display_name() -> String:
		return item_name

func run(t: Object) -> void:
	var previous_gold: int = GameManager.gold
	var previous_stats: Dictionary = GameManager.stats.duplicate(true)
	GameManager.gold = 10
	GameManager.stats["gold_collected"] = 0

	var event_amounts: Array[int] = []
	var event_totals: Array[int] = []
	var on_gold := func(amount: int, total: int) -> void:
		event_amounts.append(amount)
		event_totals.append(total)
	EventBus.gold_collected.connect(on_gold)

	var artifact := FakeArtifact.new()
	var hero := FakeHero.new()
	hero.belongings.equipped_artifact = artifact
	var item := FakeItem.new()
	var shopkeeper := Shopkeeper.new()
	var sale_price: int = shopkeeper.sell_item(hero, item)

	t.check(sale_price == 40, "shopkeeper pays item.value(), matching SPD's sale path")
	t.check(GameManager.gold == 50, "shop sale adds gold to the run total")
	t.check(event_amounts == [40] and event_totals == [50], "shop sale emits a gold total update")
	t.check(
		GameManager.stats.get("gold_collected", 0) == 40,
		"shop sale counts as collected gold, matching SPD's Gold.doPickUp sale path"
	)
	t.check(
		artifact.gold_pickup_calls == 1,
		"shop sale triggers positive gold pickup hooks"
	)
	t.check(
		hero.belongings.removed_items == [item],
		"shop sale still removes the sold item from belongings"
	)
	t.check(
		shopkeeper.buyback_items.size() == 1
				and int(shopkeeper.buyback_items[0].get("price", 0)) == 40,
		"shop sale keeps the buyback record"
	)

	EventBus.gold_collected.disconnect(on_gold)
	GameManager.gold = previous_gold
	GameManager.stats = previous_stats
