class_name CorrosiveGas
extends Blob
## Acidic gas seeded by Wand of Corrosion. It carries a cloud-wide strength and
## applies the real Corrosion debuff to characters standing in it.

const CORROSION_DURATION: float = 2.0

var strength: int = 0
var source_id: String = ""

func _init() -> void:
	super._init()
	blob_id = "corrosive_gas"
	blob_name = "Corrosive Gas"
	spread_rate = 0.4
	decay_rate = 0.08

func set_strength(new_strength: int, new_source_id: String = "") -> CorrosiveGas:
	if new_strength > strength:
		strength = new_strength
		source_id = new_source_id
	return self

func merge_from_blob(other: Blob) -> void:
	if other is CorrosiveGas:
		var gas: CorrosiveGas = other as CorrosiveGas
		set_strength(gas.strength, gas.source_id)

func affect_char(ch: Char) -> void:
	if ch.is_immune(blob_id):
		return
	var corrosion: Corrosion = ch.get_buff("Corrosion") as Corrosion
	if corrosion == null:
		corrosion = Corrosion.new()
		ch.add_buff(corrosion)
	corrosion.set_level(CORROSION_DURATION, strength, source_id)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["strength"] = strength
	data["source_id"] = source_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	strength = int(data.get("strength", 0))
	source_id = str(data.get("source_id", ""))
