class_name ParalyticGas
extends Blob
## Yellow gas that paralyzes characters.

func _init() -> void:
	super._init()
	blob_id = "paralytic_gas"
	blob_name = "Paralytic Gas"
	spread_rate = 0.4
	decay_rate = 0.08

func affect_char(ch: Char) -> void:
	if not ch.has_buff("Paralysis"):
		var para: Paralysis = Paralysis.new()
		para.set_duration(5.0)
		ch.add_buff(para)
