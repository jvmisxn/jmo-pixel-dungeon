extends RefCounted

func run(t: Object) -> void:
	var script: Variant = load("res://src/ui/status_pane.gd")
	t.check(script != null and script is GDScript, "status_pane.gd loads as a script")

	var pane: StatusPane = StatusPane.new()
	t.root.add_child(pane)
	t.check(pane.get_parent() == t.root, "StatusPane can be added to the scene tree")

	pane.set_compact_mode(true)
	t.check(bool(pane.get("_compact_mode")), "StatusPane compact mode is applied")

	pane.update_all()
	t.check(pane.get_parent() == t.root, "StatusPane update path remains alive after compact layout")

	pane.free()
