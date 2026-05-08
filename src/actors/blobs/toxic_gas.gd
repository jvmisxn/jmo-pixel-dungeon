class_name ToxicGas
extends Blob
## Poisonous green gas. Applies poison to characters within.

func _init() -> void:
	super._init()
	blob_id = "toxic_gas"
	blob_name = "Toxic Gas"
	spread_rate = 0.4
	decay_rate = 0.08

func affect_char(ch: Char) -> void:
	if not ch.has_buff("Poison"):
		var p: Poison = Poison.create(4.0 + density[ch.pos])
		ch.add_buff(p)
