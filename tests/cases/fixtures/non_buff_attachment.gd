extends Node
## Test fixture: a plain Node attachment (deliberately NOT a Buff) used by
## test_buff_key_lookup.gd to exercise script-path buff keys.

var merged_count: int = 0


func merge(_other: Node) -> void:
	merged_count += 1
