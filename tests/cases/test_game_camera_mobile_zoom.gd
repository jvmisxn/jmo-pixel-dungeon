extends RefCounted

func run(t: Object) -> void:
	var camera := GameCamera.new()
	camera.default_zoom_level = 3.0
	camera.min_zoom = 1.5
	camera.max_zoom = 5.0
	camera.zoom_step = 0.5
	camera._apply_mobile_zoom_limits()
	t.check(
		is_equal_approx(camera.default_zoom_level, 1.5),
		"mobile camera starts zoomed out enough for a phone viewport"
	)
	t.check(
		is_equal_approx(camera.min_zoom, 1.0),
		"mobile camera can zoom out to 1x"
	)
	t.check(
		camera.max_zoom >= 10.0,
		"mobile camera still allows pinch zooming in"
	)
	camera.free()
