extends RefCounted
## Quest NPCs must survive level save/load. Level.deserialize rebuilds every
## mob through MobFactory.create_mob, which previously had no NPC entries —
## the Sad Ghost, Wandmaker, Imp, Blacksmith, Shopkeeper (and Sheep) were
## silently dropped with all quest/stock state on backtrack or reload.
## Also: quest/reward generation now happens in generate_quest() at spawn
## time (QuestHandler), not in _init, so load-path instantiation consumes
## no global RNG (upstream restores quests from bundles without re-rolling).

func run(t: Object) -> void:
	_test_factory_creates_npcs(t)
	_test_init_consumes_no_rng(t)
	_test_generate_quest_populates(t)
	_test_ghost_factory_round_trip(t)
	_test_shopkeeper_factory_round_trip(t)

func _test_factory_creates_npcs(t: Object) -> void:
	t.check(MobFactory.create_mob("sad_ghost") is SadGhost,
		"factory restores sad_ghost as SadGhost")
	t.check(MobFactory.create_mob("wandmaker") is Wandmaker,
		"factory restores wandmaker as Wandmaker")
	t.check(MobFactory.create_mob("ambitious_imp") is AmbImp,
		"factory restores ambitious_imp as AmbImp")
	t.check(MobFactory.create_mob("blacksmith") is Blacksmith,
		"factory restores blacksmith as Blacksmith")
	t.check(MobFactory.create_mob("shopkeeper") is Shopkeeper,
		"factory restores shopkeeper as Shopkeeper")
	t.check(MobFactory.create_mob("sheep") is Sheep,
		"factory restores sheep as Sheep")

func _test_init_consumes_no_rng(t: Object) -> void:
	seed(918273)
	var expected: int = randi()
	seed(918273)
	var ghost := SadGhost.new()
	var wm := Wandmaker.new()
	var imp := AmbImp.new()
	var observed: int = randi()
	t.check(expected == observed,
		"instantiating quest NPCs does not advance the global RNG stream")
	t.check(ghost.quest_target_id == "" and ghost.reward_weapon == null,
		"fresh ghost has no quest state before generate_quest")
	t.check(wm.requested_seed_id == "" and wm.wand_choice_a == null,
		"fresh wandmaker has no quest state before generate_quest")
	t.check(imp.quest_mob_id == "" and imp.reward_ring == null,
		"fresh imp has no quest state before generate_quest")

func _test_generate_quest_populates(t: Object) -> void:
	var ghost := SadGhost.new()
	ghost.generate_quest()
	t.check(ghost.quest_target_id != "" and ghost.reward_weapon != null \
		and ghost.reward_armor != null,
		"ghost generate_quest rolls target and both rewards")

	var wm := Wandmaker.new()
	wm.generate_quest()
	t.check(wm.requested_seed_id != "" and wm.wand_choice_a != null \
		and wm.wand_choice_b != null,
		"wandmaker generate_quest rolls reagent and both wands")

	var imp := AmbImp.new()
	imp.generate_quest()
	t.check(imp.quest_mob_id != "" and imp.required_kills > 0 \
		and imp.reward_ring != null,
		"imp generate_quest rolls target, kill count and ring")

func _test_ghost_factory_round_trip(t: Object) -> void:
	var ghost := SadGhost.new()
	ghost.generate_quest()
	ghost.target_slain = true
	ghost.quest_mob_spawned = true
	var data: Dictionary = ghost.serialize()

	var restored: Variant = MobFactory.create_mob(str(data.get("mob_id", "")))
	t.check(restored is SadGhost, "serialized ghost mob_id maps back through the factory")
	restored.deserialize(data)
	t.check(restored.quest_target_id == ghost.quest_target_id,
		"ghost quest target survives the factory round trip")
	t.check(restored.target_slain and restored.quest_mob_spawned,
		"ghost quest progress survives the factory round trip")
	t.check(restored.reward_weapon != null \
		and restored.reward_weapon.item_id == ghost.reward_weapon.item_id,
		"ghost reward weapon survives the factory round trip")

func _test_shopkeeper_factory_round_trip(t: Object) -> void:
	var keeper := Shopkeeper.new()
	var stock_item: Item = Generator.create_item("torch")
	if stock_item == null:
		stock_item = Generator.create_item("shortsword")
	t.check(stock_item != null, "test stock item generates")
	keeper.shop_inventory.append({"item": stock_item, "price": 25})
	var data: Dictionary = keeper.serialize()

	var restored: Variant = MobFactory.create_mob(str(data.get("mob_id", "")))
	t.check(restored is Shopkeeper, "serialized shopkeeper maps back through the factory")
	restored.deserialize(data)
	t.check(restored.shop_inventory.size() == 1 \
		and restored.shop_inventory[0].get("item") != null \
		and restored.shop_inventory[0].get("item").item_id == stock_item.item_id \
		and int(restored.shop_inventory[0].get("price", 0)) == 25,
		"shopkeeper stock survives the factory round trip")
