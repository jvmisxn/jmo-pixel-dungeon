class_name CellExaminer
extends RefCounted
## Examine-mode cell inspection, mirroring Shattered PD's
## GameScene.examineCell(): unknown cells report nothing, then priority is
## visible char > heap > plant > visible trap > terrain knowledge.
## Entry point is InputCoordinator (X key toggles examine mode); windows are
## delivered through EventBus.show_window so the HUD owns presentation.

## Classify what the hero knows about a cell. Pure logic, headless-testable.
## Returns a Dictionary with a "kind" key:
##   none | unknown | hero | mob | heap | plant | trap | terrain
static func describe_cell(level: Variant, hero: Variant, cell: int) -> Dictionary:
	if level == null or not ConstantsData.is_valid_pos(cell):
		return {"kind": "none"}
	var seen: bool = _flag(level.visible, cell)
	var known: bool = seen or _flag(level.visited, cell) or _flag(level.mapped, cell)
	if not known:
		return {"kind": "unknown"}
	# Characters are only examinable while actually in view.
	if seen:
		var ch: Variant = level.find_char_at(cell)
		if ch != null:
			if hero != null and ch == hero:
				return {"kind": "hero", "char": ch}
			return {"kind": "mob", "char": ch}
	var heaps: Array[Dictionary] = level.heaps_at(cell)
	if not heaps.is_empty():
		return {"kind": "heap", "item": heaps[0].get("item"), "count": heaps.size()}
	if level.plants.has(cell):
		return {"kind": "plant", "plant": level.plants[cell]}
	var trap: Variant = level.trap_at(cell)
	if trap != null and trap.visible and trap.active:
		return {"kind": "trap", "trap": trap}
	var terrain: int = level.terrain_at(cell)
	return {
		"kind": "terrain",
		"terrain": terrain,
		"title": terrain_name(terrain),
		"text": terrain_desc(terrain),
	}

## Examine a cell from the game scene: resolve what is there and present it.
static func examine(scene: Variant, cell: int) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	var info: Dictionary = describe_cell(scene._current_level, hero, cell)
	match String(info.get("kind", "none")):
		"unknown":
			if MessageLog:
				MessageLog.add("You don't know what is there.")
		"hero":
			_show(WndHeroInfo.new())
		"mob":
			var wnd_mob: WndInfoMob = WndInfoMob.new()
			wnd_mob.setup(info.get("char"))
			_show(wnd_mob)
		"heap":
			var item: Variant = info.get("item")
			var title: String = str(item.item_name) if item != null else "Discarded pile"
			var text: String = ""
			if item != null:
				text = str(item.description)
			if text.is_empty():
				text = "You see %s lying here." % title.to_lower()
			if int(info.get("count", 1)) > 1:
				text += "\n\nThere is more than one item on this spot."
			_show_text(title, text)
		"plant":
			var plant: Variant = info.get("plant")
			var plant_name: String = str(plant.plant_name) if plant != null else "plant"
			_show_text(plant_name.capitalize(),
				"This plant will activate when someone steps on it.")
		"trap":
			var trap: Variant = info.get("trap")
			var trap_title: String = str(trap.trap_name) if trap != null else "trap"
			_show_text(trap_title.capitalize(),
				"Stepping on this hidden pressure plate will activate the trap.")
		"terrain":
			_show_text(str(info.get("title", "")).capitalize(), str(info.get("text", "")))

## Base-region tile names, following upstream Level.tileName(). Secret doors
## and secret traps deliberately masquerade as wall/floor.
static func terrain_name(terrain: int) -> String:
	match terrain:
		ConstantsData.Terrain.CHASM: return "chasm"
		ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.EMPTY_SP, \
		ConstantsData.Terrain.SECRET_TRAP: return "floor"
		ConstantsData.Terrain.GRASS: return "grass"
		ConstantsData.Terrain.EMPTY_WELL: return "empty well"
		ConstantsData.Terrain.WALL, ConstantsData.Terrain.WALL_DECO, \
		ConstantsData.Terrain.SECRET_DOOR: return "wall"
		ConstantsData.Terrain.DOOR: return "closed door"
		ConstantsData.Terrain.OPEN_DOOR: return "open door"
		ConstantsData.Terrain.ENTRANCE: return "depth entrance"
		ConstantsData.Terrain.EXIT: return "depth exit"
		ConstantsData.Terrain.EMBERS: return "embers"
		ConstantsData.Terrain.LOCKED_DOOR: return "locked door"
		ConstantsData.Terrain.CRYSTAL_DOOR: return "crystal door"
		ConstantsData.Terrain.PEDESTAL: return "pedestal"
		ConstantsData.Terrain.BARRICADE: return "barricade"
		ConstantsData.Terrain.HIGH_GRASS: return "high grass"
		ConstantsData.Terrain.FURROWED_GRASS: return "furrowed grass"
		ConstantsData.Terrain.TRAP: return "trap"
		ConstantsData.Terrain.INACTIVE_TRAP: return "triggered trap"
		ConstantsData.Terrain.WATER: return "water"
		ConstantsData.Terrain.SIGN: return "sign"
		ConstantsData.Terrain.WELL: return "well"
		ConstantsData.Terrain.STATUE, ConstantsData.Terrain.STATUE_SP: return "statue"
		ConstantsData.Terrain.BOOKSHELF: return "bookshelf"
		ConstantsData.Terrain.ALCHEMY: return "alchemy pot"
		ConstantsData.Terrain.WEB: return "web"
	return "unknown terrain"

## Base-region tile descriptions, following upstream Level.tileDesc().
static func terrain_desc(terrain: int) -> String:
	match terrain:
		ConstantsData.Terrain.CHASM:
			return "You can't see the bottom."
		ConstantsData.Terrain.WATER:
			return "In case of burning, step into the water to extinguish the fire."
		ConstantsData.Terrain.ENTRANCE:
			return "The stairs lead up to the upper depth."
		ConstantsData.Terrain.EXIT:
			return "The stairs lead down to the lower depth."
		ConstantsData.Terrain.EMBERS:
			return "Embers cover the floor."
		ConstantsData.Terrain.HIGH_GRASS, ConstantsData.Terrain.FURROWED_GRASS:
			return "Dense vegetation blocks the view."
		ConstantsData.Terrain.LOCKED_DOOR:
			return "This door is locked. You need a matching key to unlock it."
		ConstantsData.Terrain.CRYSTAL_DOOR:
			return "You can see through this crystal door, but you need a matching key to open it."
		ConstantsData.Terrain.PEDESTAL:
			return "Sometimes valuable items are kept on such pedestals."
		ConstantsData.Terrain.BARRICADE:
			return "The wooden barricade is firmly set, but it has dried over the years. Might it burn?"
		ConstantsData.Terrain.EMPTY_WELL:
			return "The well has run dry."
		ConstantsData.Terrain.WELL:
			return "The waters of this well have magic properties."
		ConstantsData.Terrain.STATUE, ConstantsData.Terrain.STATUE_SP:
			return "Someone wanted to adorn this place long ago, but failed."
		ConstantsData.Terrain.INACTIVE_TRAP:
			return "The trap has been triggered before, and it is no longer dangerous."
		ConstantsData.Terrain.TRAP:
			return "Stepping on this hidden pressure plate will activate the trap."
		ConstantsData.Terrain.BOOKSHELF:
			return "It is hard to tell what these books are about."
		ConstantsData.Terrain.ALCHEMY:
			return "Alchemical energy radiates from this pot. Materials can be combined here."
		ConstantsData.Terrain.SIGN:
			return "A dungeon sign. Someone left a message here."
		ConstantsData.Terrain.WEB:
			return "Sticky spider webs. Moving through them takes extra effort."
	return "You are not sure what this is."

static func _flag(arr: Variant, cell: int) -> bool:
	if not (arr is Array):
		return false
	var a: Array = arr
	if cell >= a.size():
		return false
	return bool(a[cell])

static func _show(wnd: Control) -> void:
	if EventBus:
		EventBus.show_window.emit(wnd)

static func _show_text(title: String, text: String) -> void:
	var wnd: WndInfoCell = WndInfoCell.new()
	wnd.setup(title, text)
	_show(wnd)
