class_name Scroll
extends Item
## Base class for all scrolls. Scrolls are stackable consumables that are read
## for an immediate effect. Cannot be used while blinded.

# --- Scroll-Specific Properties ---
## Whether the player has identified this scroll's rune as this scroll type.
var known: bool = false
## The arcane rune symbol used for unidentified display (randomized per run).
var rune_symbol: String = "UNKNOWN"

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	category = ConstantsData.ItemCategory.SCROLL
	stackable = true
	default_action = "READ"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Time cost for reading a scroll (matches original TIME_TO_READ = 1f).
const TIME_TO_READ: float = 1.0

## Primary action: read the scroll and consume one from the stack.
func execute(hero: Char) -> void:
	if hero == null:
		return
	# Cannot read while blinded
	if hero.has_method("has_buff") and hero.has_buff("Blindness"):
		if MessageLog:
			MessageLog.add_warning("You can't read a scroll while blinded!")
		return
	# Spend a turn to read (original: hero.spend(TIME_TO_READ))
	if hero.has_method("spend"):
		hero.spend(TIME_TO_READ)
	read_scroll(hero)
	identify()
	_consume(hero)

## Virtual — override in each scroll type for the reading effect.
func read_scroll(_hero: Char) -> void:
	pass

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Consume one scroll from the stack. Removes from inventory if exhausted.
func _consume(hero: Char) -> void:
	quantity -= 1
	if MessageLog:
		MessageLog.add_info("You read the %s." % item_name)
	if EventBus:
		EventBus.item_used.emit(item_name)
	if GameManager:
		GameManager.record_stat("scrolls_used")
	if quantity <= 0 and hero != null:
		if hero.belongings and hero.belongings.has_method("remove_item"):
			hero.belongings.remove_item(self)

func _notify_hero(hero: Char, text: String, kind: String = "info") -> void:
	if hero == null:
		return
	if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var owner_peer_id: int = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
		var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
		if owner_peer_id != local_peer_id and NetworkManager.has_method("send_ui_event_to_peer"):
			NetworkManager.send_ui_event_to_peer(owner_peer_id, {
				"type": "npc_message",
				"text": text,
				"kind": kind,
			})
			return
	if MessageLog == null:
		return
	match kind:
		"positive":
			MessageLog.add_positive(text)
		"warning", "negative":
			MessageLog.add_warning(text)
		_:
			MessageLog.add(text)

## Override duplicate_item to preserve scroll-specific properties.
func duplicate_item() -> Item:
	var copy: Scroll = Scroll.create(item_id)
	if copy == null:
		copy = Scroll.new()
	_copy_base_properties(copy)
	copy.known = known
	copy.rune_symbol = rune_symbol
	return copy

## Scrolls are not upgradeable.
func is_upgradeable() -> bool:
	return false

## SPD Scroll.value() = 30 * quantity.
func value() -> int:
	return 30 * quantity

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

## If not identified and not known, show the rune symbol instead.
func get_display_name() -> String:
	if identified or known:
		return super.get_display_name()
	var display: String = "Scroll labeled \"%s\"" % rune_symbol
	if stackable and quantity > 1:
		display = "%s (%d)" % [display, quantity]
	return display

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["known"] = known
	data["rune_symbol"] = rune_symbol
	data["scroll_type"] = item_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	known = data.get("known", false)
	rune_symbol = data.get("rune_symbol", "UNKNOWN")

# ===========================================================================
# Factory
# ===========================================================================

## Create a configured Scroll instance by type ID.
static func create(scroll_id: String) -> Scroll:
	match scroll_id:
		"identify":
			return _create_identify()
		"upgrade":
			return _create_upgrade()
		"remove_curse":
			return _create_remove_curse()
		"magic_mapping":
			return _create_magic_mapping()
		"teleportation":
			return _create_teleportation()
		"lullaby":
			return _create_lullaby()
		"rage":
			return _create_rage()
		"terror":
			return _create_terror()
		"mirror_image":
			return _create_mirror_image()
		"recharging":
			return _create_recharging()
		"transmutation":
			return _create_transmutation()
		"enchantment":
			return _create_enchantment()
		"retribution":
			return _create_retribution()
		"divination":
			return _create_divination()
	push_warning("Scroll.create(): unknown scroll_id '%s'" % scroll_id)
	return null

## Return all valid scroll IDs.
static func all_ids() -> Array[String]:
	return [
		"identify", "upgrade", "remove_curse", "magic_mapping",
		"teleportation", "lullaby", "rage", "terror",
		"mirror_image", "recharging", "transmutation", "enchantment",
		"retribution", "divination",
	]

# ===========================================================================
# Scroll Definitions
# ===========================================================================

static func _create_identify() -> Scroll:
	return ScrollIdentify.new()

static func _create_upgrade() -> Scroll:
	return ScrollUpgrade.new()

static func _create_remove_curse() -> Scroll:
	return ScrollRemoveCurse.new()

static func _create_magic_mapping() -> Scroll:
	return ScrollMagicMapping.new()

static func _create_teleportation() -> Scroll:
	return ScrollTeleportation.new()

static func _create_lullaby() -> Scroll:
	return ScrollLullaby.new()

static func _create_rage() -> Scroll:
	return ScrollRage.new()

static func _create_terror() -> Scroll:
	return ScrollTerror.new()

static func _create_mirror_image() -> Scroll:
	return ScrollMirrorImage.new()

static func _create_recharging() -> Scroll:
	return ScrollRecharging.new()

static func _create_transmutation() -> Scroll:
	return ScrollTransmutation.new()

static func _create_enchantment() -> Scroll:
	return ScrollEnchantment.new()

static func _create_retribution() -> Scroll:
	return ScrollRetribution.new()

static func _create_divination() -> Scroll:
	return ScrollDivination.new()


# ############################################################################
# SCROLL SUBCLASSES
# ############################################################################

# ---------------------------------------------------------------------------
# Scroll of Identify
# ---------------------------------------------------------------------------
class ScrollIdentify extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "identify"
		item_name = "Scroll of Identify"
		description = "A scroll inscribed with revealing runes that identify the true nature of an item."
		icon_color = Color(0.3, 0.8, 1.0)

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		# Find all unidentified items
		var unidentified: Array[Item] = []
		for item: Item in hero.belongings.backpack:
			if item != null and item.has_method("is_identified"):
				if not item.is_identified():
					unidentified.append(item)
		# Also check equipped items
		var equipped: Array[Item] = [
			hero.belongings.weapon, hero.belongings.armor,
			hero.belongings.artifact, hero.belongings.misc,
			hero.belongings.ring_left, hero.belongings.ring_right,
		]
		for eq: Variant in equipped:
			if eq != null and eq.has_method("is_identified") and not eq.is_identified():
				unidentified.append(eq)

		if unidentified.is_empty():
			if MessageLog:
				MessageLog.add("All your items are already identified.")
			return

		if unidentified.size() == 1:
			# Only one option — identify it directly
			var chosen: Variant = unidentified[0]
			if chosen.has_method("identify"):
				chosen.identify()
			if MessageLog:
				MessageLog.add_positive("You identify the %s!" % chosen.get_display_name())
		else:
			if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
				var owner_peer_id: int = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
				var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
				if owner_peer_id != local_peer_id and NetworkManager.has_method("send_ui_event_to_peer"):
					var items_data: Array[Dictionary] = []
					for unidentified_item: Variant in unidentified:
						if unidentified_item != null and unidentified_item.has_method("serialize"):
							items_data.append(unidentified_item.serialize())
					NetworkManager.send_ui_event_to_peer(owner_peer_id, {
						"type": "item_select_open",
						"hero_actor_id": int(ConstantsData.get_prop(hero, "actor_id", -1)),
						"prompt": "Choose an item to identify:",
						"action_type": "identify_item",
						"items": items_data,
					})
					return
			# Open item selection window
			var wnd: WndItemSelect = WndItemSelect.new()
			wnd.setup(unidentified, "Choose an item to identify:", func(chosen: Variant) -> void:
				if chosen != null and chosen.has_method("identify"):
					chosen.identify()
				if MessageLog:
					MessageLog.add_positive("You identify the %s!" % chosen.get_display_name())
			)
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree and tree.root:
				tree.root.add_child(wnd)


# ---------------------------------------------------------------------------
# Scroll of Upgrade
# ---------------------------------------------------------------------------
class ScrollUpgrade extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "upgrade"
		item_name = "Scroll of Upgrade"
		description = "A scroll of arcane power that enhances an item, raising its level by +1."
		icon_color = Color(1.0, 0.85, 0.3)

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		# Find all upgradeable items
		var upgradeable: Array[Item] = []
		for item: Item in hero.belongings.backpack:
			if item != null and item.has_method("is_upgradeable") and item.is_upgradeable():
				upgradeable.append(item)
		var equipped: Array[Item] = [
			hero.belongings.weapon, hero.belongings.armor,
		]
		for eq: Item in equipped:
			if eq != null and eq.has_method("is_upgradeable") and eq.is_upgradeable():
				upgradeable.append(eq)

		if upgradeable.is_empty():
			if MessageLog:
				MessageLog.add_warning("You have nothing to upgrade.")
			return

		if upgradeable.size() == 1:
			# Only one option — upgrade it directly
			_do_upgrade(upgradeable[0])
		else:
			if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
				var owner_peer_id: int = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
				var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
				if owner_peer_id != local_peer_id and NetworkManager.has_method("send_ui_event_to_peer"):
					var items_data: Array[Dictionary] = []
					for upgrade_item: Variant in upgradeable:
						if upgrade_item != null and upgrade_item.has_method("serialize"):
							items_data.append(upgrade_item.serialize())
					NetworkManager.send_ui_event_to_peer(owner_peer_id, {
						"type": "item_select_open",
						"hero_actor_id": int(ConstantsData.get_prop(hero, "actor_id", -1)),
						"prompt": "Choose an item to upgrade:",
						"action_type": "upgrade_item",
						"items": items_data,
					})
					return
			# Open item selection window
			var wnd: WndItemSelect = WndItemSelect.new()
			wnd.setup(upgradeable, "Choose an item to upgrade:", func(chosen: Variant) -> void:
				_do_upgrade(chosen)
			)
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree and tree.root:
				tree.root.add_child(wnd)

	func _do_upgrade(chosen: Variant) -> void:
		if chosen == null:
			return
		if chosen.has_method("upgrade"):
			chosen.upgrade()
		# Upgrading also identifies the item
		if chosen.has_method("identify"):
			chosen.identify()
		if MessageLog:
			MessageLog.add_positive("Your %s glows brightly!" % chosen.get_display_name())
		if GameManager:
			GameManager.record_stat("scrolls_of_upgrade")


# ---------------------------------------------------------------------------
# Scroll of Remove Curse
# ---------------------------------------------------------------------------
class ScrollRemoveCurse extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "remove_curse"
		item_name = "Scroll of Remove Curse"
		description = "A scroll of purification that lifts curses from all equipped items."
		icon_color = Color(0.9, 0.9, 1.0)

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		var uncursed_count: int = 0
		var equipped: Array = [
			hero.belongings.weapon, hero.belongings.armor,
			hero.belongings.artifact, hero.belongings.misc,
			hero.belongings.ring_left, hero.belongings.ring_right,
		]
		for eq: Variant in equipped:
			if eq == null:
				continue
			if eq.get("cursed") == true:
				eq.cursed = false
				eq.cursed_known = true
				uncursed_count += 1
			elif eq.has_method("is_actually_cursed") and not eq.is_actually_cursed():
				eq.cursed_known = true
		# Also check backpack items
		for item: Variant in hero.belongings.backpack:
			if item == null:
				continue
			if item.get("cursed") == true:
				item.cursed = false
				item.cursed_known = true
				uncursed_count += 1
			elif item.has_method("is_actually_cursed") and not item.is_actually_cursed():
				item.cursed_known = true
		if uncursed_count > 0:
			_notify_hero(hero, "A warm light washes over your belongings! %d curse(s) lifted." % uncursed_count, "positive")
		else:
			_notify_hero(hero, "The scroll's light reveals no curses on your items.")


# ---------------------------------------------------------------------------
# Scroll of Magic Mapping
# ---------------------------------------------------------------------------
class ScrollMagicMapping extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "magic_mapping"
		item_name = "Scroll of Magic Mapping"
		description = "A scroll that magically reveals the layout of the entire floor."
		icon_color = Color(0.4, 0.7, 0.4)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		# Reveal entire level map
		var dungeon_level: Variant = hero.level
		if dungeon_level and dungeon_level.has_method("reveal_all"):
			dungeon_level.reveal_all()
			_notify_hero(hero, "The layout of this floor is revealed to you!", "positive")
		elif dungeon_level and dungeon_level.get("mapped") != null:
			# Alternative: set mapped array to all true
			if dungeon_level.has_method("get") and dungeon_level.get("visited") is Array:
				var visited: Array = dungeon_level.get("visited")
				for i: int in range(visited.size()):
					visited[i] = true
			_notify_hero(hero, "The layout of this floor is revealed to you!", "positive")
		else:
			_notify_hero(hero, "A map of this floor burns into your mind!", "positive")


# ---------------------------------------------------------------------------
# Scroll of Teleportation
# ---------------------------------------------------------------------------
class ScrollTeleportation extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "teleportation"
		item_name = "Scroll of Teleportation"
		description = "A scroll that teleports the reader to a random location on the floor."
		icon_color = Color(0.3, 0.5, 1.0)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		var dungeon_level: Variant = hero.level
		if dungeon_level == null:
			return
		# Find a random passable cell
		var attempts: int = 100
		var new_pos: int = -1
		while attempts > 0:
			var candidate: int = randi() % ConstantsData.LENGTH
			if dungeon_level.has_method("is_passable") and dungeon_level.is_passable(candidate):
				if dungeon_level.has_method("find_char_at"):
					if dungeon_level.find_char_at(candidate) == null:
						new_pos = candidate
						break
			attempts -= 1
		if new_pos >= 0:
			hero.pos = new_pos
			_notify_hero(hero, "You are teleported to a new location!", "positive")
			if EventBus:
				EventBus.hero_moved_detailed.emit(hero, new_pos)
				var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
				if focused_hero == hero:
					EventBus.hero_moved.emit(new_pos)
		else:
			_notify_hero(hero, "The scroll fails to find a suitable destination.", "warning")


# ---------------------------------------------------------------------------
# Scroll of Lullaby
# ---------------------------------------------------------------------------
class ScrollLullaby extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "lullaby"
		item_name = "Scroll of Lullaby"
		description = "A scroll of soothing melody that puts all nearby enemies to sleep."
		icon_color = Color(0.6, 0.5, 0.9)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		var dungeon_level: Variant = hero.level
		if dungeon_level == null:
			return
		var affected: int = 0
		# Get all mobs in view distance
		if dungeon_level.has_method("get_mobs"):
			var mobs: Array = dungeon_level.get_mobs()
			for mob: Variant in mobs:
				if mob == null or not mob.is_alive:
					continue
				if hero.has_method("can_see") and hero.can_see(mob.pos):
					# Put to sleep with wake-on-damage semantics.
					if mob.has_method("add_buff"):
						var sleep_buff: SleepBuff = SleepBuff.new()
						sleep_buff.set_duration(10.0)
						mob.add_buff(sleep_buff)
						affected += 1
		if affected > 0:
			_notify_hero(hero, "A soothing melody lulls %d enemies to sleep!" % affected, "positive")
		else:
			_notify_hero(hero, "The lullaby echoes through empty corridors.")


# ---------------------------------------------------------------------------
# Scroll of Rage
# ---------------------------------------------------------------------------
class ScrollRage extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "rage"
		item_name = "Scroll of Rage"
		description = "A scroll of fury that enrages all visible enemies, causing them to attack anything nearby."
		icon_color = Color(1.0, 0.2, 0.2)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		var dungeon_level: Variant = hero.level
		if dungeon_level == null:
			return
		var affected: int = 0
		if dungeon_level.has_method("get_mobs"):
			var mobs: Array = dungeon_level.get_mobs()
			for mob: Variant in mobs:
				if mob == null or not mob.is_alive:
					continue
				if hero.has_method("can_see") and hero.can_see(mob.pos):
					if mob.has_method("add_buff"):
						var amok_buff: Amok = Amok.new()
						amok_buff.set_duration(5.0)
						mob.add_buff(amok_buff)
						affected += 1
		if affected > 0:
			_notify_hero(hero, "%d enemies fly into a mindless rage!" % affected, "warning")
		else:
			_notify_hero(hero, "The rage fades without a target.")


# ---------------------------------------------------------------------------
# Scroll of Terror
# ---------------------------------------------------------------------------
class ScrollTerror extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "terror"
		item_name = "Scroll of Terror"
		description = "A scroll of dread that causes all visible enemies to flee in fear."
		icon_color = Color(0.6, 0.0, 0.8)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		var dungeon_level: Variant = hero.level
		if dungeon_level == null:
			return
		var affected: int = 0
		if dungeon_level.has_method("get_mobs"):
			var mobs: Array = dungeon_level.get_mobs()
			for mob: Variant in mobs:
				if mob == null or not mob.is_alive:
					continue
				if hero.has_method("can_see") and hero.can_see(mob.pos):
					if mob.has_method("add_buff"):
						var terror_buff: Terror = Terror.create(hero.actor_id, 10.0)
						mob.add_buff(terror_buff)
						affected += 1
		if affected > 0:
			if MessageLog:
				MessageLog.add_positive("%d enemies flee in terror!" % affected)
		else:
			if MessageLog:
				MessageLog.add("The terror fades — no enemies are nearby.")


# ---------------------------------------------------------------------------
# Scroll of Mirror Image
# ---------------------------------------------------------------------------
class ScrollMirrorImage extends Scroll:
	const IMAGE_COUNT: int = 3

	func _init() -> void:
		super._init()
		item_id = "mirror_image"
		item_name = "Scroll of Mirror Image"
		description = "A scroll that creates illusory copies of the reader to confuse enemies."
		icon_color = Color(0.7, 0.7, 1.0)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		var dungeon_level: Variant = hero.level
		if dungeon_level == null:
			return
		# Spawn mirror images at adjacent empty cells
		var spawned: int = 0
		var offsets: Array[int] = ConstantsData.DIRS_8.duplicate()
		# Shuffle offsets for randomness
		for i: int in range(offsets.size() - 1, 0, -1):
			var j: int = randi() % (i + 1)
			var tmp: int = offsets[i]
			offsets[i] = offsets[j]
			offsets[j] = tmp

		for offset: int in offsets:
			if spawned >= IMAGE_COUNT:
				break
			var target_pos: int = hero.pos + offset
			if not ConstantsData.is_valid_pos(target_pos):
				continue
			if dungeon_level.has_method("is_passable") and dungeon_level.is_passable(target_pos):
				if dungeon_level.has_method("find_char_at") and dungeon_level.find_char_at(target_pos) == null:
					# Create a mirror image mob (using the level's spawn system)
					if dungeon_level.has_method("spawn_mirror_image"):
						dungeon_level.spawn_mirror_image(target_pos, hero)
					spawned += 1
		if spawned > 0:
			_notify_hero(hero, "Mirror images appear around you!", "positive")
		else:
			_notify_hero(hero, "There isn't enough space for mirror images.", "warning")


# ---------------------------------------------------------------------------
# Scroll of Recharging
# ---------------------------------------------------------------------------
class ScrollRecharging extends Scroll:
	const RECHARGE_AMOUNT: float = 10.0

	func _init() -> void:
		super._init()
		item_id = "recharging"
		item_name = "Scroll of Recharging"
		description = "A scroll that recharges all wands in the reader's inventory."
		icon_color = Color(1.0, 1.0, 0.5)

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		var recharged: int = 0
		# Recharge all wand-type items in inventory
		for item: Variant in hero.belongings.backpack:
			if item == null:
				continue
			if item.get("category") == ConstantsData.ItemCategory.WAND:
				if item.has_method("recharge"):
					item.recharge(RECHARGE_AMOUNT)
					recharged += 1
				elif item.get("charges") != null and item.get("max_charges") != null:
					item.charges = mini(item.charges + int(RECHARGE_AMOUNT), item.max_charges)
					recharged += 1
		# Also check equipped misc slot (wand might be there)
		if hero.belongings.misc != null:
			var misc_item: Variant = hero.belongings.misc
			if misc_item.get("category") == ConstantsData.ItemCategory.WAND:
				if misc_item.has_method("recharge"):
					misc_item.recharge(RECHARGE_AMOUNT)
					recharged += 1
				elif misc_item.get("charges") != null and misc_item.get("max_charges") != null:
					misc_item.charges = mini(misc_item.charges + int(RECHARGE_AMOUNT), misc_item.max_charges)
					recharged += 1
		if recharged > 0:
			_notify_hero(hero, "Your wands crackle with renewed energy! (%d recharged)" % recharged, "positive")
		else:
			_notify_hero(hero, "You don't have any wands to recharge.")


# ---------------------------------------------------------------------------
# Scroll of Transmutation
# ---------------------------------------------------------------------------
class ScrollTransmutation extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "transmutation"
		item_name = "Scroll of Transmutation"
		description = "A scroll of change that transforms an item into another of the same type."
		icon_color = Color(0.8, 0.5, 0.2)

	## Override execute to defer consumption — the window handles it on confirm.
	## If the window cannot open, fall back to immediate consume via super.
	func execute(hero: Char) -> void:
		if hero == null:
			return
		if hero.has_method("has_buff") and hero.has_buff("Blindness"):
			if MessageLog:
				MessageLog.add_warning("You can't read a scroll while blinded!")
			return
		read_scroll(hero)
		# Do NOT call _consume here — the WndTransmute handles it on confirm.
		# If fallback was used, _transmutation_fallback already logged.

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
			var owner_peer_id: int = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
			var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
			if owner_peer_id != local_peer_id and NetworkManager.has_method("send_ui_event_to_peer"):
				NetworkManager.send_ui_event_to_peer(owner_peer_id, {
					"type": "transmute_open",
					"hero_actor_id": int(ConstantsData.get_prop(hero, "actor_id", -1)),
					"scroll_item_id": str(item_id),
				})
				return
		# Open the transmutation selection window via the HUD
		var game_scene: Node = _find_game_scene()
		if game_scene and game_scene.get("_hud") != null:
			var wnd: Node = load("res://src/ui/windows/wnd_transmute.gd").new()
			wnd.setup(self, hero)
			game_scene._hud.show_window(wnd)
		else:
			# Fallback: old behavior — transmute the first eligible item
			_transmutation_fallback(hero)
			_consume(hero)

	## Find the active GameScene in the scene tree.
	func _find_game_scene() -> Node:
		# Walk up from any node in the tree to find the GameScene
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		var root: Window = tree.root
		if root == null:
			return null
		# Search children for GameScene (duck-typed to avoid circular dep)
		for child: Node in root.get_children():
			if child.has_method("load_level") and child.has_method("refresh_after_turn"):
				return child
			for grandchild: Node in child.get_children():
				if grandchild.has_method("load_level") and grandchild.has_method("refresh_after_turn"):
					return grandchild
		return null

	## Fallback transmutation when no UI is available.
	func _transmutation_fallback(hero: Char) -> void:
		var transmutable: Array[Item] = []
		for item: Item in hero.belongings.backpack:
			if item == null:
				continue
			if item.category in [ConstantsData.ItemCategory.WEAPON, ConstantsData.ItemCategory.ARMOR,
					ConstantsData.ItemCategory.WAND, ConstantsData.ItemCategory.RING,
					ConstantsData.ItemCategory.ARTIFACT,
					ConstantsData.ItemCategory.POTION, ConstantsData.ItemCategory.SCROLL]:
				if not item.unique and item != self:
					transmutable.append(item)

		if transmutable.size() > 0:
			var chosen: Variant = transmutable[0]
			var old_name: String = chosen.get_display_name() if chosen.has_method("get_display_name") else "item"
			if chosen.has_method("identify"):
				chosen.identify()
			if EventBus:
				EventBus.item_used.emit("transmutation_target:" + old_name)
			if MessageLog:
				MessageLog.add_positive("The %s shimmers and transforms!" % old_name)
		else:
			if MessageLog:
				MessageLog.add_warning("You have nothing that can be transmuted.")


# ---------------------------------------------------------------------------
# Scroll of Enchantment
# ---------------------------------------------------------------------------
class ScrollEnchantment extends Scroll:
	## Available weapon enchantment types.
	const ENCHANTMENTS: Array[String] = [
		"blazing", "chilling", "shocking", "vampiric",
		"lucky", "projecting", "unstable", "grim",
	]

	func _init() -> void:
		super._init()
		item_id = "enchantment"
		item_name = "Scroll of Enchantment"
		description = "A scroll that imbues a weapon with a random magical enchantment."
		icon_color = Color(0.9, 0.3, 0.6)

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		# Enchant the currently equipped weapon
		var weapon: Variant = hero.belongings.weapon
		if weapon == null:
			# Try to find a weapon in the backpack
			for item: Variant in hero.belongings.backpack:
				if item != null and item.get("category") == ConstantsData.ItemCategory.WEAPON:
					weapon = item
					break
		if weapon == null:
			if MessageLog:
				MessageLog.add_warning("You don't have a weapon to enchant.")
			return
		# Apply a random enchantment
		var enchant_type: String = ENCHANTMENTS[randi() % ENCHANTMENTS.size()]
		var ench: WeaponEnchantment = WeaponEnchantment.create(enchant_type)
		if weapon.has_method("enchant"):
			weapon.enchant(ench)
		else:
			# Fallback: store enchantment as a property
			weapon.set("enchantment", ench)
		# Identify the weapon
		if weapon.has_method("identify"):
			weapon.identify()
		if MessageLog:
			MessageLog.add_positive("Your %s glows with %s energy!" % [weapon.get_display_name(), enchant_type])


# ---------------------------------------------------------------------------
# Scroll of Retribution
# ---------------------------------------------------------------------------
class ScrollRetribution extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "retribution"
		item_name = "Scroll of Retribution"
		description = "A scroll of devastating power that deals massive damage to all visible enemies at the cost of the reader's health."
		icon_color = Color(1.0, 1.0, 1.0)

	func read_scroll(hero: Char) -> void:
		if hero == null:
			return
		var dungeon_level: Variant = hero.level
		if dungeon_level == null:
			return
		# Calculate damage based on hero's current and max HP
		@warning_ignore("integer_division")
		var hp_sacrifice: int = hero.hp / 2
		if hp_sacrifice < 1:
			hp_sacrifice = 1
		# Deal retribution damage to self
		hero.take_damage(hp_sacrifice, self)
		# Deal massive damage to all visible enemies
		var base_damage: int = hp_sacrifice * 2 + hero.ht
		var affected: int = 0
		if dungeon_level.has_method("get_mobs"):
			var mobs: Array = dungeon_level.get_mobs()
			for mob: Variant in mobs:
				if mob == null or not mob.is_alive:
					continue
				if hero.has_method("can_see") and hero.can_see(mob.pos):
					# Damage scales with distance — closer = more damage
					var dist: int = 1
					if hero.has_method("distance_to"):
						dist = maxi(1, hero.distance_to(mob.pos))
					var mob_damage: int = maxi(1, int(float(base_damage) / float(dist)))
					if mob.has_method("take_damage"):
						mob.take_damage(mob_damage, hero)
					affected += 1
		# Also blind nearby enemies and the hero
		var blind_buff: Blindness = Blindness.new()
		blind_buff.set_duration(5.0)
		hero.add_buff(blind_buff)
		if affected > 0:
			if MessageLog:
				MessageLog.add_warning("A blinding flash of holy light sears everything in sight! (%d hit)" % affected)
		else:
			if MessageLog:
				MessageLog.add_warning("A blinding flash erupts from the scroll, but no enemies are nearby.")


# ---------------------------------------------------------------------------
# Scroll of Divination
# ---------------------------------------------------------------------------
class ScrollDivination extends Scroll:
	func _init() -> void:
		super._init()
		item_id = "divination"
		item_name = "Scroll of Divination"
		description = "This scroll will reveal the nature of a random unidentified item in your inventory."

	func read_scroll(hero: Char) -> void:
		if hero == null or hero.belongings == null:
			return
		var unidentified: Array[Item] = []
		for item: Item in hero.belongings.get_all_items():
			if item and ConstantsData.get_prop(item, "is_identified", true) == false:
				unidentified.append(item)
		if unidentified.is_empty():
			if MessageLog:
				MessageLog.add("All your items are already identified.")
			return
		var chosen: Item = unidentified[randi() % unidentified.size()]
		if chosen.has_method("identify"):
			chosen.identify()
		if MessageLog:
			MessageLog.add_positive("The scroll reveals the nature of %s!" % chosen.get_display_name())
