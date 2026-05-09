class_name Spell
extends Item
## Crafted spell items. Stackable consumables that produce magical effects when
## used. Created via alchemy and used from inventory. Created via static factory.

# --- Enums ---
enum SpellType {
	PHASE_SHIFT, WILD_ENERGY, AQUA_BLAST, FEATHER_FALL,
	RECYCLE, ALCHEMIZE, CURSE_INFUSION, RECLAIM_TRAP, SUMMON_ELEMENTAL
}

# --- Properties ---
var spell_type: SpellType = SpellType.PHASE_SHIFT

func _init() -> void:
	category = ConstantsData.ItemCategory.MISC
	stackable = true
	default_action = "CAST"
	identified = true
	cursed_known = true
	icon_color = Color(0.7, 0.5, 0.9)

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

## Cast the spell.
func execute(hero: Char) -> void:
	if hero == null:
		return
	_cast(hero)
	if EventBus:
		EventBus.item_used.emit(item_name)
	_consume_one(hero)

## Apply the spell's effect based on type.
func _cast(hero: Char) -> void:
	match spell_type:
		SpellType.PHASE_SHIFT:
			_cast_phase_shift(hero)
		SpellType.WILD_ENERGY:
			_cast_wild_energy(hero)
		SpellType.AQUA_BLAST:
			_cast_aqua_blast(hero)
		SpellType.FEATHER_FALL:
			_cast_feather_fall(hero)
		SpellType.RECYCLE:
			_cast_recycle(hero)
		SpellType.ALCHEMIZE:
			_cast_alchemize(hero)
		SpellType.CURSE_INFUSION:
			_cast_curse_infusion(hero)
		SpellType.RECLAIM_TRAP:
			_cast_reclaim_trap(hero)
		SpellType.SUMMON_ELEMENTAL:
			_cast_summon_elemental(hero)

## Teleport to a random passable position on the level.
func _cast_phase_shift(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		if MessageLog:
			MessageLog.add_warning("The spell fizzles without effect.")
		return
	var attempts: int = 200
	while attempts > 0:
		attempts -= 1
		var new_pos: int = randi_range(0, ConstantsData.LENGTH - 1)
		if dungeon_level.has_method("is_passable") and dungeon_level.is_passable(new_pos):
			if dungeon_level.has_method("find_char_at") and dungeon_level.find_char_at(new_pos) == null:
				hero.pos = new_pos
				if MessageLog:
					MessageLog.add_positive("You teleport to a new location!")
				if EventBus:
					EventBus.hero_moved.emit(new_pos)
				return
	if MessageLog:
		MessageLog.add("The spell fizzles... nowhere to go.")

## Recharge wands and apply a random transmutation effect.
func _cast_wild_energy(hero: Char) -> void:
	if hero.get("belongings") == null:
		return
	# Recharge all wands in inventory
	var recharged: int = 0
	for item: Variant in hero.belongings.backpack:
		if item != null and item.get("category") == ConstantsData.ItemCategory.WAND:
			if item.has_method("recharge"):
				item.recharge()
				recharged += 1
	if recharged > 0:
		if MessageLog:
			MessageLog.add_positive("Your wands surge with renewed energy! (%d recharged)" % recharged)
	else:
		if MessageLog:
			MessageLog.add("Wild energy surges through you, but you have no wands to recharge.")
	# Random transmutation effect on a random inventory item
	if hero.belongings.backpack.size() > 0:
		var rand_item: Variant = hero.belongings.backpack[randi_range(0, hero.belongings.backpack.size() - 1)]
		if rand_item != null and rand_item.has_method("upgrade"):
			# Small chance to upgrade a random item
			if randf() < 0.3:
				rand_item.upgrade()
				if MessageLog:
					MessageLog.add_positive("Wild energy upgrades your %s!" % rand_item.get("item_name"))

## Create a water blast at the hero's position with knockback.
func _cast_aqua_blast(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	# Add water to adjacent cells
	if dungeon_level.has_method("set_terrain"):
		for dir: int in ConstantsData.DIRS_4:
			var cell: int = hero.pos + dir
			if ConstantsData.is_valid_pos(cell):
				if dungeon_level.has_method("get_terrain"):
					var terrain: int = dungeon_level.get_terrain(cell)
					if ConstantsData.terrain_is_passable(terrain):
						dungeon_level.set_terrain(cell, ConstantsData.Terrain.WATER)
	# Knockback adjacent enemies
	if dungeon_level.has_method("find_char_at"):
		for dir: int in ConstantsData.DIRS_8:
			var cell: int = hero.pos + dir
			if not ConstantsData.is_valid_pos(cell):
				continue
			var ch: Variant = dungeon_level.find_char_at(cell)
			if ch != null and ch != hero:
				# Push them one cell further away
				var push_pos: int = cell + dir
				if ConstantsData.is_valid_pos(push_pos):
					if dungeon_level.has_method("is_passable") and dungeon_level.is_passable(push_pos):
						if dungeon_level.find_char_at(push_pos) == null:
							ch.pos = push_pos
				# Small damage from the blast
				if ch.has_method("take_damage"):
					ch.take_damage(randi_range(3, 8), null)
	if MessageLog:
		MessageLog.add_info("A torrent of water erupts around you!")

## Grant safe chasm descent (feather falling) for a duration.
func _cast_feather_fall(hero: Char) -> void:
	if hero.has_method("add_buff"):
		var levi: Levitation = Levitation.new()
		levi.set_duration(30.0)
		hero.add_buff(levi)
	if MessageLog:
		MessageLog.add_positive("You feel weightless! You can safely descend chasms.")

## Transmute one consumable into another of the same type.
func _cast_recycle(hero: Char) -> void:
	if hero == null or hero.get("belongings") == null:
		return
	var consumables: Array = []
	for item: Variant in hero.belongings.backpack:
		if _is_recyclable_item(item):
			consumables.append(item)
	if consumables.is_empty():
		if MessageLog:
			MessageLog.add_warning("You have no suitable consumables to recycle.")
		return
	if consumables.size() == 1:
		_recycle_item(hero, consumables[0])
		return
	var wnd: WndItemSelect = WndItemSelect.new()
	wnd.setup(consumables, "Choose a consumable to recycle:", func(chosen: Variant) -> void:
		_recycle_item(hero, chosen)
	)
	_show_window(wnd)

## Open the alchemy pot interface anywhere.
func _cast_alchemize(_hero: Char) -> void:
	var wnd: Variant = WndAlchemy.new()
	if EventBus:
		EventBus.show_window.emit(wnd)
	if MessageLog:
		MessageLog.add_info("The alchemy pot materializes before you!")

## Curse an item to gain power from the curse.
func _cast_curse_infusion(hero: Char) -> void:
	if hero == null or hero.get("belongings") == null:
		return
	var choices: Array = []
	for item: Variant in hero.belongings.backpack:
		if _is_curse_infusion_target(item):
			choices.append(item)
	var equipped: Array = [
		hero.belongings.weapon,
		hero.belongings.armor,
		hero.belongings.spirit_bow,
	]
	for item: Variant in equipped:
		if item != null and item not in choices and _is_curse_infusion_target(item):
			choices.append(item)
	if choices.is_empty():
		if MessageLog:
			MessageLog.add_warning("You have nothing suitable to infuse.")
		return
	if choices.size() == 1:
		_apply_curse_infusion(choices[0])
		return
	var wnd: WndItemSelect = WndItemSelect.new()
	wnd.setup(choices, "Choose an item to infuse with dark energy:", func(chosen: Variant) -> void:
		_apply_curse_infusion(chosen)
	)
	_show_window(wnd)

## Pick up a trap to store and throw later.
func _cast_reclaim_trap(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	var trap: Variant = dungeon_level.trap_at(hero.pos) if dungeon_level.has_method("trap_at") else null
	if trap != null:
		var trapped_item: TrappedItem = TrappedItem.new()
		trapped_item.configure_from_trap(trap)
		dungeon_level.traps.erase(hero.pos)
		dungeon_level.set_terrain(hero.pos, ConstantsData.Terrain.EMPTY)
		var stored: bool = false
		if hero.get("belongings") != null:
			var belongings: Belongings = hero.belongings
			var self_index: int = belongings.backpack.find(self)
			if self_index >= 0 and quantity <= 1:
				belongings.backpack[self_index] = trapped_item
				for slot_index: int in range(Belongings.QUICKSLOT_COUNT):
					if belongings.quickslots[slot_index] == self:
						belongings.quickslots[slot_index] = trapped_item
				stored = true
			elif belongings.backpack.size() < Belongings.MAX_INVENTORY:
				belongings.backpack.append(trapped_item)
				stored = true
		if not stored:
			dungeon_level.drop_item(hero.pos, trapped_item)
			if MessageLog:
				MessageLog.add_warning("Your pack is full, so you leave the reclaimed trap on the ground.")
		if MessageLog:
			MessageLog.add_positive("You reclaim the %s!" % trapped_item.trap_name)
		return
	if MessageLog:
		MessageLog.add("There is no trap here to reclaim.")

## Summon a fire or frost elemental ally.
func _cast_summon_elemental(hero: Char) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	# Find an adjacent empty cell
	for dir: int in ConstantsData.DIRS_4:
		var cell: int = hero.pos + dir
		if not ConstantsData.is_valid_pos(cell):
			continue
		if dungeon_level.has_method("is_passable") and dungeon_level.is_passable(cell):
			if dungeon_level.has_method("find_char_at") and dungeon_level.find_char_at(cell) == null:
				var element: String = "fire" if randi_range(0, 1) == 0 else "frost"
				var elemental_script: GDScript = load("res://src/actors/mobs/special/summoned_elemental.gd")
				var elemental: Variant = elemental_script.call("spawn_at", cell, dungeon_level, hero, element, GameManager.depth if GameManager else 1) if elemental_script != null else null
				if elemental != null and EventBus:
					EventBus.mob_revealed.emit(elemental)
				if MessageLog:
					MessageLog.add_positive("A %s elemental rises to aid you!" % element)
				return
	if MessageLog:
		MessageLog.add("There is no space to summon an elemental.")

func _show_window(window: Control) -> void:
	if EventBus:
		EventBus.show_window.emit(window)
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(window)

func _is_recyclable_item(item: Variant) -> bool:
	if item == null or item == self:
		return false
	var recyclable_categories: Array[int] = [
		ConstantsData.ItemCategory.POTION,
		ConstantsData.ItemCategory.SCROLL,
		ConstantsData.ItemCategory.FOOD,
		ConstantsData.ItemCategory.STONE,
		ConstantsData.ItemCategory.MISC,
	]
	return item.get("category") in recyclable_categories and _recycle_pool_for_item(item).size() > 0

func _recycle_pool_for_item(item: Variant) -> Array[String]:
	if item == null:
		return []
	match int(item.get("category")):
		ConstantsData.ItemCategory.POTION:
			return Generator.POTIONS.duplicate()
		ConstantsData.ItemCategory.SCROLL:
			return Generator.SCROLLS.duplicate()
		ConstantsData.ItemCategory.FOOD:
			return Generator.FOODS.duplicate()
		ConstantsData.ItemCategory.STONE:
			return Generator.STONES.duplicate()
		ConstantsData.ItemCategory.MISC:
			if item is Bomb:
				return Generator.BOMBS.duplicate()
			if item is Spell:
				return Generator.SPELLS.duplicate()
	return []

func _recycle_item(hero: Char, item: Variant) -> void:
	if hero == null or item == null or hero.get("belongings") == null:
		return
	var pool: Array[String] = _recycle_pool_for_item(item)
	var current_id: String = str(item.get("item_id", ""))
	pool.erase(current_id)
	if pool.is_empty():
		if current_id != "":
			pool.append(current_id)
	if pool.is_empty():
		if MessageLog:
			MessageLog.add_warning("The spell cannot transmute that item.")
		return
	var new_id: String = pool[randi() % pool.size()]
	var replacement: Variant = Generator.create_item(new_id)
	if replacement == null:
		if MessageLog:
			MessageLog.add_warning("The spell fizzles and fails to transmute the item.")
		return
	if item.get("stackable") == true and int(item.get("quantity", 1)) > 1 and item.has_method("split"):
		item.split(1)
	else:
		hero.belongings.remove_item(item)
	hero.belongings.add_item(replacement)
	if MessageLog:
		MessageLog.add_positive("%s twists into %s!" % [item.get_display_name(), replacement.get_display_name()])

func _is_curse_infusion_target(item: Variant) -> bool:
	if item == null:
		return false
	if not item.has_method("is_upgradeable") or not item.is_upgradeable():
		return false
	return item is Weapon or item is Armor

func _apply_curse_infusion(item: Variant) -> void:
	if item == null:
		return
	if item.has_method("upgrade"):
		item.upgrade()
	item.cursed = true
	item.cursed_known = true
	if item is Weapon:
		item.curse_infusion_bonus = true
	elif item is Armor:
		item.curse_infusion_bonus = true
	if item.has_method("identify"):
		item.identify()
	if MessageLog:
		MessageLog.add_negative("Dark power seeps into your %s." % item.get_display_name())
	if EventBus:
		EventBus.hero_stats_changed.emit()

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
	return 20 * quantity

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Spell"
	data["spell_type"] = spell_type
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	spell_type = data.get("spell_type", SpellType.PHASE_SHIFT) as SpellType

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a spell by ID.
static func create(spell_id: String) -> Spell:
	var spell: Spell = Spell.new()
	spell.item_id = spell_id

	match spell_id:
		"phase_shift":
			spell.item_name = "Phase Shift"
			spell.description = "Teleports you to a random location on the current floor."
			spell.spell_type = SpellType.PHASE_SHIFT
			spell.icon_color = Color(0.4, 0.7, 1.0)

		"wild_energy":
			spell.item_name = "Wild Energy"
			spell.description = "Recharges all wands and may randomly transmute an item."
			spell.spell_type = SpellType.WILD_ENERGY
			spell.icon_color = Color(0.9, 0.6, 0.2)

		"aqua_blast":
			spell.item_name = "Aqua Blast"
			spell.description = "Creates a burst of water that pushes enemies back and floods the area."
			spell.spell_type = SpellType.AQUA_BLAST
			spell.icon_color = Color(0.3, 0.5, 0.9)

		"feather_fall":
			spell.item_name = "Feather Fall"
			spell.description = "Grants levitation, allowing safe descent into chasms."
			spell.spell_type = SpellType.FEATHER_FALL
			spell.icon_color = Color(0.95, 0.95, 0.8)

		"recycle":
			spell.item_name = "Recycle"
			spell.description = "Transmutes a consumable item into another of the same type."
			spell.spell_type = SpellType.RECYCLE
			spell.icon_color = Color(0.4, 0.8, 0.4)

		"alchemize":
			spell.item_name = "Alchemize"
			spell.description = "Summons the alchemy pot, allowing crafting anywhere."
			spell.spell_type = SpellType.ALCHEMIZE
			spell.icon_color = Color(0.8, 0.6, 0.3)

		"curse_infusion":
			spell.item_name = "Curse Infusion"
			spell.description = "Curses an item, granting it dark power at a cost."
			spell.spell_type = SpellType.CURSE_INFUSION
			spell.icon_color = Color(0.3, 0.1, 0.3)

		"reclaim_trap":
			spell.item_name = "Reclaim Trap"
			spell.description = "Picks up a trap from the ground to deploy later."
			spell.spell_type = SpellType.RECLAIM_TRAP
			spell.icon_color = Color(0.7, 0.5, 0.3)

		"summon_elemental":
			spell.item_name = "Summon Elemental"
			spell.description = "Summons a fire or frost elemental to fight alongside you."
			spell.spell_type = SpellType.SUMMON_ELEMENTAL
			spell.icon_color = Color(0.9, 0.4, 0.3)

		_:
			spell.item_name = "Unknown Spell"
			spell.description = "A spell of unknown purpose."

	return spell
