class_name WndChooseSubclass
extends WndBase
## Subclass choice window (upstream WndChooseSubclass): lists the hero
## class's two subclasses with their descriptions and perk summaries.
## Choosing one applies the subclass through SubclassAbilities, spends a
## turn, and consumes the Potion of Mastery (this port's stand-in for
## upstream Tengu's Mask). Cancel closes without cost and keeps the potion.

var _hero: Hero = null
var _potion: Potion = null


func _init() -> void:
	window_title = "Choose Your Path"
	custom_minimum_size = Vector2(340, 200)


func setup(hero: Hero, potion: Potion) -> void:
	_hero = hero
	_potion = potion
	refresh_content()


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	if _hero == null:
		return main

	var intro: Label = Label.new()
	intro.text = "Drinking this potion will let you specialize. This choice is permanent."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	main.add_child(intro)

	for subclass: int in ConstantsData.subclasses_for(_hero.hero_class):
		if subclass == ConstantsData.HeroSubclass.NONE:
			continue
		var info: SubclassAbilities.SubclassInfo = \
			SubclassAbilities.get_subclass_info(subclass)
		var button: Button = Button.new()
		button.text = info.name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(choose.bind(subclass))
		main.add_child(button)

		var desc: Label = Label.new()
		var lines: Array[String] = [info.description]
		for perk: String in info.perks:
			lines.append("- %s" % perk)
		desc.text = "\n".join(lines)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		main.add_child(desc)

	var cancel: Button = Button.new()
	cancel.text = "Not yet"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close_window)
	main.add_child(cancel)

	return main


## Upstream TengusMask.choose: detach the item and set the subclass.
## Routed through SubclassAbilities.apply_subclass so passive perks are
## actually granted (the old auto-pick path skipped them). The turn cost
## is already charged by Hero.execute_action's use_item branch.
func choose(subclass: int) -> void:
	if _hero == null or _hero.hero_subclass != ConstantsData.HeroSubclass.NONE:
		close_window()
		return
	SubclassAbilities.apply_subclass(_hero, subclass)
	if _hero.has_method("on_potion_used"):
		_hero.on_potion_used()
	if _potion != null:
		_potion.identify()
		_potion._consume(_hero)
	close_window()
