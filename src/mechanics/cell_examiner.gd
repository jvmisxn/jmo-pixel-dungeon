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
	var depth: int = int(level.depth)
	return {
		"kind": "terrain",
		"terrain": terrain,
		"title": terrain_name(terrain, depth),
		"text": terrain_desc(terrain, depth),
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
			_show_text(plant_name.capitalize(), plant_desc(plant))
		"trap":
			var trap: Variant = info.get("trap")
			var trap_title: String = str(trap.trap_name) if trap != null else "trap"
			_show_text(trap_title.capitalize(), trap_desc(trap))
		"terrain":
			_show_text(str(info.get("title", "")).capitalize(), str(info.get("text", "")))

## Region-specific tile name overrides, mirroring upstream SewerLevel/
## PrisonLevel/CavesLevel/CityLevel/HallsLevel tileName(). The port has no
## EMPTY_DECO/REGION_DECO/ENTRANCE_SP terrains, so those upstream entries
## are intentionally absent.
const REGION_TILE_NAMES: Dictionary = {
	ConstantsData.Region.SEWERS: {
		ConstantsData.Terrain.WATER: "murky water",
	},
	ConstantsData.Region.PRISON: {
		ConstantsData.Terrain.WATER: "dark cold water",
	},
	ConstantsData.Region.CAVES: {
		ConstantsData.Terrain.GRASS: "fluorescent moss",
		ConstantsData.Terrain.HIGH_GRASS: "fluorescent mushrooms",
		ConstantsData.Terrain.WATER: "freezing cold water",
	},
	ConstantsData.Region.CITY: {
		ConstantsData.Terrain.WATER: "suspiciously colored water",
		ConstantsData.Terrain.HIGH_GRASS: "high blooming flowers",
	},
	ConstantsData.Region.HALLS: {
		ConstantsData.Terrain.WATER: "cold lava",
		ConstantsData.Terrain.GRASS: "embermoss",
		ConstantsData.Terrain.HIGH_GRASS: "emberfungi",
		ConstantsData.Terrain.STATUE: "pillar",
		ConstantsData.Terrain.STATUE_SP: "pillar",
	},
}

## Region-specific tile description overrides, mirroring the same upstream
## per-region tileDesc() switches (levels.properties strings).
const REGION_TILE_DESCS: Dictionary = {
	ConstantsData.Region.SEWERS: {
		ConstantsData.Terrain.BOOKSHELF:
			"The bookshelf is packed with cheap useless books. Might it burn?",
	},
	ConstantsData.Region.PRISON: {
		ConstantsData.Terrain.BOOKSHELF:
			"This is probably a vestige of a prison library. Might it burn?",
	},
	ConstantsData.Region.CAVES: {
		ConstantsData.Terrain.ENTRANCE: "The ladder leads up to the upper depth.",
		ConstantsData.Terrain.EXIT: "The ladder leads down to the lower depth.",
		ConstantsData.Terrain.HIGH_GRASS: "Huge mushrooms block the view.",
		ConstantsData.Terrain.WALL_DECO: "A vein of some ore is visible on the wall. Gold?",
		ConstantsData.Terrain.BOOKSHELF: "Who would need a bookshelf in a cave?",
	},
	ConstantsData.Region.CITY: {
		ConstantsData.Terrain.ENTRANCE: "A ramp leads up to the upper depth.",
		ConstantsData.Terrain.EXIT: "A ramp leads down to the lower depth.",
		ConstantsData.Terrain.WALL_DECO: "Several tiles are missing here.",
		ConstantsData.Terrain.EMPTY_SP: "Thick carpet covers the floor.",
		ConstantsData.Terrain.STATUE:
			"The statue depicts some dwarf standing in a heroic stance.",
		ConstantsData.Terrain.STATUE_SP:
			"The statue depicts some dwarf standing in a heroic stance.",
		ConstantsData.Terrain.BOOKSHELF:
			"The rows of books on different disciplines fill the bookshelf.",
	},
	ConstantsData.Region.HALLS: {
		ConstantsData.Terrain.WATER:
			"It looks like lava, but it's cold and probably safe to touch.",
		ConstantsData.Terrain.STATUE: "The pillar is made of real humanoid skulls. Awesome.",
		ConstantsData.Terrain.STATUE_SP: "The pillar is made of real humanoid skulls. Awesome.",
		ConstantsData.Terrain.BOOKSHELF:
			"Books in ancient languages smoulder in the bookshelf.",
	},
}

## Base-region tile names, following upstream Level.tileName(). Secret doors
## and secret traps deliberately masquerade as wall/floor. Depth selects the
## per-region overrides above, matching upstream level subclasses.
static func terrain_name(terrain: int, depth: int = 1) -> String:
	var region_names: Dictionary = REGION_TILE_NAMES.get(
		ConstantsData.region_for_depth(depth), {})
	if region_names.has(terrain):
		return String(region_names[terrain])
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

## Base-region tile descriptions, following upstream Level.tileDesc(), with
## depth-driven per-region overrides matching upstream level subclasses.
static func terrain_desc(terrain: int, depth: int = 1) -> String:
	var region_descs: Dictionary = REGION_TILE_DESCS.get(
		ConstantsData.region_for_depth(depth), {})
	if region_descs.has(terrain):
		return String(region_descs[terrain])
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

const GENERIC_TRAP_DESC: String = "Stepping on this hidden pressure plate will activate the trap."
const GENERIC_PLANT_DESC: String = "This plant will activate when someone steps on it."

## Upstream trap descriptions (messages/levels/levels.properties,
## `levels.traps.<class>.desc`), keyed by the port's `trap_name`. "fire trap"
## carries upstream BurningTrap's text; "paralytic gas trap" is a classic trap
## the port kept, so its text is adapted in the upstream style.
const TRAP_DESCS: Dictionary = {
	"alarm trap": "This trap seems to be tied to a loud alarm mechanism. Triggering it will likely alert everything on the level.",
	"blazing trap": "Stepping on this trap will ignite a powerful chemical mixture, setting a wide area ablaze.",
	"chilling trap": "When activated, chemicals in this trap will rapidly freeze the air around its location.",
	"confusion gas trap": "Triggering this trap will set a cloud of confusion gas loose within the immediate area.",
	"corrosion trap": "Triggering this trap will set a cloud of deadly acidic gas loose within the immediate area.",
	"cursing trap": "This trap contains the same malevolent magic found in cursed equipment. Triggering it will curse some items in the immediate area.",
	"disarming trap": "This trap contains very specific teleportation magic, which will warp the weapon of its victim to some other location.",
	"disintegration trap": "When triggered, this trap will lance the nearest target with beams of disintegration, dealing significant damage and destroying items.\n\nThankfully the trigger mechanism isn't hidden.",
	"distortion trap": "Built from strange magic of unknown origin, this trap will summon all manner of creatures to this location.",
	"explosive trap": "This trap contains some powdered explosive and a trigger mechanism. Activating it will cause an explosion in the immediate area.",
	"fire trap": "Stepping on this trap will ignite a chemical mixture, setting the surrounding area aflame.",
	"flashing trap": "On activation, this trap will ignite a potent flashing powder stored within, temporarily blinding, crippling, and injuring its victim.\n\nThe trap must have a large store of powder, as it can activate many times without breaking.",
	"flock trap": "Perhaps a joke from some amateur mage, triggering this trap will create a flock of magical sheep.",
	"frost trap": "When activated, chemicals in this trap will rapidly freeze the air in a wide range around its location.",
	"gateway trap": "This special teleportation trap can activate an infinite numbers of times and always teleports to the same location.",
	"geyser trap": "When triggered, this trap will cause a geyser of water to spew forth, damaging fiery enemies, knocking away all nearby characters, dousing fires, and converting the surrounding terrain to water.",
	"grim trap": "Extremely powerful destructive magic is stored within this trap, enough to instantly kill all but the healthiest of heroes. Triggering it will send a ranged blast of lethal magic towards the nearest character.\n\nThankfully the trigger mechanism isn't hidden.",
	"gripping trap": "This trap latches onto the feet of whoever trigger it, damaging them and slowing their movement.\n\nDue to its simple nature, this trap can activate many times without breaking.",
	"guardian trap": "This trap is tied to a strange magical mechanism, which will summon guardians and alert all enemies on the floor.",
	"ooze trap": "This trap will splash out caustic ooze when activated, which will burn until it is washed away.",
	"paralytic gas trap": "Triggering this trap will set a cloud of paralysing gas loose within the immediate area.",
	"pitfall trap": "This trap is connected to a large trapdoor mechanism, and shortly after it is triggered anything near it will slip right through the ground and fall! It won't work in areas with especially solid floors though.",
	"poison dart trap": "A small dart-blower must be hidden nearby, activating this trap will cause it to shoot a poisoned dart at the nearest target.\n\nThankfully the trigger mechanism isn't hidden.",
	"rockfall trap": "This trap is connected to a series of loose rocks above, triggering it will cause them to come crashing down over the entire room! If the trap isn't in a specific room, rocks will fall in an area around the trap instead.\n\nThankfully the trigger mechanism isn't hidden.",
	"shocking trap": "A mechanism with a large amount of energy stored into it. Triggering this trap will discharge that energy into a field around it.",
	"storm trap": "A mechanism with a massive amount of energy stored into it. Triggering this trap will discharge that energy into a large electrical storm.",
	"summoning trap": "Triggering this trap will summon a number of this area's monsters to this location.",
	"teleportation trap": "Whenever this trap is triggered, everything around it will be teleported to random locations on this floor.",
	"toxic gas trap": "Triggering this trap will set a cloud of toxic gas loose within the surrounding area.",
	"warping trap": "This trap is similar to a teleportation trap, but will also cause the hero to lose their knowledge of the floor's layout!",
	"weakening trap": "Dark magic in this trap sucks the energy out of anything that comes into contact with it. Powerful enemies may resist the effect, however.",
	"worn dart trap": "A small dart-blower must be hidden nearby, activating this trap will cause it to shoot at the nearest target.\n\nDue to its age it's not very harmful though, it isn't even hidden...",
}

## Upstream plant descriptions (messages/plants/plants.properties), keyed by
## `plant_name`. Dreamfoil keeps its pre-rename identity in this port (upstream
## renamed it to Mageroyal), so its text is the upstream cleansing description
## adapted to also cover the port's sleep-lesser-creatures behavior.
const PLANT_DESCS: Dictionary = {
	"Blindweed": "Upon being touched a blindweed perishes in a bright flash of light. The flash is strong enough to disorient for several seconds.",
	"Dreamfoil": "The dreamfoil's prickly flowers contain a chemical which is known for its properties as a strong neutralizing agent. Anything that steps in this plant will be cleansed of many mind-affecting ailments, while lesser creatures are lulled into a deep sleep.",
	"Earthroot": "When a creature touches an earthroot, its roots create a kind of immobile natural armor around it.",
	"Fadeleaf": "Touching a fadeleaf will teleport any creature to a random place on the current level.",
	"Firebloom": "When something touches a firebloom, it bursts into flames.",
	"Icecap": "Upon being touched, an icecap lets out a puff of freezing pollen. The freezing effect is much stronger if the environment is wet.",
	"Rotberry": "The berries of a young rotberry shrub taste like sweet, sweet death. Over a few years, this rotberry shrub will grow into another rot heart. When trampled, a young rotberry will produce a small puff of toxic gas.",
	"Sorrowmoss": "A sorrowmoss is a flower (not a moss) with razor-sharp petals, coated with a deadly venom.",
	"Starflower": "A rare plant, starflower is said to grant holy power to whomever touches it.",
	"Stormvine": "Gravity affects the stormvine plant strangely, allowing its whispy blue tendrils to 'hang' on the air. Anything caught in the vine is affected by this, and becomes disoriented.",
	"Sungrass": "Sungrass is renowned for its sap's slow but effective healing properties.",
	"Swiftthistle": "When trampled, swiftthistle will briefly accelerate the flow of time around it, allowing the trampler to perform several actions instantly.",
}

## Full examine text for a revealed trap, falling back to the generic
## pressure-plate line for unknown trap types.
static func trap_desc(trap: Variant) -> String:
	if trap == null:
		return GENERIC_TRAP_DESC
	return String(TRAP_DESCS.get(str(trap.trap_name), GENERIC_TRAP_DESC))

## Full examine text for a plant, falling back to a generic activation line.
static func plant_desc(plant: Variant) -> String:
	if plant == null:
		return GENERIC_PLANT_DESC
	return String(PLANT_DESCS.get(str(plant.plant_name), GENERIC_PLANT_DESC))

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
