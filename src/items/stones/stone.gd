class_name Stone
extends Item
## Runestones. Stackable consumable items with targeted effects. Used by
## throwing at a target or applying to an item. Created via the static factory.

# --- Enums ---
enum StoneType {
	ENCHANTMENT, AUGMENTATION, INTUITION, BLAST, BLINK,
	CLAIRVOYANCE, DEEPENED_SLEEP, DISARMING, FEAR, FLOCK, SHOCK
}

# --- Properties ---
var stone_type: StoneType = StoneType.ENCHANTMENT

func _init() -> void:
	category = ConstantsData.ItemCategory.STONE
	stackable = true
	default_action = "USE"
	identified = true
	cursed_known = true
	icon_color = Color(0.6, 0.6, 0.7)

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

## Use the stone. Behavior depends on the stone type.
func execute(hero: Char) -> void:
	if hero == null:
		return
	_apply_effect(hero)
	if EventBus:
		EventBus.item_used.emit(item_name)
	_consume_one(hero)

## Apply the stone's effect based on type.
func _apply_effect(hero: Char) -> void:
	match stone_type:
		StoneType.ENCHANTMENT:
			_use_enchantment(hero)
		StoneType.AUGMENTATION:
			_use_augmentation(hero)
		StoneType.INTUITION:
			_use_intuition(hero)
		StoneType.BLAST:
			_use_blast(hero)
		StoneType.BLINK:
			_use_blink(hero)
		StoneType.CLAIRVOYANCE:
			_use_clairvoyance(hero)
		StoneType.DEEPENED_SLEEP:
			_use_deepened_sleep(hero)
		StoneType.DISARMING:
			_use_disarming(hero)
		StoneType.FEAR:
			_use_fear(hero)
		StoneType.FLOCK:
			_use_flock(hero)
		StoneType.SHOCK:
			_use_shock(hero)

## Add a random enchantment to the hero's equipped weapon.
func _use_enchantment(hero: Char) -> void:
	if hero.get("belongings") == null:
		if MessageLog:
			MessageLog.add_warning("You need a weapon equipped to use this!")
		return
	var choices: Array = []
	var equipped_weapon: Variant = hero.belongings.weapon
	var spirit_bow: Variant = hero.belongings.spirit_bow
	if equipped_weapon != null and equipped_weapon.has_method("enchant"):
		choices.append(equipped_weapon)
	if spirit_bow != null and spirit_bow.has_method("enchant") and spirit_bow != equipped_weapon:
		choices.append(spirit_bow)
	if choices.is_empty():
		if MessageLog:
			MessageLog.add_warning("You need a weapon equipped to use this!")
		return
	if choices.size() == 1:
		_apply_enchantment_to_item(choices[0])
		return
	var wnd: WndItemSelect = WndItemSelect.new()
	wnd.setup(choices, "Choose a weapon to enchant:", func(chosen: Variant) -> void:
		_apply_enchantment_to_item(chosen)
	)
	_show_window(wnd)

## Set augmentation on the hero's weapon or armor.
func _use_augmentation(hero: Char) -> void:
	if hero.get("belongings") == null:
		if MessageLog:
			MessageLog.add_warning("You need equipment to augment!")
		return
	var choices: Array = []
	var belongings: Variant = hero.belongings
	var candidates: Array = [
		belongings.weapon,
		belongings.armor,
		belongings.spirit_bow,
	]
	for item: Variant in candidates:
		if item == null:
			continue
		if item.has_method("apply_augment"):
			choices.append(item)
	if choices.is_empty():
		if MessageLog:
			MessageLog.add_warning("You need equipment to augment!")
		return
	if choices.size() == 1:
		_open_augment_choice(choices[0])
		return
	var wnd: WndItemSelect = WndItemSelect.new()
	wnd.setup(choices, "Choose an item to augment:", func(chosen: Variant) -> void:
		_open_augment_choice(chosen)
	)
	_show_window(wnd)

func _apply_enchantment_to_item(item: Variant) -> void:
	if item == null or not item.has_method("enchant"):
		return
	item.enchant(WeaponEnchantment.random())
	if item.has_method("identify"):
		item.identify()
	if MessageLog:
		MessageLog.add_positive("Your %s glows with new enchantment!" % item.get_display_name())
	if EventBus:
		EventBus.hero_stats_changed.emit()

func _open_augment_choice(item: Variant) -> void:
	if item == null:
		return
	var wnd: WndAugmentSelect = WndAugmentSelect.new()
	wnd.setup(item, func(chosen_item: Variant, augment_key: String) -> void:
		_apply_augment_to_item(chosen_item, augment_key)
	)
	_show_window(wnd)

func _apply_augment_to_item(item: Variant, augment_key: String) -> void:
	if item == null or not item.has_method("apply_augment"):
		return
	if item is Armor:
		var armor: Armor = item as Armor
		match augment_key:
			"evasion":
				armor.apply_augment(Armor.Augment.EVASION)
			"defense":
				armor.apply_augment(Armor.Augment.DEFENSE)
			_:
				return
	else:
		var weapon: Weapon = item as Weapon
		match augment_key:
			"speed":
				weapon.apply_augment(Weapon.Augment.SPEED)
			"damage":
				weapon.apply_augment(Weapon.Augment.DAMAGE)
			_:
				return
	if item.has_method("identify"):
		item.identify()
	if MessageLog:
		MessageLog.add_positive("%s is augmented for %s." % [item.get_display_name(), augment_key])
	if EventBus:
		EventBus.hero_stats_changed.emit()

func _show_window(window: Control) -> void:
	if EventBus:
		EventBus.show_window.emit(window)
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(window)

## Chance to identify a random unidentified item in inventory.
func _use_intuition(hero: Char) -> void:
	if not (hero is Hero) or (hero as Hero).belongings == null:
		return
	var unidentified: Array[Item] = []
	for item: Item in hero.belongings.backpack:
		if item != null and not item.identified:
			unidentified.append(item)
	if unidentified.is_empty():
		if MessageLog:
			MessageLog.add_info("You have nothing left to identify.")
		return
	# 60% chance to identify a random item
	if randf() < 0.6:
		var target: Variant = unidentified[randi_range(0, unidentified.size() - 1)]
		if target.has_method("identify"):
			target.identify()
		if MessageLog:
			MessageLog.add_positive("You identify the %s!" % target.get("item_name"))
	else:
		if MessageLog:
			MessageLog.add("The stone crumbles, but nothing happens.")

## Create a mini explosion at the hero's position.
func _use_blast(hero: Char) -> void:
	var target_pos: int = hero.pos if hero.get("pos") != null else 0
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level != null and dungeon_level.has_method("get_chars_at_positions"):
		# Damage adjacent enemies
		var cells: Array[int] = []
		for dir: int in ConstantsData.DIRS_8:
			var cell: int = target_pos + dir
			if ConstantsData.is_valid_pos(cell):
				cells.append(cell)
		var chars: Array = dungeon_level.get_chars_at_positions(cells)
		for ch: Variant in chars:
			if ch != null and ch != hero and ch.has_method("take_damage"):
				ch.take_damage(randi_range(5, 15), null)
	if MessageLog:
		MessageLog.add("The stone explodes!")

## Short-range teleport (blink).
func _use_blink(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	# Teleport to a random passable cell within 8 cells
	var attempts: int = 100
	var hero_x: int = ConstantsData.pos_to_x(hero.pos)
	var hero_y: int = ConstantsData.pos_to_y(hero.pos)
	while attempts > 0:
		attempts -= 1
		var dx: int = randi_range(-4, 4)
		var dy: int = randi_range(-4, 4)
		if dx == 0 and dy == 0:
			continue
		var nx: int = hero_x + dx
		var ny: int = hero_y + dy
		if nx < 0 or nx >= ConstantsData.WIDTH or ny < 0 or ny >= ConstantsData.HEIGHT:
			continue
		var new_pos: int = ConstantsData.xy_to_pos(nx, ny)
		if dungeon_level.has_method("is_passable") and dungeon_level.is_passable(new_pos):
			if dungeon_level.has_method("find_char_at") and dungeon_level.find_char_at(new_pos) == null:
				hero.pos = new_pos
				if MessageLog:
					MessageLog.add_positive("You blink to a new position!")
				if EventBus:
					EventBus.hero_moved_detailed.emit(hero, new_pos)
					var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
					if focused_hero == hero:
						EventBus.hero_moved.emit(new_pos)
				return
	if MessageLog:
		MessageLog.add("The stone crumbles, but there was nowhere to blink to.")

## Reveal the area around a target position.
func _use_clairvoyance(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	# Reveal cells in a large radius around hero
	if dungeon_level.has_method("reveal_area"):
		dungeon_level.reveal_area(hero.pos, 8)
	if MessageLog:
		MessageLog.add_positive("The dungeon layout becomes clear!")

## Put a target enemy into deep sleep.
func _use_deepened_sleep(hero: Char) -> void:
	# Would target an adjacent or nearby mob
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	# Find an adjacent mob
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = hero.pos + dir
		if not ConstantsData.is_valid_pos(cell):
			continue
		if dungeon_level.has_method("find_char_at"):
			var ch: Variant = dungeon_level.find_char_at(cell)
			if ch != null and ch != hero and ch.has_method("add_buff"):
				var sleep_buff: Paralysis = Paralysis.new()
				sleep_buff.set_duration(20.0)
				ch.add_buff(sleep_buff)
				if MessageLog:
					MessageLog.add_positive("The target falls into a deep sleep!")
				return
	if MessageLog:
		MessageLog.add("There is no adjacent target to put to sleep.")

## Remove a target's weapon (disarm).
func _use_disarming(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = hero.pos + dir
		if not ConstantsData.is_valid_pos(cell):
			continue
		if dungeon_level.has_method("find_char_at"):
			var ch: Variant = dungeon_level.find_char_at(cell)
			if ch != null and ch != hero:
				# Reduce the target's attack skill temporarily
				if ch.has_method("add_buff"):
					var weak: Weakness = Weakness.new()
					weak.set_duration(10.0)
					ch.add_buff(weak)
				if MessageLog:
					MessageLog.add_positive("You disarm the target!")
				return
	if MessageLog:
		MessageLog.add("There is no adjacent target to disarm.")

## Terrify targets in the area.
func _use_fear(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	var cells: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = hero.pos + dir
		if ConstantsData.is_valid_pos(cell):
			cells.append(cell)
	if dungeon_level.has_method("get_chars_at_positions"):
		var chars: Array = dungeon_level.get_chars_at_positions(cells)
		for ch: Variant in chars:
			if ch != null and ch != hero and ch.has_method("add_buff"):
				var terror_buff: Terror = Terror.new()
				terror_buff.set_duration(10.0)
				ch.add_buff(terror_buff)
	if MessageLog:
		MessageLog.add("A wave of terror washes over nearby enemies!")

## Summon blocking sheep at adjacent positions.
func _use_flock(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	var spawned: int = 0
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = hero.pos + dir
		if not ConstantsData.is_valid_pos(cell):
			continue
		if dungeon_level.has_method("is_passable") and not dungeon_level.is_passable(cell):
			continue
		if dungeon_level.has_method("find_char_at") and dungeon_level.find_char_at(cell) != null:
			continue
		Sheep.spawn_at(cell, dungeon_level, 8)
		spawned += 1
	if MessageLog:
		if spawned > 0:
			MessageLog.add("A flock of magical sheep appears!")
		else:
			MessageLog.add("There is no space for the flock to appear.")

## Chain lightning from the thrown position.
func _use_shock(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	# Damage all adjacent enemies with lightning
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = hero.pos + dir
		if not ConstantsData.is_valid_pos(cell):
			continue
		if dungeon_level.has_method("find_char_at"):
			var ch: Variant = dungeon_level.find_char_at(cell)
			if ch != null and ch != hero and ch.has_method("take_damage"):
				ch.take_damage(randi_range(4, 12), null)
	if MessageLog:
		MessageLog.add_warning("Lightning arcs between targets!")

## Remove one from the stack.
func _consume_one(hero: Char) -> void:
	quantity -= 1
	if quantity <= 0:
		if hero != null and hero.get("belongings") != null:
			hero.belongings.remove_item(self)

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	return 15 * quantity

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Stone"
	data["stone_type"] = stone_type
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	stone_type = data.get("stone_type", StoneType.ENCHANTMENT) as StoneType

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a stone by ID.
static func create(stone_id: String) -> Stone:
	var stone: Stone = Stone.new()
	stone.item_id = stone_id

	match stone_id:
		"enchantment":
			stone.item_name = "Stone of Enchantment"
			stone.description = "Imbues a weapon with a random magical enchantment."
			stone.stone_type = StoneType.ENCHANTMENT
			stone.icon_color = Color(0.9, 0.5, 0.9)

		"augmentation":
			stone.item_name = "Stone of Augmentation"
			stone.description = "Allows you to augment a weapon or armor for speed or power."
			stone.stone_type = StoneType.AUGMENTATION
			stone.icon_color = Color(0.9, 0.9, 0.3)

		"intuition":
			stone.item_name = "Stone of Intuition"
			stone.description = "Has a chance to identify a random item in your inventory."
			stone.stone_type = StoneType.INTUITION
			stone.icon_color = Color(0.4, 0.8, 0.9)

		"blast":
			stone.item_name = "Stone of Blast"
			stone.description = "Creates a small explosion, damaging adjacent enemies."
			stone.stone_type = StoneType.BLAST
			stone.icon_color = Color(1.0, 0.3, 0.1)

		"blink":
			stone.item_name = "Stone of Blink"
			stone.description = "Teleports you a short distance."
			stone.stone_type = StoneType.BLINK
			stone.icon_color = Color(0.3, 0.6, 1.0)

		"clairvoyance":
			stone.item_name = "Stone of Clairvoyance"
			stone.description = "Reveals the dungeon layout in a large area around you."
			stone.stone_type = StoneType.CLAIRVOYANCE
			stone.icon_color = Color(0.7, 0.9, 1.0)

		"deepened_sleep":
			stone.item_name = "Stone of Deepened Sleep"
			stone.description = "Puts an adjacent target into a deep, prolonged sleep."
			stone.stone_type = StoneType.DEEPENED_SLEEP
			stone.icon_color = Color(0.3, 0.3, 0.6)

		"disarming":
			stone.item_name = "Stone of Disarming"
			stone.description = "Weakens an adjacent target, reducing its combat ability."
			stone.stone_type = StoneType.DISARMING
			stone.icon_color = Color(0.7, 0.7, 0.5)

		"fear":
			stone.item_name = "Stone of Fear"
			stone.description = "Terrifies all adjacent enemies, causing them to flee."
			stone.stone_type = StoneType.FEAR
			stone.icon_color = Color(0.5, 0.2, 0.5)

		"flock":
			stone.item_name = "Stone of Flock"
			stone.description = "Summons a flock of magical sheep that block movement."
			stone.stone_type = StoneType.FLOCK
			stone.icon_color = Color(0.95, 0.95, 0.9)

		"shock":
			stone.item_name = "Stone of Shock"
			stone.description = "Releases chain lightning that arcs between nearby targets."
			stone.stone_type = StoneType.SHOCK
			stone.icon_color = Color(0.3, 0.5, 1.0)

		_:
			stone.item_name = "Unknown Stone"
			stone.description = "A runestone of unknown power."

	return stone
