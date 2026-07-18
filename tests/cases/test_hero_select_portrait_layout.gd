extends RefCounted

func run(t: Object) -> void:
	var scene := HeroSelectScene.new()
	var portrait_viewport := Vector2(375, 548)
	var chosen_viewport: Vector2 = scene._apply_mobile_safe_layout_reserve(scene._choose_layout_viewport_size(Vector2(1280, 720), Vector2i(375, 548)))
	t.check(
		chosen_viewport == Vector2(359, 456),
		"mobile web hero select reserves space for side and bottom browser chrome"
	)
	var left_height: float = scene._portrait_left_height(chosen_viewport)
	var min_content_height: float = scene._portrait_single_player_min_content_height(chosen_viewport)
	t.check(
		min_content_height <= left_height,
		"portrait hero select keeps Start row inside a 375px mobile viewport"
	)

	var safari_viewport := Vector2(393, 687)
	var safari_safe_viewport: Vector2 = scene._apply_mobile_safe_layout_reserve(safari_viewport)
	var safari_left_height: float = scene._portrait_left_height(safari_safe_viewport)
	var safari_min_content_height: float = scene._portrait_single_player_min_content_height(safari_safe_viewport)
	t.check(
		safari_min_content_height <= safari_left_height,
		"portrait hero select keeps Start row above mobile browser controls"
	)
	t.check(
		scene._portrait_action_row_bottom(safari_safe_viewport) <= safari_safe_viewport.y - 52.0,
		"portrait hero select places the Start row within the safe viewport"
	)

	var discord_viewport := Vector2(393, 852)
	var discord_safe_viewport: Vector2 = scene._apply_mobile_safe_layout_reserve(discord_viewport)
	t.check(
		discord_safe_viewport == Vector2(377, 660),
		"Discord mobile webview hero select reserves its bottom browser chrome"
	)
	t.check(
		scene._portrait_action_row_bottom(discord_safe_viewport) <= discord_safe_viewport.y - 52.0,
		"Discord mobile webview keeps the Start row above bottom controls"
	)
	scene.free()
