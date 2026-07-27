extends RefCounted
## Buff-index consistency: has_buff/get_buff_node/remove_buff_by_id run on an
## O(1) type-key index (backlog audit:S03/S06). The index must track every
## _buffs mutation — add_buff, remove_buff, and the deserialize load path —
## and keep the old linear-scan semantics (earliest match wins, keyed removal
## removes all matches).


func run(t: Object) -> void:
	_test_add_remove_readd(t)
	_test_serialize_round_trip(t)
	_test_deserialize_duplicates_and_replacement(t)


func _test_add_remove_readd(t: Object) -> void:
	var ch: Char = Char.new()
	var w: Buff = Weakness.new()
	ch.add_buff(w)
	t.check(ch.has_buff("Weakness"), "indexed on add_buff")
	t.check(ch.get_buff_node("Weakness") == w, "get_buff_node hits the index")

	ch.remove_buff(w)
	t.check(not ch.has_buff("Weakness"), "unindexed on remove_buff instance removal")
	t.check(ch.get_buff_node("Weakness") == null, "get_buff_node null after removal")

	var w2: Buff = Weakness.new()
	ch.add_buff(w2)
	t.check(ch.has_buff("Weakness"), "re-add after removal re-indexes")
	t.check(ch.get_buff_node("Weakness") == w2, "index points at the new instance")
	ch.free()


func _test_serialize_round_trip(t: Object) -> void:
	var ch: Char = Char.new()
	ch.add_buff(Weakness.new())
	var data: Array[Dictionary] = ch._serialize_buffs()

	var loaded: Char = Char.new()
	loaded._deserialize_buffs(data)
	t.check(loaded.has_buff("Weakness"), "deserialize path indexes loaded buffs")
	t.check(loaded.get_buff("Weakness") is Weakness, "typed lookup works after load")

	loaded.remove_buff_by_id("Weakness")
	t.check(not loaded.has_buff("Weakness"), "keyed removal works on loaded buffs")
	ch.free()
	loaded.free()


func _test_deserialize_duplicates_and_replacement(t: Object) -> void:
	# _deserialize_buffs appends without merging, so two same-key entries can
	# coexist after a load; the index must keep both and honor old scan order.
	var ch: Char = Char.new()
	var scratch: Buff = Weakness.new()
	var entry: Dictionary = scratch.serialize()
	scratch.free()
	ch._deserialize_buffs([entry, entry.duplicate(true)])
	t.check(ch.get_buffs().size() == 2, "two same-key entries both attach on load")
	t.check(ch.has_buff("Weakness"), "duplicated key still findable")
	var first: Node = ch.get_buffs()[0]
	t.check(ch.get_buff_node("Weakness") == first, "earliest-attached match wins")

	ch.remove_buff_by_id("Weakness")
	t.check(not ch.has_buff("Weakness"), "keyed removal removes all matches")
	t.check(ch.get_buffs().is_empty(), "buff list empty after keyed removal")

	# A fresh deserialize replaces prior buffs; index must reset with them.
	ch.add_buff(Weakness.new())
	ch._deserialize_buffs([] as Array)
	t.check(not ch.has_buff("Weakness"), "deserialize replacement clears stale index entries")
	ch.free()
