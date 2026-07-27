class_name EnhancedRings
extends Buff
## Rogue Enhanced Rings effect (upstream buffs/EnhancedRings.java): using the
## Cloak of Shadows enhances the Rogue's rings for 3 turns per talent point
## (Talent.onArtifactUsed: Buff.prolong 3*points). While live, every equipped
## ring's effective bonus level is +1 (upstream Ring.buffedLvl). Port
## adaptation: upstream calls updateHT on attach/detach for Ring of Might;
## here the Might passive is re-applied instead so STR/HP stay in sync.

func _init() -> void:
	buff_id = "EnhancedRings"
	buff_name = "Enhanced Rings"
	buff_type = BuffType.POSITIVE
	icon_color = Color(0.2, 1.0, 0.2)  # upstream UPGRADE icon hardlight(0,1,0)

func on_attach() -> void:
	_refresh_might_passive()

func on_detach() -> void:
	_refresh_might_passive()

## Ring of Might caches its STR/HP bonus at equip time, so re-apply its
## passive when the +1 window opens/closes (mirrors upstream updateHT calls).
func _refresh_might_passive() -> void:
	if target == null or not target.has_method("get_buff"):
		return
	var mb: Variant = target.get_buff("RingOfMight")
	if mb != null and mb.get("ring") != null:
		var ring: Ring = mb.ring
		ring._remove_passive(target)
		ring._apply_passive(target)

func description() -> String:
	return ("The magic of your rings has been temporarily enhanced. " +
		"Your equipped rings behave as if they were one level higher " +
		"for %s.") % disp_turns(time_left)
