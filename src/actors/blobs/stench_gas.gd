class_name StenchGas
extends Blob
## Fetid Rat stench cloud. Mirrors SPD StenchGas: characters standing in the
## cloud are briefly paralyzed on the blob timeline.

func _init() -> void:
	super._init()
	blob_id = "stench_gas"
	blob_name = "Stench Gas"
	spread_rate = 0.4
	decay_rate = 0.08

func affect_char(ch: Char) -> void:
	if ch == null or ch.is_immune(blob_id):
		return
	var para: Paralysis = ch.get_buff("Paralysis") as Paralysis
	if para == null:
		para = Paralysis.new()
		para.set_duration(Paralysis.DURATION / 5.0)
		ch.add_buff(para)
	else:
		para.set_duration(maxf(para.time_left, Paralysis.DURATION / 5.0))
