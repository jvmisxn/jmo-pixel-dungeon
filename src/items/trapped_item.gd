class_name TrappedItem
extends Item
## A reclaimed trap stored as an inventory item and re-deployable later.

var trap_script_path: String = ""
var trap_data: Dictionary = {}
var trap_name: String = "trap"

func _init() -> void:
	item_id = "reclaimed_trap"
	item_name = "Reclaimed Trap"
	description = "A recovered trap mechanism that can be set down elsewhere."
	category = ConstantsData.ItemCategory.MISC
	stackable = false
	default_action = "SET"
	identified = true
	cursed_known = true
	icon_color = Color(0.9, 0.7, 0.25)

func configure_from_trap(trap: Variant) -> void:
	if trap == null or not trap.has_method("serialize"):
		return
	trap_script_path = trap.get_script().resource_path if trap.get_script() != null else ""
	trap_data = trap.serialize().duplicate(true)
	trap_name = str(trap.get("trap_name")) if trap.get("trap_name") != null else trap_name
	item_name = "Reclaimed %s" % trap_name.capitalize()
	description = "A reclaimed %s that can be placed on an empty tile." % trap_name

func execute(hero: Char) -> void:
	if hero == null or trap_script_path.is_empty():
		return
	var trap_item: TrappedItem = self
	var callback: Callable = func(cell: int) -> void:
		trap_item._place_trap_at(hero, cell)
	if EventBus and EventBus.has_signal("enter_targeting"):
		EventBus.enter_targeting.emit(self, 6, callback)
		if MessageLog:
			MessageLog.add("Choose where to set the reclaimed trap.")

func _place_trap_at(hero: Char, target_pos: int) -> void:
	var dungeon_level: Variant = hero.get("level")
	if dungeon_level == null:
		return
	if target_pos < 0 or target_pos >= ConstantsData.LENGTH:
		return
	if not dungeon_level.is_passable(target_pos):
		if MessageLog:
			MessageLog.add_warning("You need open ground to place the trap.")
		return
	if dungeon_level.find_char_at(target_pos) != null:
		if MessageLog:
			MessageLog.add_warning("Something is standing there.")
		return
	if dungeon_level.trap_at(target_pos) != null:
		if MessageLog:
			MessageLog.add_warning("There is already a trap there.")
		return
	if not ResourceLoader.exists(trap_script_path):
		if MessageLog:
			MessageLog.add_warning("The reclaimed trap mechanism is broken.")
		return
	var trap_script: Script = load(trap_script_path) as Script
	if trap_script == null:
		return
	var trap: Variant = trap_script.new()
	if trap == null:
		return
	if trap.has_method("deserialize"):
		trap.deserialize(trap_data.duplicate(true))
	trap.visible = true
	trap.active = true
	trap.set_pos(target_pos)
	dungeon_level.place_trap(target_pos, trap)
	dungeon_level.set_terrain(target_pos, ConstantsData.Terrain.TRAP)
	if hero.get("belongings") != null:
		hero.belongings.remove_item(self)
	if EventBus:
		EventBus.item_used.emit(item_name)
	if MessageLog:
		MessageLog.add_positive("You set the %s." % trap_name)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["trap_script_path"] = trap_script_path
	data["trap_data"] = trap_data.duplicate(true)
	data["trap_name"] = trap_name
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	trap_script_path = str(data.get("trap_script_path", trap_script_path))
	trap_data = (data.get("trap_data", {}) as Dictionary).duplicate(true)
	trap_name = str(data.get("trap_name", trap_name))
	item_name = "Reclaimed %s" % trap_name.capitalize()
	description = "A reclaimed %s that can be placed on an empty tile." % trap_name
