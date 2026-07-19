extends RefCounted

func run(t: Object) -> void:
	var scene := TitleScene.new()
	var browser_viewport := Vector2(393, 687)
	var chosen_viewport: Vector2 = scene._apply_mobile_safe_layout_reserve(scene._choose_layout_viewport_size(Vector2(1280, 720), Vector2i(393, 687)))
	t.check(
		chosen_viewport == Vector2(377, 687),
		"mobile web title layout uses browser viewport with a right-edge safe reserve"
	)
	t.check(
		scene._title_menu_width(chosen_viewport) <= 320.0,
		"portrait title menu is capped below the full desktop button width"
	)
	t.check(
		scene._title_menu_width(chosen_viewport) <= chosen_viewport.x - 112.0,
		"portrait title menu leaves horizontal breathing room inside the phone viewport"
	)
	t.check(
		scene._should_stack_title_actions(chosen_viewport),
		"portrait title menu stacks New Game and Continue instead of clipping the split row"
	)
	t.check(
		not scene._should_stack_title_actions(Vector2(852, 393)),
		"landscape title menu keeps the split top action row"
	)

	var new_game := Button.new()
	var continue_btn := Button.new()
	var multiplayer := Button.new()
	var menu_box := VBoxContainer.new()
	var top_row := HBoxContainer.new()
	scene._menu_box = menu_box
	scene._top_menu_row = top_row
	scene._btn_continue = continue_btn
	menu_box.add_child(top_row)
	top_row.add_child(continue_btn)
	var menu_width: float = scene._title_menu_width(chosen_viewport)
	scene._set_button_width(new_game, menu_width, 44.0)
	scene._set_button_width(continue_btn, menu_width, 44.0)
	scene._set_button_width(multiplayer, menu_width, 44.0)
	t.check(
		new_game.custom_minimum_size.is_equal_approx(multiplayer.custom_minimum_size),
		"title menu buttons share the same mobile layout width"
	)
	t.check(
		new_game.size.is_equal_approx(multiplayer.size),
		"title menu button rects are resized, not just their minimums"
	)
	scene._arrange_top_actions(true)
	t.check(
		continue_btn.get_parent() == menu_box and menu_box.get_child(1) == continue_btn,
		"portrait Continue button is moved under New Game"
	)
	scene._arrange_top_actions(false)
	t.check(
		continue_btn.get_parent() == top_row,
		"desktop Continue button returns to the split top row"
	)
	new_game.free()
	multiplayer.free()
	menu_box.free()
	scene.free()
