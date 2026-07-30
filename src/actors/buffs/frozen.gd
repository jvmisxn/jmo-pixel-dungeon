class_name Frozen
extends Buff
## Frozen debuff: prevents actions via paralysed counter.
## Original (Frost.java): FlavourBuff, increments target.paralysed.
## Removes Burning on attach. Does NOT deal bonus damage — just immobilizes.
## Can freeze potions in hero inventory.

const BASE_DURATION: float = 10.0

func _init() -> void:
	buff_id = "Frozen"
	buff_name = "Frozen"
	buff_type = BuffType.NEGATIVE
	announced = true
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.5, 0.8, 1.0)

func on_attach() -> void:
	if target == null:
		return
	# Increment paralysed counter (original uses target.paralysed++)
	target.paralysed += 1
	# Remove Burning and Chill on attach
	var burn: Node = target.get_buff("Burning")
	if burn:
		target.remove_buff(burn)
	var chill: Node = target.get_buff("Chill")
	if chill:
		target.remove_buff(chill)

	# Original (Frost.attachTo): freeze one random carried potion or mystery
	# meat — potions shatter at the hero's cell, mystery meat becomes a
	# Frozen Carpaccio (one unit from the stack, not the whole stack).
	if target.get("is_hero") == true:
		var hero: Node = target
		var pack: Variant = _backpack_of(hero)
		if pack != null:
			var freezable: Array = []
			for item: Variant in pack:
				if (
					item
					and item.get("unique") != true
					and (
						item.get("category") == ConstantsData.ItemCategory.POTION
						or item.get("item_id") == "mystery_meat"
					)
				):
					freezable.append(item)
			if freezable.size() > 0:
				var frozen_item: Variant = freezable[randi() % freezable.size()]
				freeze_carried_item(hero, frozen_item)

	if MessageLog:
		MessageLog.add_negative("%s is frozen solid!" % target.name)

## The hero's carried-item list: real Belongings exposes `backpack`; test
## doubles may expose `get_backpack_items()` instead.
static func _backpack_of(hero: Node) -> Variant:
	var belongings: Variant = hero.get("belongings") if hero != null else null
	if belongings == null:
		return null
	if belongings.get("backpack") != null:
		return belongings.backpack
	if belongings.has_method("get_backpack_items"):
		return belongings.get_backpack_items()
	return null

## Freeze one unit of a carried potion (shatters) or mystery meat (becomes a
## Frozen Carpaccio). Split from on_attach so tests can drive it directly.
static func freeze_carried_item(hero: Node, frozen_item: Variant) -> void:
	if hero == null or frozen_item == null or hero.get("belongings") == null:
		return
	if hero.belongings.has_method("remove_item_quantity"):
		hero.belongings.remove_item_quantity(frozen_item.item_id, 1)
	elif hero.belongings.has_method("remove_item"):
		hero.belongings.remove_item(frozen_item)
	if frozen_item.get("category") == ConstantsData.ItemCategory.POTION:
		if MessageLog:
			MessageLog.add_warning("The cold shatters your %s!" % frozen_item.item_name)
		if frozen_item.has_method("shatter") and hero.get("level") != null:
			frozen_item.shatter(hero.get("pos"), hero.get("level"))
	else:
		if MessageLog:
			MessageLog.add_warning("The cold freezes your %s solid!" % frozen_item.item_name)
		var carpaccio: Food = Food.create("frozen_carpaccio")
		if not hero.belongings.has_method("add_item") or not hero.belongings.add_item(carpaccio):
			var level_ref: Variant = hero.get("level")
			if level_ref != null and level_ref.has_method("drop_item"):
				level_ref.drop_item(carpaccio, hero.pos)

func on_detach() -> void:
	if target:
		if target.paralysed > 0:
			target.paralysed -= 1

func description() -> String:
	return "Frozen solid! Cannot move or act."
