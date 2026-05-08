class_name WndJournal
extends WndBase
## Journal window with tabs for Notes, Catalog, and Guide.

enum JournalTab {
	NOTES,
	CATALOG,
	GUIDE,
}

var _current_tab: JournalTab = JournalTab.NOTES
var _tab_buttons: Array[Button] = []
var _content_scroll: ScrollContainer = null
var _journal_content: VBoxContainer = null


func _init() -> void:
	window_title = "Journal"
	custom_minimum_size = Vector2(420, 440)


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)

	# --- Tab Bar ---
	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	main.add_child(tab_row)

	var tab_names: Array[String] = ["Notes", "Catalog", "Guide"]
	for i: int in range(tab_names.size()):
		var tab_btn: Button = Button.new()
		tab_btn.text = tab_names[i]
		tab_btn.toggle_mode = true
		tab_btn.button_pressed = (i == 0)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_row.add_child(tab_btn)
		_tab_buttons.append(tab_btn)

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	# --- Scrollable Content Area ---
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_content_scroll)

	_journal_content = VBoxContainer.new()
	_journal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_content.add_theme_constant_override("separation", 6)
	_content_scroll.add_child(_journal_content)

	_refresh_tab_content()
	return main


func _on_tab_pressed(tab_idx: int) -> void:
	_current_tab = tab_idx as JournalTab
	for i: int in range(_tab_buttons.size()):
		_tab_buttons[i].button_pressed = (i == tab_idx)
	_refresh_tab_content()


func _refresh_tab_content() -> void:
	if not _journal_content:
		return
	# Clear existing content
	for child: Node in _journal_content.get_children():
		child.queue_free()

	match _current_tab:
		JournalTab.NOTES:
			_build_notes_tab()
		JournalTab.CATALOG:
			_build_catalog_tab()
		JournalTab.GUIDE:
			_build_guide_tab()


# ---------------------------------------------------------------------------
# Notes Tab
# ---------------------------------------------------------------------------

func _build_notes_tab() -> void:
	var notes_title: Label = Label.new()
	notes_title.text = "Notes & Quest Progress"
	notes_title.add_theme_font_size_override("font_size", 16)
	_journal_content.add_child(notes_title)

	# Keys found
	var keys_header: Label = Label.new()
	keys_header.text = "Keys:"
	keys_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_journal_content.add_child(keys_header)

	var keys_found: Array = _get_keys_from_inventory()
	if keys_found.is_empty():
		var no_keys: Label = Label.new()
		no_keys.text = "  No keys in inventory."
		no_keys.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_journal_content.add_child(no_keys)
	else:
		for key_name: String in keys_found:
			var key_lbl: Label = Label.new()
			key_lbl.text = "  - %s" % key_name
			_journal_content.add_child(key_lbl)

	# Quest progress
	var sep: HSeparator = HSeparator.new()
	_journal_content.add_child(sep)

	var quest_header: Label = Label.new()
	quest_header.text = "Quests:"
	quest_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_journal_content.add_child(quest_header)

	var quests: Array = _get_active_quests()
	if quests.is_empty():
		var no_quests: Label = Label.new()
		no_quests.text = "  No active quests."
		no_quests.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_journal_content.add_child(no_quests)
	else:
		for quest: Dictionary in quests:
			var quest_row: HBoxContainer = HBoxContainer.new()
			var q_name: Label = Label.new()
			q_name.text = "  %s" % quest.get("name", "Unknown Quest")
			q_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			quest_row.add_child(q_name)

			var q_status: Label = Label.new()
			q_status.text = quest.get("status", "In Progress")
			var status_color: Color = Color(0.3, 1.0, 0.3) if quest.get("status") == "Complete" else Color(0.9, 0.9, 0.3)
			q_status.add_theme_color_override("font_color", status_color)
			quest_row.add_child(q_status)

			_journal_content.add_child(quest_row)

	# Depth notes
	var sep2: HSeparator = HSeparator.new()
	_journal_content.add_child(sep2)

	var depth_header: Label = Label.new()
	depth_header.text = "Landmarks:"
	depth_header.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_journal_content.add_child(depth_header)

	var landmarks: Array = _get_landmarks()
	if landmarks.is_empty():
		var no_lm: Label = Label.new()
		no_lm.text = "  No landmarks discovered."
		no_lm.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_journal_content.add_child(no_lm)
	else:
		for lm: String in landmarks:
			var lm_lbl: Label = Label.new()
			lm_lbl.text = "  - %s" % lm
			_journal_content.add_child(lm_lbl)


# ---------------------------------------------------------------------------
# Catalog Tab
# ---------------------------------------------------------------------------

func _build_catalog_tab() -> void:
	var cat_title: Label = Label.new()
	cat_title.text = "Discovered Items"
	cat_title.add_theme_font_size_override("font_size", 16)
	_journal_content.add_child(cat_title)

	# Group by category
	var categories: Array[Dictionary] = [
		{"name": "Weapons", "cat": ConstantsData.ItemCategory.WEAPON},
		{"name": "Armor", "cat": ConstantsData.ItemCategory.ARMOR},
		{"name": "Wands", "cat": ConstantsData.ItemCategory.WAND},
		{"name": "Rings", "cat": ConstantsData.ItemCategory.RING},
		{"name": "Artifacts", "cat": ConstantsData.ItemCategory.ARTIFACT},
		{"name": "Potions", "cat": ConstantsData.ItemCategory.POTION},
		{"name": "Scrolls", "cat": ConstantsData.ItemCategory.SCROLL},
	]

	var catalog: Dictionary = _get_catalog_data()

	for cat_info: Dictionary in categories:
		var cat_name: String = cat_info["name"]
		var cat_id: int = cat_info["cat"]

		var header: Label = Label.new()
		header.text = cat_name
		header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
		_journal_content.add_child(header)

		var items_in_cat: Array = catalog.get(cat_id, [])
		if items_in_cat.is_empty():
			var none_lbl: Label = Label.new()
			none_lbl.text = "  None discovered yet."
			none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			_journal_content.add_child(none_lbl)
		else:
			for item_entry: Dictionary in items_in_cat:
				var row: HBoxContainer = HBoxContainer.new()
				var check: Label = Label.new()
				check.text = "  [x] " if item_entry.get("identified", false) else "  [ ] "
				row.add_child(check)

				var name_lbl: Label = Label.new()
				name_lbl.text = item_entry.get("name", "???")
				if not item_entry.get("identified", false):
					name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				row.add_child(name_lbl)
				_journal_content.add_child(row)


# ---------------------------------------------------------------------------
# Guide Tab
# ---------------------------------------------------------------------------

func _build_guide_tab() -> void:
	var guide_title: Label = Label.new()
	guide_title.text = "Adventurer's Guide"
	guide_title.add_theme_font_size_override("font_size", 16)
	_journal_content.add_child(guide_title)

	var tips: Array[String] = [
		"Explore thoroughly - search walls for secret doors by walking into them.",
		"Identify potions and scrolls by using them. Warriors identify healing, Mages identify scrolls, Rogues identify rings.",
		"Upgrade scrolls are rare. Save them for late-game equipment.",
		"Eat food before you start starving to avoid HP loss.",
		"Surprise attacks deal 50% bonus damage. Attack from behind doors or while invisible.",
		"Thrown weapons are effective but break after a few uses.",
		"Seeds can be planted as traps or used in alchemy.",
		"The Sad Ghost quest on floors 2-4 rewards a weapon or armor choice.",
		"Bosses appear every 5 floors. Prepare before descending.",
		"Wells of Health fully restore HP. Wells of Awareness reveal the floor map.",
		"Cursed items can be removed with a Scroll of Remove Curse.",
		"Strength requirements reduce damage/defense if not met.",
		"Rings provide passive bonuses while equipped. Two can be worn at once.",
		"Artifacts grow stronger with use - keep them equipped.",
		"The Alchemy system lets you combine seeds and potions into stronger items.",
	]

	for i: int in range(tips.size()):
		var tip_lbl: RichTextLabel = RichTextLabel.new()
		tip_lbl.bbcode_enabled = true
		tip_lbl.fit_content = true
		tip_lbl.text = "[b]%d.[/b] %s" % [i + 1, tips[i]]
		tip_lbl.custom_minimum_size = Vector2(0, 28)
		_journal_content.add_child(tip_lbl)


# ---------------------------------------------------------------------------
# Data Helpers
# ---------------------------------------------------------------------------

func _get_keys_from_inventory() -> Array:
	var keys: Array = []
	var hero: Hero = GameManager.hero if GameManager else null
	if not hero or not hero.belongings:
		return keys
	for item: Variant in hero.belongings.backpack:
		var name_str: String = ConstantsData.get_prop(item, "item_name", "")
		if "key" in name_str.to_lower() or "Key" in name_str:
			keys.append(name_str)
	return keys


func _get_active_quests() -> Array:
	# Pull from GameManager stats or a quest tracker if available
	var stats: Dictionary = GameManager.stats if GameManager and GameManager.get("stats") else {}
	return stats.get("active_quests", [])


func _get_landmarks() -> Array:
	var stats: Dictionary = GameManager.stats if GameManager and GameManager.get("stats") else {}
	return stats.get("landmarks", [])


func _get_catalog_data() -> Dictionary:
	# Pull discovered items from GameManager or a catalog singleton
	var stats: Dictionary = GameManager.stats if GameManager and GameManager.get("stats") else {}
	return stats.get("catalog", {})
