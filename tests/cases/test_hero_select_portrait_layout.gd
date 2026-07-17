extends RefCounted

func run(t: Object) -> void:
	var scene := HeroSelectScene.new()
	var portrait_viewport := Vector2(375, 548)
	var chosen_viewport: Vector2 = scene._choose_layout_viewport_size(Vector2(1280, 720), Vector2i(375, 548))
	t.check(
		chosen_viewport == portrait_viewport,
		"mobile web hero select uses browser portrait size instead of desktop canvas size"
	)
	var left_height: float = scene._portrait_left_height(portrait_viewport)
	var min_content_height: float = scene._portrait_single_player_min_content_height(portrait_viewport)
	t.check(
		min_content_height <= left_height,
		"portrait hero select keeps Start row inside a 375px mobile viewport"
	)

	var safari_viewport := Vector2(393, 687)
	var safari_left_height: float = scene._portrait_left_height(safari_viewport)
	var safari_min_content_height: float = scene._portrait_single_player_min_content_height(safari_viewport)
	t.check(
		safari_min_content_height <= safari_left_height,
		"portrait hero select keeps Start row above mobile browser controls"
	)
	scene.free()
