extends SceneTree
## Dev tool: boots the real game and saves screenshots of key screens, for
## reviewing UI/visual changes without a display. Needs a rendering driver,
## so run it under a virtual display, e.g.:
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     -s res://tools/capture_screenshots.gd -- --out=/tmp/shots
##
## The work lives in capture_driver.gd, loaded at runtime because autoload
## names are not resolvable while a -s script compiles.

func _initialize() -> void:
	var driver_script: GDScript = load("res://tools/capture_driver.gd") as GDScript
	var driver: Node = driver_script.new() as Node
	root.add_child.call_deferred(driver)
