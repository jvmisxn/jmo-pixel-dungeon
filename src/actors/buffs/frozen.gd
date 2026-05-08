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

	# Original: freeze a random potion or mystery meat in hero inventory
	if target.get("is_hero") == true:
		var hero: Node = target
		if hero.belongings and hero.belongings.has_method("get_backpack_items"):
			var freezable: Array = []
			for item: Variant in hero.belongings.get_backpack_items():
				if item and item.get("category") == ConstantsData.ItemCategory.POTION:
					freezable.append(item)
				if freezable.size() > 0:
					var frozen_item: Variant = freezable[randi() % freezable.size()]
					if MessageLog:
						MessageLog.add_warning("The cold shatters your %s!" % frozen_item.item_name)
					if hero.belongings.has_method("remove_item"):
						hero.belongings.remove_item(frozen_item)

	if MessageLog:
		MessageLog.add_negative("%s is frozen solid!" % target.name)

func on_detach() -> void:
	if target:
		if target.paralysed > 0:
			target.paralysed -= 1

func description() -> String:
	return "Frozen solid! Cannot move or act."
