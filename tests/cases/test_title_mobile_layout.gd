extends RefCounted

func run(t: Object) -> void:
	var scene := TitleScene.new()
	var browser_viewport := Vector2(393, 687)
	var chosen_viewport: Vector2 = scene._choose_layout_viewport_size(Vector2(1280, 720), Vector2i(393, 687))
	t.check(
		chosen_viewport == browser_viewport,
		"mobile web title layout uses the browser viewport instead of the backing canvas"
	)

	var new_game := Button.new()
	var multiplayer := Button.new()
	scene._set_button_width(new_game, 297.0, 44.0)
	scene._set_button_width(multiplayer, 297.0, 44.0)
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
