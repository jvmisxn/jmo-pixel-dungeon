class_name WndMonkAbilities
extends WndBase
## Monk ability picker (upstream WndMonkAbilities): lists the five monk
## abilities with their energy costs. Tapping an ability closes the window
## and either performs it directly (Focus, Meditate) or enters targeting
## (Flurry, Dash, Dragon Kick). Buttons follow upstream
## MonkAbility.usable(): energy cost gate, plus Flurry's once-per-turn
## cooldown and Focus's already-focused gate. Opened by tapping the Monk
## Energy buff icon (port stand-in for the upstream ActionIndicator).

const ABILITIES: Array[Dictionary] = [
	{
		"kind": "flurry",
		"name": "Flurry",
		"cost": 1.0,
		"targeted": true,
		"desc": "Instantly strike an adjacent enemy twice with unarmed attacks. Once per turn.",
	},
	{
		"kind": "focus",
		"name": "Focus",
		"cost": 2.0,
		"targeted": false,
		"desc": "Enter a defensive stance and parry the next attack that would hit you.",
	},
	{
		"kind": "dash",
		"name": "Dash",
		"cost": 3.0,
		"targeted": true,
		"desc": "Instantly dash to an empty cell in a straight line.",
	},
	{
		"kind": "dragon_kick",
		"name": "Dragon Kick",
		"cost": 4.0,
		"targeted": true,
		"desc": "Deliver a devastating unarmed kick that knocks an adjacent enemy back, paralyzing it if it hits a wall.",
	},
	{
		"kind": "meditate",
		"name": "Meditate",
		"cost": 5.0,
		"targeted": false,
		"desc": "Meditate for 5 turns, cleansing harmful effects and gaining recharging afterward.",
	},
]

var _hero: Hero = null


func _init() -> void:
	window_title = "Monk Abilities"
	custom_minimum_size = Vector2(320, 180)


func setup(hero: Hero) -> void:
	_hero = hero
	refresh_content()


func _get_energy() -> MonkEnergy:
	if _hero == null:
		return null
	return _hero.get_buff("MonkEnergy") as MonkEnergy


## Upstream MonkAbility.usable(): energy >= cost, plus per-ability gates
## (Flurry: no FlurryCooldownTracker; Focus: no active FocusBuff).
func ability_usable(kind: String) -> bool:
	var energy: MonkEnergy = _get_energy()
	if energy == null or _hero == null:
		return false
	var cost: float = 0.0
	for abil: Dictionary in ABILITIES:
		if str(abil.get("kind", "")) == kind:
			cost = float(abil.get("cost", 0.0))
			break
	if energy.energy < cost:
		return false
	if kind == "flurry" and _hero.has_buff("FlurryCooldownTracker"):
		return false
	if kind == "focus" and _hero.has_buff("FocusBuff"):
		return false
	return true


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	if _hero == null:
		return main

	var energy: MonkEnergy = _get_energy()
	var header: Label = Label.new()
	if energy != null:
		header.text = "Energy: %s/%d" % [_format_energy(energy.energy), energy.energy_cap()]
		if energy.abilities_empowered():
			header.text += "  (abilities empowered!)"
	else:
		header.text = "Energy: 0"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.63, 0.53, 0.25))
	main.add_child(header)

	for abil: Dictionary in ABILITIES:
		var kind: String = str(abil.get("kind", ""))
		var button: Button = Button.new()
		button.text = "%s (%d energy)" % [str(abil.get("name", "")), int(abil.get("cost", 0.0))]
		button.disabled = not ability_usable(kind)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_use_ability.bind(kind))
		main.add_child(button)

		var desc: Label = Label.new()
		desc.text = str(abil.get("desc", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		main.add_child(desc)

	return main


static func _format_energy(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _use_ability(kind: String) -> void:
	var targeted: bool = false
	for abil: Dictionary in ABILITIES:
		if str(abil.get("kind", "")) == kind:
			targeted = bool(abil.get("targeted", false))
			break
	if not targeted:
		if EventBus and EventBus.has_signal("request_hero_action"):
			EventBus.request_hero_action.emit({"type": "monk_ability", "kind": kind})
		close_window()
		return
	if MessageLog:
		match kind:
			"dash":
				MessageLog.add("Choose a place to dash to.")
			_:
				MessageLog.add("Choose an enemy to strike.")
	if EventBus:
		EventBus.enter_targeting.emit(null, targeting_range(kind), _on_target_selected.bind(kind))
	close_window()


## Targeting range per ability: melee reach for Flurry/Dragon Kick, Dash's
## 4-cell blink (8 while empowered, upstream MonkAbility.Dash range).
func targeting_range(kind: String) -> int:
	if kind == "dash":
		var energy: MonkEnergy = _get_energy()
		if energy != null and energy.abilities_empowered():
			return 8
		return 4
	return 1


func _on_target_selected(target_cell: int, kind: String) -> void:
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({
			"type": "monk_ability", "kind": kind, "target_pos": target_cell,
		})
