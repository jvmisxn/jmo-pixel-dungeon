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

	var new_game := Button.new()
	var multiplayer := Button.new()
	var menu_width: float = scene._title_menu_width(chosen_viewport)
	scene._set_button_width(new_game, menu_width, 44.0)
	scene._set_button_width(multiplayer, menu_width, 44.0)
	t.check(
		new_game.custom_minimum_size.is_equal_approx(multiplayer.custom_minimum_size),
		"title menu buttons share the same mobile layout width"
	)
	t.check(
		new_game.size.is_equal_approx(multiplayer.size),
		"title menu button rects are resized, not just their minimums"
	)
	new_game.free()
	multiplayer.free()
	scene.free()
