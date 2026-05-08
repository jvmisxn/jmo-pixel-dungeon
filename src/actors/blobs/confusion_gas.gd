class_name ConfusionGas
extends Blob
## Purple gas that causes random movement (amok-like effect for mobs).

func _init() -> void:
	super._init()
	blob_id = "confusion_gas"
	blob_name = "Confusion Gas"
	spread_rate = 0.35
	decay_rate = 0.1

func affect_char(ch: Char) -> void:
	if not ch.has_buff("Amok") and not ch.is_hero:
		var amok_buff: Amok = Amok.new()
		amok_buff.set_duration(5.0)
		ch.add_buff(amok_buff)
	elif ch.is_hero:
		# For hero, apply a vertigo/random movement effect
		if not ch.has_buff("Blindness"):
			var blind: Blindness = Blindness.new()
			blind.set_duration(3.0)
			ch.add_buff(blind)
