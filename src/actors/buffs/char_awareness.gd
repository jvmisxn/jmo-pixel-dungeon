class_name CharAwareness
extends Buff
## Upstream TalismanOfForesight.CharAwareness, adapted for the port.
## Upstream attaches the buff to the HERO with the watched actor's id;
## the port has no global actor-id registry, so the mark is attached to
## the watched character instead and Level.update_fov reveals any living
## mob carrying it (cell + 8 neighbors, like MindVision's per-mob overlay).
## Attaching to the mob also gives save/load persistence for free, since
## mob buffs serialize with the mob. Currently applied by the Mage's
## Arcane Vision talent (Wand.wandProc: 5 + 5*points turns per zap).

func _init() -> void:
	buff_id = "CharAwareness"
	buff_name = "Watched"
	buff_type = BuffType.NEUTRAL
	duration = 10.0
	time_left = 10.0
	icon_color = Color(0.6, 0.85, 1.0)

## Upstream Buff.append refreshes per-target awareness; the port merges by
## buff_id per mob, keeping the longer remaining duration.
func merge(other: Node) -> void:
	if other is Buff:
		time_left = maxf(time_left, (other as Buff).time_left)
		duration = maxf(duration, (other as Buff).duration)

func description() -> String:
	return ("The Mage's magic clings to this creature, revealing it even"
		+ " through walls.\n\nTurns of awareness remaining: %d." % int(ceil(time_left)))
