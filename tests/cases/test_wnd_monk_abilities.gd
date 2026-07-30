extends RefCounted
## Monk ability picker window (upstream WndMonkAbilities): lists all five
## abilities with energy-cost gating (plus Flurry cooldown / Focus stance
## gates), performs untargeted abilities directly, enters targeting for
## targeted ones, and opens from the Monk Energy buff icon instead of the
## plain buff-info window.

var _last_action: Dictionary = {}
var _targeting_range: int = -1
var _targeting_callback: Callable = Callable()


func run(t: Object) -> void:
	EventBus.request_hero_action.connect(_on_request_hero_action)
	EventBus.enter_targeting.connect(_on_enter_targeting)

	_test_usable_gating(t)
	_test_focus_action_direct(t)
	_test_dash_targeting(t)
	_test_buff_icon_routing(t)

	EventBus.request_hero_action.disconnect(_on_request_hero_action)
	EventBus.enter_targeting.disconnect(_on_enter_targeting)


func _on_request_hero_action(action: Dictionary) -> void:
	_last_action = action


func _on_enter_targeting(_item: Variant, max_range: int, callback: Callable) -> void:
	_targeting_range = max_range
	_targeting_callback = callback


func _make_monk() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.MONK
	return hero


func _energy_of(hero: Hero) -> MonkEnergy:
	var energy: MonkEnergy = hero.get_buff("MonkEnergy") as MonkEnergy
	if energy == null:
		energy = hero.add_buff(MonkEnergy.new()) as MonkEnergy
	return energy


func _test_usable_gating(t: Object) -> void:
	var hero := _make_monk()
	var energy: MonkEnergy = _energy_of(hero)
	var wnd := WndMonkAbilities.new()
	wnd.setup(hero)

	energy.energy = 0.0
	t.check(not wnd.ability_usable("flurry"),
		"flurry is unusable with no energy")
	t.check(not wnd.ability_usable("meditate"),
		"meditate is unusable with no energy")

	energy.energy = 10.0
	t.check(wnd.ability_usable("flurry"), "flurry is usable at full energy")
	t.check(wnd.ability_usable("focus"), "focus is usable at full energy")
	t.check(wnd.ability_usable("dash"), "dash is usable at full energy")
	t.check(wnd.ability_usable("dragon_kick"),
		"dragon kick is usable at full energy")
	t.check(wnd.ability_usable("meditate"),
		"meditate is usable at full energy")

	energy.energy = 4.0
	t.check(not wnd.ability_usable("meditate"),
		"meditate is cost-gated below 5 energy")
	t.check(wnd.ability_usable("dragon_kick"),
		"dragon kick is usable at exactly 4 energy")

	energy.energy = 10.0
	hero.add_buff(FlurryCooldownTracker.new())
	t.check(not wnd.ability_usable("flurry"),
		"flurry is gated by its once-per-turn cooldown (upstream Flurry.usable)")
	t.check(wnd.ability_usable("dash"),
		"flurry cooldown does not gate other abilities")

	hero.add_buff(FocusBuff.new())
	t.check(not wnd.ability_usable("focus"),
		"focus is gated while already focused (upstream Focus.usable)")

	wnd.free()
	hero.free()


func _test_focus_action_direct(t: Object) -> void:
	var hero := _make_monk()
	var energy: MonkEnergy = _energy_of(hero)
	energy.energy = 10.0
	var wnd := WndMonkAbilities.new()
	wnd.setup(hero)

	_last_action = {}
	wnd._use_ability("focus")
	t.check(str(_last_action.get("type", "")) == "monk_ability",
		"picking focus submits a monk_ability action")
	t.check(str(_last_action.get("kind", "")) == "focus",
		"picking focus submits the focus kind")
	t.check(not _last_action.has("target_pos"),
		"untargeted focus submits without a target")

	_last_action = {}
	var wnd2 := WndMonkAbilities.new()
	wnd2.setup(hero)
	wnd2._use_ability("meditate")
	t.check(str(_last_action.get("kind", "")) == "meditate",
		"picking meditate submits the meditate kind directly")

	wnd.free()
	wnd2.free()
	hero.free()


func _test_dash_targeting(t: Object) -> void:
	var hero := _make_monk()
	var energy: MonkEnergy = _energy_of(hero)
	energy.energy = 5.0
	var wnd := WndMonkAbilities.new()
	wnd.setup(hero)

	t.check(wnd.targeting_range("dash") == 4,
		"dash targets range 4 when not empowered")
	t.check(wnd.targeting_range("flurry") == 1,
		"flurry targets melee reach")
	t.check(wnd.targeting_range("dragon_kick") == 1,
		"dragon kick targets melee reach")

	energy.energy = float(energy.energy_cap())
	if energy.abilities_empowered():
		t.check(wnd.targeting_range("dash") == 8,
			"dash targets range 8 while abilities are empowered")

	_last_action = {}
	_targeting_range = -1
	_targeting_callback = Callable()
	wnd._use_ability("dash")
	t.check(_targeting_range > 0,
		"picking dash enters targeting instead of acting immediately")
	t.check(_last_action.is_empty(),
		"targeted abilities submit no action until a cell is chosen")
	if _targeting_callback.is_valid():
		_targeting_callback.call(42)
	t.check(str(_last_action.get("kind", "")) == "dash",
		"selecting a cell submits the dash monk_ability action")
	t.check(int(_last_action.get("target_pos", -1)) == 42,
		"selecting a cell forwards the chosen target position")

	wnd.free()
	hero.free()


func _test_buff_icon_routing(t: Object) -> void:
	var hero := _make_monk()
	var energy: MonkEnergy = _energy_of(hero)
	energy.energy = 3.0

	var icon := BuffIcon.new()
	icon.buff_ref = energy
	var wnd: WndBase = icon.make_info_window()
	t.check(wnd is WndMonkAbilities,
		"tapping the Monk Energy buff icon opens the ability picker")
	if wnd != null:
		wnd.free()

	var other := BuffIcon.new()
	var bless := Bless.new()
	other.buff_ref = bless
	var info: WndBase = other.make_info_window()
	t.check(info is WndInfoBuff and not (info is WndMonkAbilities),
		"other buff icons still open the plain buff-info window")
	if info != null:
		info.free()

	icon.free()
	other.free()
	bless.free()
	hero.free()
