extends RefCounted
## Stack splitting must preserve concrete item behavior instead of downgrading
## split-off stacks to inert base Item/Potion/Scroll instances.


func run(t: Object) -> void:
	_check_potion_split(t)
	_check_scroll_split(t)
	_check_factory_backed_stackables(t)
	_check_split_guards(t)


func _check_potion_split(t: Object) -> void:
	var potion: Potion = Potion.create("toxic_gas")
	potion.quantity = 3
	potion.known = true
	potion.appearance_name = "Viridian"
	var split_item: Item = potion.split(1)

	t.check(split_item != null, "potion split returns a new item")
	t.check(split_item is Potion, "potion split stays a Potion")
	t.check(split_item.get_script() == potion.get_script(), "potion split preserves concrete shatter/drink behavior")
	t.check((split_item as Potion).known, "potion split preserves known state")
	t.check((split_item as Potion).appearance_name == "Viridian", "potion split preserves appearance")
	t.check(split_item.quantity == 1 and potion.quantity == 2, "potion split divides quantities")


func _check_scroll_split(t: Object) -> void:
	var scroll: Scroll = Scroll.create("teleportation")
	scroll.quantity = 4
	scroll.known = true
	scroll.rune_symbol = "KAUNAN"
	var split_item: Item = scroll.split(2)

	t.check(split_item != null, "scroll split returns a new item")
	t.check(split_item is Scroll, "scroll split stays a Scroll")
	t.check(split_item.get_script() == scroll.get_script(), "scroll split preserves concrete read behavior")
	t.check((split_item as Scroll).known, "scroll split preserves known state")
	t.check((split_item as Scroll).rune_symbol == "KAUNAN", "scroll split preserves rune")
	t.check(split_item.quantity == 2 and scroll.quantity == 2, "scroll split divides scroll quantities")


func _check_factory_backed_stackables(t: Object) -> void:
	_check_split_type(t, SeedItem.create("seed_of_firebloom"), "SeedItem", "plant_type", "firebloom")
	_check_split_type(t, Bomb.create("fire_bomb"), "Bomb", "bomb_type", Bomb.BombType.FIRE)
	_check_split_type(t, Stone.create("blink"), "Stone", "stone_type", Stone.StoneType.BLINK)
	_check_split_type(t, Spell.create("recycle"), "Spell", "spell_type", Spell.SpellType.RECYCLE)
	_check_split_type(t, Food.create("mystery_meat"), "Food", "random_effect", true)
	_check_missile_split(t)
	_check_split_type(t, Torch.new(), "Torch", "default_action", "LIGHT")
	_check_split_type(t, Dewdrop.new(), "Dewdrop", "default_action", "PICK UP")


func _check_split_type(t: Object, item: Item, expected_type: String, field_name: String, expected_value: Variant) -> void:
	item.quantity = 3
	var split_item: Item = item.split(1)
	t.check(split_item != null, "%s split returns a new item" % expected_type)
	t.check(split_item.get_script() == item.get_script(), "%s split preserves concrete script" % expected_type)
	t.check(split_item.get(field_name) == expected_value, "%s split preserves %s" % [expected_type, field_name])
	t.check(split_item.quantity == 1 and item.quantity == 2, "%s split divides quantities" % expected_type)


func _check_missile_split(t: Object) -> void:
	var item: MissileWeapon = MissileWeapon.create("bolas")
	item.quantity = 3
	item.level = 2
	item.uses_left = 3
	var split_item: Item = item.split(1)
	t.check(split_item != null, "MissileWeapon split returns a new item")
	t.check(split_item.get_script() == item.get_script(), "MissileWeapon split preserves concrete script")
	t.check(split_item is MissileWeapon, "MissileWeapon split stays a missile weapon")
	var split_missile: MissileWeapon = split_item as MissileWeapon
	t.check(split_missile.special_effect == "slow", "MissileWeapon split preserves special effect")
	t.check(split_missile.level == 2, "MissileWeapon split preserves level")
	t.check(split_missile.uses_left == 3, "MissileWeapon split preserves remaining uses")
	t.check(split_item.quantity == 1 and item.quantity == 2, "MissileWeapon split divides quantities")


func _check_split_guards(t: Object) -> void:
	var item: Stone = Stone.create("shock")
	item.quantity = 2
	t.check(item.split(0) == null, "split rejects zero quantity")
	t.check(item.quantity == 2, "zero split leaves quantity unchanged")
	t.check(item.split(2) == null, "split rejects full-stack quantity")
	t.check(item.quantity == 2, "full-stack split leaves quantity unchanged")
	t.check(item.split(3) == null, "split rejects oversized quantity")
	t.check(item.quantity == 2, "oversized split leaves quantity unchanged")
