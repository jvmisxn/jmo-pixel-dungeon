class_name ConfusionGas
extends Blob
## Purple gas that disorients everything standing in it, mirroring Shattered
## Pixel Dungeon's ConfusionGas: its evolve() calls `Buff.prolong(ch, Vertigo, 2)`
## on each affected char every step, randomizing movement rather than applying a
## one-shot effect at seed time.

## SPD tops Vertigo up to 2 turns per gas tick (Buff.prolong(..., 2)).
const VERTIGO_DURATION: float = 2.0

func _init() -> void:
	super._init()
	blob_id = "confusion_gas"
	blob_name = "Confusion Gas"
	spread_rate = 0.35
	decay_rate = 0.1

func affect_char(ch: Char) -> void:
	# Source-faithful: hero and mobs alike get Vertigo, and each tick prolongs
	# (never shortens) the existing debuff to at least VERTIGO_DURATION turns.
	var existing: Vertigo = ch.get_buff("Vertigo") as Vertigo
	if existing != null:
		existing.postpone(VERTIGO_DURATION)
		return
	var vert: Vertigo = Vertigo.new()
	vert.set_duration(VERTIGO_DURATION)
	ch.add_buff(vert)
