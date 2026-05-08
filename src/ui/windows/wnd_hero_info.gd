class_name WndHeroInfo
extends WndBase
## Hero information window showing stats, buffs, and run statistics.

var _hero: Hero = null


func _init() -> void:
	window_title = "Hero Info"
	custom_minimum_size = Vector2(380, 440)


func _build_content() -> Control:
	_hero = GameManager.hero if GameManager else null

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	scroll.add_child(main)

	if not _hero:
		var no_hero: Label = Label.new()
		no_hero.text = "No hero data available."
		main.add_child(no_hero)
		return scroll

	# --- Class & Name ---
	var class_name_str: String = HeroClassData.get_class_name_str(_hero.hero_class)
	var title_label: Label = Label.new()
	title_label.text = class_name_str
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title_label)

	# Subclass
	if _hero.hero_subclass != ConstantsData.HeroSubclass.NONE:
		var sub_label: Label = Label.new()
		sub_label.text = _get_subclass_name(_hero.hero_subclass)
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		main.add_child(sub_label)

	# --- Portrait placeholder ---
	var portrait: ColorRect = ColorRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.color = _get_class_color(_hero.hero_class)
	var portrait_center: CenterContainer = CenterContainer.new()
	portrait_center.add_child(portrait)
	main.add_child(portrait_center)

	# --- Core Stats ---
	var sep1: HSeparator = HSeparator.new()
	main.add_child(sep1)

	var stats_grid: GridContainer = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 4)
	main.add_child(stats_grid)

	_add_stat_row(stats_grid, "Level", "%d" % _hero.hero_level)
	_add_stat_row(stats_grid, "Experience", "%d / %d" % [_hero.xp, _hero.xp_to_next])
	_add_stat_row(stats_grid, "HP", "%d / %d" % [_hero.hp, _hero.hp_max])
	_add_stat_row(stats_grid, "Max HP (HT)", "%d" % _hero.ht)
	_add_stat_row(stats_grid, "Strength", "%d" % _hero.str_val)
	_add_stat_row(stats_grid, "Attack Skill", "%d" % _hero.attack_skill)
	_add_stat_row(stats_grid, "Defense Skill", "%d" % _hero.defense_skill)

	# Effective damage
	var dmg_range: Array[int] = [_hero.damage_roll_min, _hero.damage_roll_max]
	if _hero.belongings and _hero.belongings.weapon:
		dmg_range = _hero.belongings.weapon_damage_range()
	_add_stat_row(stats_grid, "Damage", "%d-%d" % [dmg_range[0], dmg_range[1]])

	# Effective armor
	var armor_val: int = _hero.effective_armor() if _hero.has_method("effective_armor") else 0
	_add_stat_row(stats_grid, "Armor", "%d" % armor_val)

	# --- Active Buffs ---
	var sep2: HSeparator = HSeparator.new()
	main.add_child(sep2)

	var buffs_title: Label = Label.new()
	buffs_title.text = "Active Effects"
	buffs_title.add_theme_font_size_override("font_size", 16)
	main.add_child(buffs_title)

	var buffs_array: Array = _hero.buffs if _hero.get("buffs") else []
	if buffs_array.is_empty():
		var no_buffs: Label = Label.new()
		no_buffs.text = "None"
		no_buffs.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		main.add_child(no_buffs)
	else:
		for buff: Variant in buffs_array:
			var buff_row: HBoxContainer = HBoxContainer.new()
			var buff_name: Label = Label.new()
			buff_name.text = ConstantsData.get_prop(buff, "buff_name", ConstantsData.get_prop(buff, "name", "Unknown"))
			buff_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var buff_color: Color = Color(0.6, 1.0, 0.6) if not ConstantsData.get_prop(buff, "is_debuff", false) else Color(1.0, 0.5, 0.5)
			buff_name.add_theme_color_override("font_color", buff_color)
			buff_row.add_child(buff_name)

			if buff.has_method("get_description"):
				var buff_desc: Label = Label.new()
				buff_desc.text = buff.get_description()
				buff_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				buff_row.add_child(buff_desc)
			elif ConstantsData.get_prop(buff, "turns_remaining", -1) > 0:
				var turns_label: Label = Label.new()
				turns_label.text = "(%d turns)" % buff.turns_remaining
				turns_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				buff_row.add_child(turns_label)

			main.add_child(buff_row)

	# --- Run Statistics ---
	var sep3: HSeparator = HSeparator.new()
	main.add_child(sep3)

	var stats_title: Label = Label.new()
	stats_title.text = "Statistics"
	stats_title.add_theme_font_size_override("font_size", 16)
	main.add_child(stats_title)

	var run_stats: Dictionary = GameManager.stats if GameManager and GameManager.get("stats") else {}
	var stats_grid2: GridContainer = GridContainer.new()
	stats_grid2.columns = 2
	stats_grid2.add_theme_constant_override("h_separation", 16)
	stats_grid2.add_theme_constant_override("v_separation", 4)
	main.add_child(stats_grid2)

	_add_stat_row(stats_grid2, "Enemies Slain", "%d" % run_stats.get("enemies_slain", 0))
	_add_stat_row(stats_grid2, "Items Collected", "%d" % run_stats.get("items_collected", 0))
	_add_stat_row(stats_grid2, "Damage Dealt", "%d" % run_stats.get("damage_dealt", 0))
	_add_stat_row(stats_grid2, "Damage Taken", "%d" % run_stats.get("damage_taken", 0))
	_add_stat_row(stats_grid2, "Food Eaten", "%d" % run_stats.get("food_eaten", 0))
	_add_stat_row(stats_grid2, "Potions Used", "%d" % run_stats.get("potions_used", 0))
	_add_stat_row(stats_grid2, "Scrolls Read", "%d" % run_stats.get("scrolls_read", 0))
	_add_stat_row(stats_grid2, "Deepest Floor", "%d" % run_stats.get("deepest_floor", 0))

	return scroll


func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	grid.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	grid.add_child(val)


func _get_subclass_name(subclass: int) -> String:
	match subclass:
		ConstantsData.HeroSubclass.BERSERKER: return "Berserker"
		ConstantsData.HeroSubclass.GLADIATOR: return "Gladiator"
		ConstantsData.HeroSubclass.BATTLEMAGE: return "Battlemage"
		ConstantsData.HeroSubclass.WARLOCK: return "Warlock"
		ConstantsData.HeroSubclass.ASSASSIN: return "Assassin"
		ConstantsData.HeroSubclass.FREERUNNER: return "Freerunner"
		ConstantsData.HeroSubclass.SNIPER: return "Sniper"
		ConstantsData.HeroSubclass.WARDEN: return "Warden"
		ConstantsData.HeroSubclass.CHAMPION: return "Champion"
		ConstantsData.HeroSubclass.MONK: return "Monk"
	return ""


func _get_class_color(hero_class: int) -> Color:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR: return Color(0.8, 0.3, 0.2)
		ConstantsData.HeroClass.MAGE: return Color(0.3, 0.3, 0.9)
		ConstantsData.HeroClass.ROGUE: return Color(0.4, 0.2, 0.6)
		ConstantsData.HeroClass.HUNTRESS: return Color(0.2, 0.7, 0.3)
		ConstantsData.HeroClass.DUELIST: return Color(0.9, 0.7, 0.2)
	return Color(0.5, 0.5, 0.5)
