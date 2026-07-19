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

	camera._target_zoom = 2.0
	camera._touch_points = {
		0: Vector2(100, 100),
		1: Vector2(200, 100),
	}
	camera._begin_pinch()
	camera._touch_points[1] = Vector2(300, 100)
	camera._update_pinch_zoom()
	t.check(
		camera._target_zoom > 3.9,
		"pinch distance expansion zooms the camera in"
	)

	camera.set_zoom_level(3.0)
	t.check(
		is_equal_approx(camera._target_zoom, 3.0),
		"settings zoom updates the smooth camera target"
	)
	t.check(
		is_equal_approx(camera.zoom.x, 3.0),
		"settings zoom applies immediately instead of snapping back next frame"
	)
	camera.free()
