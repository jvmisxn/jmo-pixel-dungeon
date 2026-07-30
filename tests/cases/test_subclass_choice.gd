extends RefCounted
## Subclass acquisition parity (upstream TengusMask + WndChooseSubclass,
## adapted to the port's Potion of Mastery). Covers:
##   - drinking the potion opens WndChooseSubclass instead of silently
##     auto-picking subclasses[0]
##   - nothing is spent/consumed until a subclass is chosen; cancelling
##     keeps the potion
##   - choosing routes through SubclassAbilities.apply_subclass so the
##     subclass perks are actually granted, and consumes the potion
##   - an already-subclassed hero is refused without consuming
##   - Tengu drops the mastery potion on death (upstream Tengu.die drops
##     Tengu's Mask)

var _shown_window: WndBase = null


## Minimal Level stand-in that records dropped items at their cell.
class StubLevel:
	extends RefCounted
	var drops: Array = []  # [{pos, item}]
	func drop_item(pos: int, item: Variant, _heap_type: String = "heap") -> Dictionary:
		drops.append({"pos": pos, "item": item})
		return {}


func run(t: Object) -> void:
	EventBus.show_window.connect(_on_show_window)

	_test_drink_opens_choice_window(t)
	_test_cancel_keeps_potion(t)
	_test_choose_applies_subclass_and_consumes(t)
	_test_already_subclassed_refused(t)
	_test_tengu_drops_mastery(t)

	EventBus.show_window.disconnect(_on_show_window)


func _on_show_window(wnd: Variant) -> void:
	_shown_window = wnd as WndBase


func _make_hero_with_potion() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var potion: Item = Potion.create("mastery")
	hero.belongings.add_item(potion)
	return hero


func _find_potion(hero: Hero) -> Item:
	for item: Item in hero.belongings.backpack:
		if item.item_id == "mastery":
			return item
	return null


func _test_drink_opens_choice_window(t: Object) -> void:
	var hero := _make_hero_with_potion()
	var potion: Item = _find_potion(hero)
	_shown_window = null
	potion.execute(hero)

	t.check(_shown_window is WndChooseSubclass,
		"drinking the mastery potion opens the subclass choice window")
	t.check(hero.hero_subclass == ConstantsData.HeroSubclass.NONE,
		"no subclass is auto-picked just by drinking")
	t.check(_find_potion(hero) != null,
		"the potion is not consumed before a choice is made")

	if _shown_window != null:
		_shown_window.free()
		_shown_window = null
	hero.free()


func _test_cancel_keeps_potion(t: Object) -> void:
	var hero := _make_hero_with_potion()
	var potion: Item = _find_potion(hero)
	_shown_window = null
	potion.execute(hero)

	if _shown_window != null:
		_shown_window.close_window()
	t.check(hero.hero_subclass == ConstantsData.HeroSubclass.NONE,
		"cancelling the window leaves the hero unspecialized")
	t.check(_find_potion(hero) != null,
		"cancelling the window keeps the potion")

	if _shown_window != null:
		_shown_window.free()
		_shown_window = null
	hero.free()


func _test_choose_applies_subclass_and_consumes(t: Object) -> void:
	var hero := _make_hero_with_potion()
	var potion: Item = _find_potion(hero)
	_shown_window = null
	potion.execute(hero)

	var wnd: WndChooseSubclass = _shown_window as WndChooseSubclass
	t.check(wnd != null, "the shown window is a WndChooseSubclass")
	if wnd != null:
		wnd.choose(ConstantsData.HeroSubclass.BERSERKER)

	t.check(hero.hero_subclass == ConstantsData.HeroSubclass.BERSERKER,
		"choosing sets the hero's subclass")
	t.check(hero.get_buff("BerserkerRage") != null,
		"choosing routes through apply_subclass so perks are granted")
	t.check(_find_potion(hero) == null,
		"choosing consumes the mastery potion")
	t.check(potion.identified,
		"choosing identifies the mastery potion")

	if _shown_window != null:
		_shown_window.free()
		_shown_window = null
	hero.free()
	if GameManager:
		GameManager.hero_subclass = ConstantsData.HeroSubclass.NONE


func _test_already_subclassed_refused(t: Object) -> void:
	var hero := _make_hero_with_potion()
	hero.hero_subclass = ConstantsData.HeroSubclass.GLADIATOR
	var potion: Item = _find_potion(hero)
	_shown_window = null
	potion.execute(hero)

	t.check(_shown_window == null,
		"an already-subclassed hero gets no choice window")
	t.check(_find_potion(hero) != null,
		"an already-subclassed hero keeps the potion")
	t.check(hero.hero_subclass == ConstantsData.HeroSubclass.GLADIATOR,
		"the existing subclass is untouched")

	hero.free()


func _test_tengu_drops_mastery(t: Object) -> void:
	var tengu: Tengu = Tengu.new()
	var level: StubLevel = StubLevel.new()
	tengu.level = level
	tengu.pos = ConstantsData.xy_to_pos(16, 16)
	tengu._on_death(null)

	var mastery_drops: int = 0
	var mastery_pos: int = -1
	for entry: Dictionary in level.drops:
		var item: Item = entry["item"] as Item
		if item != null and item.item_id == "mastery":
			mastery_drops += 1
			mastery_pos = entry["pos"]
	t.check(mastery_drops == 1,
		"Tengu drops exactly one mastery potion on death (upstream Tengu's Mask)")
	t.check(mastery_pos == ConstantsData.xy_to_pos(16, 16),
		"the mastery potion drops at Tengu's position")
