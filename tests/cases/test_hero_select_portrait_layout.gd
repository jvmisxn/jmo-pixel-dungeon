extends RefCounted

func run(t: Object) -> void:
	var scene := HeroSelectScene.new()
	var portrait_viewport := Vector2(375, 548)
	var left_height: float = scene._portrait_left_height(portrait_viewport)
	var min_content_height: float = scene._portrait_single_player_min_content_height(portrait_viewport)
	t.check(
		min_content_height <= left_height,
		"portrait hero select keeps Start row inside a 375px mobile viewport"
	)
	scene.free()
