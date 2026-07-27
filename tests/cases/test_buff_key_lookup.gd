extends RefCounted
## Buff type-key contract: add_buff, has_buff, get_buff_node, and
## remove_buff_by_id must agree on how a buff is identified. Buff subclasses
## key on buff_id; non-Buff node attachments key on their script path
## (previously they attached fine but were un-findable and un-removable,
## backlog audit:S03).

const NON_BUFF_PATH: String = "res://tests/cases/fixtures/non_buff_attachment.gd"


func run(t: Object) -> void:
	_test_buff_id_lookups_unchanged(t)
	_test_non_buff_node_key_lookups(t)


func _test_buff_id_lookups_unchanged(t: Object) -> void:
	var ch: Char = Char.new()
	ch.add_buff(Weakness.new())

	t.check(ch.has_buff("Weakness"), "Buff subclass still found by buff_id")
	t.check(ch.get_buff("Weakness") is Weakness, "get_buff returns typed Buff by buff_id")
	t.check(ch.get_buff_node("Weakness") is Weakness, "get_buff_node also matches buff_id")

	ch.remove_buff_by_id("Weakness")
	t.check(not ch.has_buff("Weakness"), "remove_buff_by_id still removes by buff_id")
	ch.free()


func _test_non_buff_node_key_lookups(t: Object) -> void:
	var script: GDScript = load(NON_BUFF_PATH)
	var key: String = script.get_path()
	t.check(key == NON_BUFF_PATH, "fixture script keeps its resource path")

	var ch: Char = Char.new()
	var node: Node = script.new()
	var attached: Node = ch.add_buff(node)
	t.check(attached == node, "non-Buff node attaches via add_buff")
	t.check(Char.buff_type_key(node) == key, "non-Buff key is the script path")

	t.check(ch.has_buff(key), "non-Buff attachment is findable via has_buff")
	t.check(ch.get_buff_node(key) == node, "get_buff_node returns the raw node")
	t.check(ch.get_buff(key) == null, "get_buff stays typed: non-Buff match is null")

	var dup: Node = script.new()
	var merged: Node = ch.add_buff(dup)
	t.check(merged == node, "same-script re-attach merges instead of stacking")
	t.check(int(node.merged_count) == 1, "merge() ran on the existing attachment")
	t.check(ch.get_buffs().size() == 1, "no duplicate attachment in the buff list")

	ch.remove_buff_by_id(key)
	t.check(not ch.has_buff(key), "non-Buff attachment is removable by its key")
	t.check(ch.get_buffs().is_empty(), "buff list empty after keyed removal")
	ch.free()
