class_name Thief
extends Mob
## Steals an item from the hero and tries to flee.

var stolen_item: Variant = null

func _init() -> void:
	super._init()
	mob_id = "thief"
	mob_name = "Crazy Thief"
	description = "A deranged thief who will steal your belongings and flee."
	setup(20, 12, 6, 1, 7, 3)
	xp_value = 4
	max_level = 12
	awareness = 0.4
	aggro_range = 8
	base_speed = 1.2

## Thief attacks at 2x speed (0.5x delay). Original: attackDelay() = super * 0.5f.
func attack_delay() -> float:
	return super.attack_delay() * 0.5

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	if stolen_item != null:
		return  # Already stole something
	# Try to steal
	if target_char is Hero and randf() < 0.3:
		var hero: Hero = target_char as Hero
		if hero.belongings and hero.belongings.item_count() > 0:
			stolen_item = _steal_from_hero(hero)
		if stolen_item != null:
			_set_state(AIState.FLEEING)
			if MessageLog:
				MessageLog.add_negative("The thief steals %s!" % stolen_item.get_display_name())

func should_flee() -> bool:
	return stolen_item != null

func _steal_from_hero(hero: Hero) -> Variant:
	if hero == null or hero.belongings == null or hero.belongings.backpack.is_empty():
		return null
	var backpack: Array[Item] = hero.belongings.backpack
	var source_item: Item = backpack[randi() % backpack.size()]
	if source_item == null:
		return null
	if source_item.stackable and source_item.quantity > 1 and source_item.has_method("split"):
		return source_item.split(1)
	return hero.belongings.remove_item(source_item)

func _on_death(source: Variant) -> void:
	# Drop stolen item
	if stolen_item != null:
		if level != null and level.has_method("drop_item"):
			level.drop_item(pos, stolen_item)
		if MessageLog:
			MessageLog.add_positive("The thief drops %s!" % stolen_item.get_display_name())
	super._on_death(source)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	if stolen_item != null and stolen_item.has_method("serialize"):
		data["stolen_item"] = stolen_item.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	stolen_item = null
	var stolen_data: Variant = data.get("stolen_item", null)
	if not (stolen_data is Dictionary):
		return
	var item_data: Dictionary = stolen_data as Dictionary
	var item_id: String = str(item_data.get("item_id", ""))
	if item_id == "":
		return
	var restored_item: Variant = Generator.create_item(item_id)
	if restored_item != null and restored_item.has_method("deserialize"):
		restored_item.deserialize(item_data)
		stolen_item = restored_item
