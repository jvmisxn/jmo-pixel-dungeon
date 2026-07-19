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
	camera._target_zoom = 4.0
	camera._touch_points = {
		0: Vector2(100, 100),
		1: Vector2(300, 100),
	}
	camera._begin_pinch()
	camera._touch_points[1] = Vector2(150, 100)
	camera._update_pinch_zoom()
	t.check(
		camera._target_zoom < 1.1,
		"pinch distance contraction zooms the camera back out"
	)
	camera.zoom = Vector2(2.0, 2.0)
	camera.pan_by_screen_delta(Vector2(40, -20))
	t.check(
		camera.get_look_offset() == Vector2(-20, 10),
		"single-finger camera pan converts screen drag through zoom"
	)
	camera.reset_look_offset()
	t.check(
		camera.get_look_offset() == Vector2.ZERO,
		"camera look offset can recenter on the hero"
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

	var workflow := FileAccess.get_file_as_string("res://.github/workflows/deploy-web.yml")
	t.check(
		workflow.contains("user-scalable=no"),
		"web export disables browser page zoom so Godot can handle camera pinch"
	)
	t.check(
		not workflow.contains("user-scalable=yes"),
		"web export does not re-enable browser pinch zoom"
	)
	t.check(
		workflow.contains("touch-action: none"),
		"web export lets Godot receive canvas touch gestures"
	)
	t.check(
		not workflow.contains("width: 100vw !important;\\n\\theight: 100dvh !important;\\n\\ttouch-action: auto;"),
		"web export does not inject browser-owned canvas touch gestures"
	)
